# Phase 2 — VM-Based Enterprise Simulation

This directory contains infrastructure scripts and configuration for simulating
an on-prem enterprise OT monitoring environment using separate VMs.

## Architecture

```
[Collector VM]           [Monitoring VM]          [SQL VM]
Telegraf container  →→→  Prometheus + Grafana      SQL Server 2022
(on-prem simulator)      (simulates Azure-hosted)  (on-prem data store)
```

## VM Setup Order

1. **sql-vm** — install SQL Server, run schema scripts from `../shared/sql/`
2. **collector-vm** — install Telegraf, configure `.env` with SQL VM IP
3. **monitoring-vm** — install Prometheus + Grafana, configure collector VM IP

## Files

```
collector-vm/
  setup.sh                  # Bootstrap for RHEL 9 / Rocky Linux 9
  telegraf/telegraf.conf    # Multi-PLC Telegraf config (SQL + Prometheus outputs active)
  telegraf/telegraf-vlan-low.conf  # Additional PLCs on OT-LOW VLAN
  systemd/telegraf-podman.service  # Systemd unit for auto-restart

monitoring-vm/
  setup.sh
  docker-compose.yml        # Prometheus + Grafana (no static IP workaround needed)
  prometheus/prometheus.yml # Scrapes collector VM

sql-vm/
  setup.sh                  # SQL Server 2022 install + firewalld

network/
  firewall-rules.md         # Hand to network team
  vlan-topology.md          # IP plan + VLAN segmentation
```

## Key Difference from Phase 1

Phase 1 uses WSL2 Podman workarounds (static IPs, `--disable-dns` network).
Phase 2 VMs run RHEL 9 with proper systemd — remove those workarounds:
- Use normal `networks:` block in docker-compose.yml (no `external: true`)
- Remove `x-hosts` / `extra_hosts` — aardvark-dns handles service names
- Remove `user: root` + `entrypoint: ["telegraf"]` from Telegraf service

## Grafana Dashboards

Copy from `../shared/grafana-dashboards/` to `monitoring-vm/grafana/provisioning/dashboards/`.
They are identical to Phase 1 — no changes needed.
