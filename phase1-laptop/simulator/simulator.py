#!/usr/bin/env python3
"""
PLC Simulator — generates realistic factory metrics for OT monitoring PoC.

Simulates 3 production lines with a 4-state machine:
  RUNNING    → normal production
  MICRO_STOP → 2-30s unplanned stop (~every 5 min)
  LONG_STOP  → 1-5 min unplanned stop (~every 30 min)
  FAULT      → machine_error_state=1, 2-10 min repair (~every 60 min)

line2 is 2× less reliable than line1/line3.
After DEGRADATION_START_HOURS the cycle time increases +0.1ms/cycle.
"""

import enum
import os
import random
import time

from prometheus_client import Counter, Gauge, start_http_server

TICK_INTERVAL = 0.1  # seconds

SITE_NAME = os.environ.get("SITE_NAME", "factory_poc")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "poc")
SIMULATOR_PORT = int(os.environ.get("SIMULATOR_PORT", "8000"))
DEGRADATION_START_HOURS = float(os.environ.get("DEGRADATION_START_HOURS", "8"))


class State(enum.Enum):
    RUNNING = "running"
    MICRO_STOP = "micro_stop"
    LONG_STOP = "long_stop"
    FAULT = "fault"


MACHINE_CONFIGS = [
    {
        "machine_id": "line1",
        "vlan": "low",
        "cycle_ms_mean": 900.0,
        "cycle_ms_std": 50.0,
        "micro_stop_rate_per_hour": 12,   # ~every 5 min
        "long_stop_rate_per_hour": 2,     # ~every 30 min
        "fault_rate_per_hour": 1,         # ~every 60 min
    },
    {
        "machine_id": "line2",
        "vlan": "medium",
        "cycle_ms_mean": 1200.0,
        "cycle_ms_std": 80.0,
        "micro_stop_rate_per_hour": 24,   # 2x line1 — less reliable
        "long_stop_rate_per_hour": 4,
        "fault_rate_per_hour": 2,
    },
    {
        "machine_id": "line3",
        "vlan": "low",
        "cycle_ms_mean": 750.0,
        "cycle_ms_std": 40.0,
        "micro_stop_rate_per_hour": 12,
        "long_stop_rate_per_hour": 2,
        "fault_rate_per_hour": 1,
    },
]

_LABELS = ["machine_id", "vlan"]

_machine_on = Gauge(
    "machine_on", "Machine power state (1=on, 0=off)", _LABELS
)
_production_run = Gauge(
    "production_run", "Production running (1=running, 0=stopped)", _LABELS
)
_machine_error_state = Gauge(
    "machine_error_state", "Machine fault/error state (1=fault)", _LABELS
)
_ok_counter = Counter(
    "ok_counter", "Cumulative OK parts produced", _LABELS
)
_nok_counter = Counter(
    "nok_counter", "Cumulative NOK (scrap) parts produced", _LABELS
)
_last_cycle_time_ms = Gauge(
    "last_cycle_time_ms", "Last completed cycle time in ms", _LABELS
)
_last_stoppage_time_ms = Gauge(
    "last_stoppage_time_ms", "Elapsed stoppage duration in ms (0 when running)", _LABELS
)
_cycle_count = Counter(
    "cycle_count", "Total cycle count (monotonic)", _LABELS
)
_prod_type = Gauge(
    "prod_type", "Current product type (1–3)", _LABELS
)


