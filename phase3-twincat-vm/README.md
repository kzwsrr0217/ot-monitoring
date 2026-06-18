# Phase 3 — TwinCAT VM bekotese a monitoringba

A 2. fazis fut es tesztelve van. Ez a fazis egyetlen valtozast hoz:
a Python szimulator helyett egy valodi TwinCAT PLC szimulal egy gepet,
es a Collector VM Telegraf konfigja ADS protokollon olvassa.

**Semmi mas nem valtozik** --- ez bizonyitja a portabilitast.

---

## Mi valtozik a 2. fazishoz kepest

| Komponens         | Phase 2                           | Phase 3                  | Teendo                    |
|-------------------|-----------------------------------|--------------------------|---------------------------|
| TwinCAT VM        | nincs                             | Windows VM, TC3 XAR+XAE  | PLC engineer telepiti      |
| Telegraf input    | `[[inputs.prometheus]]` Python    | `[[inputs.ads]]` TwinCAT | Collector VM konfig csere  |
| Collector VM      | valtozatlan                       | valtozatlan              | csak .env + konfig csere   |
| Monitoring VM     | valtozatlan                       | valtozatlan              | semmi                      |
| SQL VM            | valtozatlan                       | valtozatlan              | semmi                      |
| Grafana dashboardok | valtozatlan                     | valtozatlan              | semmi                      |
| SQL sema          | valtozatlan                       | valtozatlan              | semmi                      |

---

## Infrastruktura attekintest

```
[TwinCAT VM]                [Collector VM]          [Monitoring VM]
Windows + TC3 XAR    ADS    Rocky Linux 9    Prom    Rocky Linux 9
GVL_Monitoring    ------->  Telegraf      ------->   Prometheus
SimulationPLC    TCP 48898  [[inputs.ads]]  :9273     Grafana :3000
192.168.100.50              192.168.100.10            192.168.100.20
                                  |
                                  | SQL
                                  v
                            [SQL VM]
                            Rocky Linux 9
                            SQL Server 2022
                            192.168.100.30
```

VMware halozat: VMnet2 (Host-only, 192.168.100.0/24)
TwinCAT VM: **Bridged adapter** (hogy a Collector VM TCP-n elerhesse)

---

## Elvegzendo lepesek sorrendben

### Lepés 1 — TwinCAT VM (PLC engineer)

Lasd: `twincat/README.md`

```
1a. VMware VM letrehozasa (Windows 10/11, Bridged halozat)
1b. Statikus IP beallitasa: 192.168.100.50 (vagy mas szabad cim VMnet2-n)
1c. TwinCAT 3 XAE + XAR telepitese
1d. Trial licenc aktivalasa
1e. AMS Net ID feljegyzes (.env-be kerul)
1f. Collector VM statikus route hozzaadasa
1g. Windows Firewall: TCP 48898 megnyitas
1h. PLC projekt letrehozasa (GVL + Enum + MAIN POU)
1i. Build --> Activate (F8) --> Login (F11) --> Run (F5)
```

### Lepés 2 — ADS kapcsolat tesztelese

A Collector VM-rol (SSH: `ssh root@192.168.100.10`):

```bash
# pyads telepitese
pip3 install pyads --user

# SCP-vel masold fel a tesztszkriptet
# (Windows hostrol: scp phase3-twincat-vm\twincat\ads-test.py root@192.168.100.10:/tmp/)

# .env valtozok betoltese
source /opt/ot-monitoring/telegraf/.env
export TWINCAT_VM_IP TWINCAT_AMS_NET_ID TWINCAT_AMS_PORT

# Teszt futtatasa
python3 /tmp/ads-test.py
```

**CSAK akkor megy tovabb ha minden valtozo zold.**

### Lepés 3 — Telegraf konfig csere (Collector VM)

Lasd: `collector-vm-patch/README.md`

```bash
# Uj valtozok hozzaadasa a .env-hez
nano /opt/ot-monitoring/telegraf/.env

# Konfig csere (backup utan)
cp /opt/ot-monitoring/telegraf/telegraf.conf telegraf.conf.phase2.bak
cp /tmp/telegraf-ads.conf /opt/ot-monitoring/telegraf/telegraf.conf

# Ujrainditas
sudo systemctl restart telegraf-podman
```

### Lepés 4 — Ellenorzes

```bash
# Collector VM-en
podman logs telegraf --tail 30
curl -s http://localhost:9273/metrics | grep machine_telemetry

# Grafana bongeszobol
http://192.168.100.20:3000
# Factory Overview: nOK_Counter novelkedik-e?
# Machine Status: xProductionRun valtozik micro-stop alatt?
```

---

## Elfogadasi kriteriumok

- [ ] `ads-test.py`: minden 9 valtozo olvasaas OK, folyamatos olvasas stabil
- [ ] Telegraf log: ADS adatok erkeznek, nincs "connection error" vagy "timeout"
- [ ] Prometheus `/metrics`: `machine_telemetry` metrika megjelenik
- [ ] Grafana Factory Overview: `ok_count` novelkedik valós idoben
- [ ] Grafana: micro-stop alatt `production_run = 0` latszik a dashboardon
- [ ] Grafana: fault alatt `machine_error_state = 1` latszik
- [ ] SQL `machine_telemetry` tabla: sorok erkeznek UTC timestamppel
- [ ] **Monitoring VM-en es SQL VM-en semmilyen valtoztatas nem volt szukseges**
      (ez a portabilitas bizonyiteka)

---

## Mappastruktura

```
phase3-twincat-vm/
├── README.md                         <- ez a fajl
├── .env.example                      <- uj valtozok a Collector VM .env-jehez
│
├── twincat/
│   ├── README.md                     <- TwinCAT VM telepitesi utmutato (magyar)
│   ├── GVL_Monitoring.TcGVL          <- Global Variable List (TwinCAT formatumu)
│   ├── SimulationPLC.TcPOU           <- Szimulacis PLC program (Structured Text)
│   └── ads-test.py                   <- ADS kapcsolat tesztelő (python3 + pyads)
│
└── collector-vm-patch/
    ├── README.md                     <- Pontosan mit kell csinalni (operacios checklist)
    └── telegraf-ads.conf             <- Uj Telegraf konfig (inputs.ads alapu)
```
