# Firewall Rules — OT Monitoring System

Provide this document to the network team when deploying Phase 2.

## Architecture

```
[OT VLAN: 192.168.10.0/24]     [DMZ / Collector VM]     [IT LAN]
  PLC / IPC (TwinCAT)      →   Telegraf :9273        →   Prometheus :9090
  ADS port 48898               SQL output port 1433  →   SQL Server :1433
                                                          Grafana :3000  ← Clients
```

## Required Rules

### PLC → Collector VM (inbound on Collector)

| Protocol | Port  | Direction         | Source            | Destination    | Purpose                  |
|----------|-------|-------------------|-------------------|----------------|--------------------------|
| TCP      | 48898 | OT VLAN → Collector | 192.168.10.0/24 | Collector VM   | Beckhoff ADS/TwinCAT     |

### Collector VM → SQL Server (outbound from Collector)

| Protocol | Port  | Direction              | Source       | Destination | Purpose             |
|----------|-------|------------------------|--------------|-------------|---------------------|
| TCP      | 1433  | Collector → SQL Server | Collector VM | SQL VM      | Telegraf SQL output |

### Monitoring VM → Collector VM (outbound from Monitoring)

| Protocol | Port | Direction               | Source         | Destination  | Purpose               |
|----------|------|-------------------------|----------------|--------------|------------------------|
| TCP      | 9273 | Monitoring → Collector  | Monitoring VM  | Collector VM | Prometheus scrape      |

### Clients → Monitoring VM (inbound on Monitoring)

| Protocol | Port | Direction             | Source        | Destination    | Purpose          |
|----------|------|-----------------------|---------------|----------------|------------------|
| TCP      | 3000 | Clients → Monitoring  | IT LAN / VPN  | Monitoring VM  | Grafana dashboard |
| TCP      | 9090 | Admin → Monitoring    | Admin hosts   | Monitoring VM  | Prometheus UI     |

### NTP (all VMs)

| Protocol | Port | Direction | Purpose         |
|----------|------|-----------|-----------------|
| UDP      | 123  | Both      | NTP time sync   |

## Notes

- Keep ADS (48898) strictly limited to OT VLAN — never expose to IT LAN.
- Grafana can be fronted by an HTTPS reverse proxy (nginx/HAProxy) on port 443 instead of 3000.
- SQL Server (1433) must never be reachable from the internet.
- For Raspberry Pi kiosk mode: allow TCP 3000 from the Raspberry Pi's IP only.
