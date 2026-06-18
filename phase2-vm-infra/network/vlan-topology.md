# VLAN Topology — OT Monitoring System

## Network Segments

| VLAN | Name           | Subnet              | Purpose                           |
|------|----------------|---------------------|-----------------------------------|
| 10   | OT-LOW         | 192.168.10.0/24     | PLCs on line1 & line3 (low speed) |
| 20   | OT-MEDIUM      | 192.168.20.0/24     | PLCs on line2 (medium speed)      |
| 100  | COLLECTOR      | 192.168.100.0/24    | Collector VM (dual-homed: OT+IT)  |
| 200  | IT-MONITORING  | 192.168.200.0/24    | Monitoring VM + SQL VM            |

## Host Addresses

| Host                  | VLAN     | IP                   | Role                            |
|-----------------------|----------|----------------------|---------------------------------|
| line1-plc             | OT-LOW   | 192.168.10.101       | Beckhoff TwinCAT PLC            |
| line3-plc             | OT-LOW   | 192.168.10.103       | Beckhoff TwinCAT PLC            |
| line2-plc             | OT-MED   | 192.168.20.102       | Beckhoff TwinCAT PLC            |
| collector-vm          | COLL     | 192.168.100.10       | Telegraf (multi-homed to OT VLANs) |
| monitoring-vm         | IT-MON   | 192.168.200.10       | Prometheus + Grafana            |
| sql-vm                | IT-MON   | 192.168.200.11       | SQL Server 2022                 |

## Routing / Firewall Policy

```
OT-LOW   → COLLECTOR:  ADS/TCP 48898 ALLOW  (line1, line3)
OT-MED   → COLLECTOR:  ADS/TCP 48898 ALLOW  (line2)
COLLECTOR → IT-MON:    SQL/TCP 1433  ALLOW  (to sql-vm)
IT-MON   → COLLECTOR:  TCP 9273      ALLOW  (Prometheus scrape from monitoring-vm)
ANY      → ANY:        DENY (default)
```

## PoC Simulation Mapping

In the Phase 1 laptop PoC, all VLANs are simulated by a single Docker network
(`monitoring_phase1` on 10.89.10.0/24) with one Python `simulator` container
serving all three machines. The `vlan` label in Prometheus metrics (low/medium)
tracks which VLAN a machine would be on in production.

## VMware Workstation Lab (Phase 2 on single laptop)

All VMs share one VMnet2 Host-only network (`192.168.100.0/24`). The multi-VLAN
segmentation is logical only (via Telegraf tags), not enforced at the network layer.

| Host              | IP               | VMware adapter | Role                         |
|-------------------|------------------|----------------|------------------------------|
| Laptop (host)     | 192.168.100.1    | VMnet2 host    | Runs Phase 1 simulator :8000 |
| collector-vm      | 192.168.100.10   | VMnet2         | Telegraf, polls simulator    |
| monitoring-vm     | 192.168.100.20   | VMnet2         | Prometheus + Grafana         |
| sql-vm            | 192.168.100.30   | VMnet2         | SQL Server 2022              |

Each VM also has a second NAT adapter (VMnet8) for internet access during setup.
Remove or disable it after `dnf` installs are complete.

Data flow in the lab:

```
Laptop :8000 (simulator)
    ↓  HTTP poll every 1s
collector-vm :9273 (Telegraf)
    ↓  Prometheus scrape every 15s        ↓  SQL write
monitoring-vm :9090/:3000                sql-vm :1433
(Prometheus + Grafana)
```