class Machine:
    def __init__(self, cfg: dict):
        self.machine_id = cfg["machine_id"]
        self.vlan = cfg["vlan"]
        self.cycle_ms_mean = cfg["cycle_ms_mean"]
        self.cycle_ms_std = cfg["cycle_ms_std"]

        # Convert hourly rates to per-second for exponential inter-arrival times
        self.micro_rate = cfg["micro_stop_rate_per_hour"] / 3600.0
        self.long_rate = cfg["long_stop_rate_per_hour"] / 3600.0
        self.fault_rate = cfg["fault_rate_per_hour"] / 3600.0

        self.state = State.RUNNING
        self.stop_start_time = 0.0
        self.state_end_time = 0.0
        self.cycle_accumulator_ms = 0.0
        self.total_cycles = 0
        self.start_time = time.time()

        self.prod_type_val = random.randint(1, 3)
        self.next_prod_type_change = time.time() + random.uniform(3600, 7200)

        lbl = {"machine_id": self.machine_id, "vlan": self.vlan}
        _machine_on.labels(**lbl).set(1)
        _production_run.labels(**lbl).set(1)
        _machine_error_state.labels(**lbl).set(0)
        _last_cycle_time_ms.labels(**lbl).set(self.cycle_ms_mean)
        _last_stoppage_time_ms.labels(**lbl).set(0)
        _prod_type.labels(**lbl).set(self.prod_type_val)
        # Touch counters so labels appear immediately on /metrics
        _ok_counter.labels(**lbl).inc(0)
        _nok_counter.labels(**lbl).inc(0)
        _cycle_count.labels(**lbl).inc(0)

        self.current_cycle_target_ms = self._sample_cycle_time()
        self.next_event_time, self.next_event_state = self._schedule_next_event()

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _sample_cycle_time(self) -> float:
        hours_elapsed = (time.time() - self.start_time) / 3600.0
        degradation_ms = 0.0
        if hours_elapsed > DEGRADATION_START_HOURS:
            degradation_ms = self.total_cycles * 0.1  # +0.1 ms per cycle
        base = self.cycle_ms_mean + degradation_ms
        return max(1.0, random.gauss(base, self.cycle_ms_std))

    def _schedule_next_event(self):
        now = time.time()
        candidates = sorted(
            [
                (now + random.expovariate(self.micro_rate), State.MICRO_STOP),
                (now + random.expovariate(self.long_rate),  State.LONG_STOP),
                (now + random.expovariate(self.fault_rate), State.FAULT),
            ],
            key=lambda x: x[0],
        )
        return candidates[0]

    @staticmethod
    def _stop_duration_s(state: State) -> float:
        if state == State.MICRO_STOP:
            return random.uniform(2, 30)
        elif state == State.LONG_STOP:
            return random.uniform(60, 300)
        else:  # FAULT
            return random.uniform(120, 600)

    # ------------------------------------------------------------------
    # Main tick
    # ------------------------------------------------------------------

    def tick(self, dt_s: float):
        now = time.time()
        lbl = {"machine_id": self.machine_id, "vlan": self.vlan}

        # Product type changes every 1-2 hours
        if now >= self.next_prod_type_change:
            options = [v for v in [1, 2, 3] if v != self.prod_type_val]
            self.prod_type_val = random.choice(options)
            self.next_prod_type_change = now + random.uniform(3600, 7200)
            _prod_type.labels(**lbl).set(self.prod_type_val)

        if self.state == State.RUNNING:
            _machine_on.labels(**lbl).set(1)
            _production_run.labels(**lbl).set(1)
            _machine_error_state.labels(**lbl).set(0)
            _last_stoppage_time_ms.labels(**lbl).set(0)

            if now >= self.next_event_time:
                duration_s = self._stop_duration_s(self.next_event_state)
                self.state = self.next_event_state
                self.stop_start_time = now
                self.state_end_time = now + duration_s
            else:
                # Accumulate time toward next cycle completion
                self.cycle_accumulator_ms += dt_s * 1000.0
                if self.cycle_accumulator_ms >= self.current_cycle_target_ms:
                    self.cycle_accumulator_ms -= self.current_cycle_target_ms
                    self.total_cycles += 1
                    _cycle_count.labels(**lbl).inc()
                    _last_cycle_time_ms.labels(**lbl).set(self.current_cycle_target_ms)
                    if random.random() < 0.03:  # 3% scrap rate
                        _nok_counter.labels(**lbl).inc()
                    else:
                        _ok_counter.labels(**lbl).inc()
                    self.current_cycle_target_ms = self._sample_cycle_time()

        else:
            # MICRO_STOP / LONG_STOP / FAULT
            _production_run.labels(**lbl).set(0)
            _machine_error_state.labels(**lbl).set(
                1 if self.state == State.FAULT else 0
            )
            _last_stoppage_time_ms.labels(**lbl).set(
                (now - self.stop_start_time) * 1000.0
            )

            if now >= self.state_end_time:
                self.state = State.RUNNING
                self.cycle_accumulator_ms = 0.0
                self.current_cycle_target_ms = self._sample_cycle_time()
                self.next_event_time, self.next_event_state = (
                    self._schedule_next_event()
                )


def main():
    start_http_server(SIMULATOR_PORT)
    print(
        f"[simulator] Started — site={SITE_NAME} env={ENVIRONMENT} "
        f"port={SIMULATOR_PORT} degradation_start={DEGRADATION_START_HOURS}h"
    )
    machines_names = [c["machine_id"] for c in MACHINE_CONFIGS]
    print(f"[simulator] Machines: {machines_names}")

    machines = [Machine(cfg) for cfg in MACHINE_CONFIGS]

    while True:
        for machine in machines:
            machine.tick(TICK_INTERVAL)
        time.sleep(TICK_INTERVAL)


if __name__ == "__main__":
    main()
