# Collector VM atallas --- Phase 2 -> Phase 3

Pontosan ezt kell elvegezni a Collector VM-en (192.168.100.10).
Semmi mas nem valtozik --- Monitoring VM, SQL VM, Grafana marad.

---

## Elofeltetel-ellenorzes

- [ ] `ads-test.py` sikeresen lefutott a Collector VM-rol (minden valtozo zold)
- [ ] TwinCAT VM fut, PLC RUN modban van (talcaikon zold)
- [ ] Collector VM eleri a TwinCAT VM-et: `ping ${TWINCAT_VM_IP}`
- [ ] Windows Firewall: TCP 48898 nyitva a TwinCAT VM-en
- [ ] TwinCAT Router: Collector VM IP (192.168.100.10) engedelyezve

---

## Lepesek

### 1. Uj kornyezeti valtozok hozzaadasa

```bash
# SSH a Collector VM-re
ssh root@192.168.100.10

# .env szerkesztese
nano /opt/ot-monitoring/telegraf/.env
```

Add hozza a `.env.example` tartalmat kitoltott ertekekkel:

```
TWINCAT_VM_IP=192.168.x.x          # a TwinCAT VM valodi IP-je
TWINCAT_AMS_NET_ID=192.168.x.x.1.1 # TwinCAT AMS Net ID
TWINCAT_AMS_PORT=851
COLLECTOR_AMS_NET_ID=192.168.100.10.1.1
MACHINE_ID=line1
MACHINE_VLAN=low
```

### 2. Telegraf konfig csere

```bash
# Backup a phase2 konfigrol
cp /opt/ot-monitoring/telegraf/telegraf.conf \
   /opt/ot-monitoring/telegraf/telegraf.conf.phase2.bak

# Uj konfig masolasa (SCP-vel elobb masold fel a fajlt /tmp-be)
cp /tmp/telegraf-ads.conf \
   /opt/ot-monitoring/telegraf/telegraf.conf
```

SCP a Windows hostrol:
```powershell
scp phase3-twincat-vm\collector-vm-patch\telegraf-ads.conf root@192.168.100.10:/tmp/
```

### 3. Telegraf ujrainditas

```bash
sudo systemctl restart telegraf-podman
sudo systemctl status telegraf-podman
# Ellenorzend: Active: active (running)
```

### 4. Ellenorzes

```bash
# Adatok erkeznek-e ADS-bol (var ~10 masodpercet)
podman logs telegraf --tail 30

# Prometheus endpoint tartalmaz-e machine_telemetry metrikat
curl http://localhost:9273/metrics | grep machine_telemetry

# Egy adott mezo
curl -s http://localhost:9273/metrics | grep machine_on
```

Grafana (bongeszobol): http://192.168.100.20:3000
- Factory Overview dashboard: `nOK_Counter` novelkedik-e?
- Machine Status panel: `xProductionRun` TRUE/FALSE valtozik-e?

### 5. Visszaallas (ha valami nem mukodik)

```bash
cp /opt/ot-monitoring/telegraf/telegraf.conf.phase2.bak \
   /opt/ot-monitoring/telegraf/telegraf.conf
sudo systemctl restart telegraf-podman
```

A phase2 konfig visszatolt, Python szimulator adatait scrape-eli megint.

---

## Mi NEM valtozik

| Komponens      | Teendo          |
|----------------|-----------------|
| Monitoring VM  | Semmi           |
| SQL VM         | Semmi           |
| Grafana        | Semmi           |
| SQL sema       | Semmi           |
| Prometheus     | Semmi           |
| systemd service| Semmi           |

A Telegraf service (`telegraf-podman`) maga nem valtozik --- csak a
konfig fajl es a .env bovul uj valtozokkal.
