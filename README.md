# OT/IT Gyártásfelügyeleti Monitoring Rendszer

Beckhoff TwinCAT PLC adatokat gyűjt ADS protokollon, SQL Server-be és Prometheusba írja, Grafanán jeleníti meg.

```
PLC (ADS/TCP 48898) → Telegraf → [SQL Server + Prometheus /metrics]
                                              ↓
                                       Grafana dashboards
```

## Projekt struktúra

```
ot-monitoring/
├── phase1-laptop/        # PoC: WSL2 + Podman Desktop, egy gépen
├── phase2-vm-infra/      # Enterprise szimuláció: külön VM-ek (Collector, Monitoring, SQL)
└── shared/               # Közös Grafana dashboardok és SQL sémák
    ├── grafana-dashboards/
    └── sql/
```

---

## Phase 1 — Laptop / WSL2 PoC

### Előfeltételek

- Windows 11 + WSL2 (Fedora 43, podman-machine-default)
- Podman 5.8.2 + podman-compose 1.6.0
- SQL Server (opcionális, Windows-on SSMS-sel)

### Telepítés

```bash
git clone <repo-url>
cd ot-monitoring/phase1-laptop
cp ../.env.example .env
# Szerkeszd a .env fájlt (Grafana jelszó, SQL kapcsolati adatok)

# Hálózat létrehozása (egyszer kell, vagy teljes törlés után):
podman network create --disable-dns --subnet 10.89.10.0/24 --gateway 10.89.10.1 monitoring_phase1

# Stack indítása
podman-compose up -d
```

> **WSL2 megjegyzés:** Az `aardvark-dns` megköveteli a systemd-t, ami nem érhető el a
> `podman-machine-default` Fedora 43 környezetben. A `docker-compose.yml` statikus IP-ket
> és `extra_hosts` bejegyzéseket használ ennek megkerülésére. RHEL 9 VM-en (Phase 2)
> ez a workaround eltávolítható.

### Ellenőrzés

```bash
podman-compose ps

curl http://localhost:8000/metrics   # PLC szimulátor — 3 gép metrikái
curl http://localhost:9273/metrics   # Telegraf kimenet
curl http://localhost:9090/-/healthy # Prometheus
```

Grafana: http://localhost:3000 — belépés: `admin` / `changeme_poc_2024`

Három dashboard érhető el (Factory POC mappa):
- **01 – Factory Overview** — gépenként állapot, throughput, selejt, ciklusidő
- **02 – Machine Detail** — egyetlen gép részletei, állapot timeline
- **03 – OEE & KPI** — OEE, Availability, Performance, Quality, MTBF becslés

### SQL aktiválás (opcionális)

1. SSMS-ben futtasd a `phase1-laptop/sql/` fájlokat sorban (01, 02, 03)
2. Hozz létre `telegraf_writer` SQL login-t és adj `db_datawriter` jogot
3. `.env`-ben állítsd be: `SQL_SERVER=host.docker.internal`
4. `phase1-laptop/telegraf/telegraf.conf`-ban kommenteld ki az `[[outputs.sqlserver]]` blokkot
5. `podman-compose restart telegraf`

### Stack leállítása

```bash
podman-compose down          # adatok megmaradnak
podman-compose down -v       # volume-ok is törlődnek (teljes reset)
```

---

## Phase 2 — VM-alapú Enterprise szimuláció

Lásd: [phase2-vm-infra/README.md](phase2-vm-infra/README.md)

Röviden: három VM szimulál egy on-prem + Azure vegyes környezetet:

| VM | Szerep | OS |
|---|---|---|
| collector-vm | Telegraf (ADS/PLC adatgyűjtő) | RHEL 9 / Rocky Linux 9 |
| monitoring-vm | Prometheus + Grafana | RHEL 9 / Rocky Linux 9 |
| sql-vm | SQL Server 2022 | RHEL 9 / Rocky Linux 9 |

### VM setup sorrend

```bash
# 1. SQL VM
ssh root@192.168.200.11
bash phase2-vm-infra/sql-vm/setup.sh
# Majd futtatsd a shared/sql/ szkripteket

# 2. Collector VM
ssh root@192.168.100.10
bash phase2-vm-infra/collector-vm/setup.sh

# 3. Monitoring VM
ssh root@192.168.200.10
bash phase2-vm-infra/monitoring-vm/setup.sh
podman-compose up -d
```

Hálózati terv és tűzfalszabályok: [phase2-vm-infra/network/](phase2-vm-infra/network/)

---

## Grafana dashboardok (közös forrás)

A `shared/grafana-dashboards/` mappa tartalmazza az egyetlen forrást.
Phase 1 és Phase 2 Grafana provisioning mappái ezekre mutatnak (Phase 1 szimlink,
Phase 2-ben a `setup.sh` másolja oda).

A dashboardok változtatás nélkül működnek mindkét fázisban.

---

## PoC → Enterprise átállás ellenőrzőlista

| Lépés | Teendő |
|---|---|
| PLC kapcsolat | `telegraf.conf`-ban `[[inputs.prometheus]]` → `[[inputs.ads]]` blokk |
| SQL | `.env`-ben `SQL_SERVER` a valódi SQL Server IP-re, SQL output aktiválás |
| Hálózat | Tűzfalszabályok alkalmazása a `network/firewall-rules.md` alapján |
| Grafana | `GF_SECURITY_ADMIN_PASSWORD` erős jelszóra cserélése |
| Volumes | `prometheus_data` és `grafana_data` persistent storage-ra (NFS/PVC) |

---

## Végeredmény ellenőrzőlista (Phase 1)

```
podman-compose up -d
```

- [ ] `http://localhost:8000/metrics` — 3 gép összes metrikája látszik
- [ ] `http://localhost:9273/metrics` — Telegraf továbbítja
- [ ] `http://localhost:9090/targets` — Prometheus: telegraf target UP
- [ ] `http://localhost:3000` — Grafana betölt, 3 dashboard elérhető
- [ ] Factory Overview: mindhárom gép adata látszik
- [ ] line2 láthatóan több leállást mutat mint line1 és line3
- [ ] Ciklusidő trend: line2 (~1200ms) > line1 (~900ms) > line3 (~750ms)
- [ ] 8+ óra után látható a degradáció a ciklusidő trendben
