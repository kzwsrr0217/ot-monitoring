# TwinCAT VM Telepitesi Utmutato — Phase 3

PLC engineernek szolo utmutato. Ez a VM szimulal egy valodi gepet:
automatikusan fut, micro-stopokat es fault allapotokat general.

---

## 1. VM letrehozasa (VMware Workstation Pro)

```
File --> New Virtual Machine --> Typical
Guest OS: Windows 10/11 x64
Disk: 60 GB (elegendo TwinCAT + XAE-hoz)
Memory: 4 GB minimum (8 GB ajanlott)
Network: Bridged (fontos: ne NAT -- a Collector VM-nek el kell ernie)
```

Windows telepites utan:
- open-vm-tools helyet VMware Tools ISO-t hasznalj (Windows gepen ez megy)
- Statikus IP beallitasa: `192.168.100.x` (VMnet2 tartomany, ne utkozzek)

---

## 2. TwinCAT 3 telepitese

```
1. Letoltes: https://www.beckhoff.com --> Downloads --> TwinCAT 3
   Telepito: TC31-Full-Setup.exe (aktualis verzio)

2. Telepites adminisztratotkent:
   - Komponensek: TwinCAT XAE (fejlesztokornyezet) + TwinCAT XAR (runtime)
   - Visual Studio Shell: igen (ha nincs Visual Studio)
   - Ujrainditas szukseges telepites utan

3. Trial licenc aktivalasa (7 nap, megujithato):
   TwinCAT XAE megnyitasa --> Solution Explorer --> SYSTEM --> License
   --> "Activate 7 Days Trial License"
   --> CAPTCHA megoldasa (szoveg beires)
   --> OK --> Ujrainditas
   Megujitasi mod: ugyanez, "Activate 7 Days Trial License" ismet
```

---

## 3. AMS Net ID es Router konfiguracioа

A Collector VM-nek (Linux) el kell ernie a TwinCAT VM-et ADS protokollon.

### Sajat AMS Net ID megkeresese

```
Talca --> TwinCAT ikon (kek fogaskerek) --> jobb klikk --> Router --> Edit Routes
Felul: "AMS Net Id of this system"  pl. 192.168.100.50.1.1
--> Ez kerul a .env TWINCAT_AMS_NET_ID mezojebe
```

### Collector VM hozzaadasa statikus route-kent

```
Edit Routes --> Add --> Static Route
  Name:       collector-vm
  AMS Net Id: 192.168.100.10.1.1   (Collector VM IP + .1.1)
  Address:    192.168.100.10        (Collector VM IP)
  Transport:  TCP/IP
--> OK
```

### Windows Firewall megnyitasa

```
Windows Defender Firewall --> Advanced Settings --> Inbound Rules --> New Rule
  Type:    Port
  Protocol: TCP
  Port:    48898
  Action:  Allow the connection
  Profile: Domain + Private (Private elegendo PoC-hoz)
  Name:    TwinCAT ADS Remote
```

---

## 4. PLC projekt letrehozasa

### Uj projekt

```
File --> New --> New Project
  Template: TwinCAT XAE Project (XML format)
  Nev:      OT_Monitoring_Simulator
  Hely:     C:\TwinCAT\Projects\  (vagy tetszoleges)
```

### PLC hozzaadasa

```
Solution Explorer --> PLC --> Add New Item
  Template: Standard PLC Project
  Nev:      SimulationPLC
```

### GVL letrehozasa

```
SimulationPLC --> GVLs --> Add --> Global Variable List
  Nev: GVL_Monitoring

Tartalom (GVL_Monitoring.TcGVL fajlbol masold be):
```
```
{attribute 'qualified_only'}
VAR_GLOBAL
    xMachineON          : BOOL;
    xProductionRun      : BOOL;
    xMachineErrorState  : BOOL;
    nOK_Counter         : DINT;
    nNOK_Counter        : DINT;
    nCycleCount         : UDINT;
    nProdType           : INT;
    nLastCycleTimeMs    : UDINT;
    nLastStoppageTimeMs : UDINT;
END_VAR
```

### Enum letrehozasa

```
SimulationPLC --> DUTs --> Add --> DUT
  Type: Enumeration
  Nev:  E_MachineState

Tartalom (SimulationPLC.TcPOU felso reszbol):
```
```pascal
TYPE E_MachineState :
(
    IDLE       := 0,
    RUNNING    := 1,
    MICRO_STOP := 2,
    LONG_STOP  := 3,
    FAULT      := 4
);
END_TYPE
```

### MAIN POU megnyitasa es feltoltese

```
SimulationPLC --> POUs --> MAIN (kattints dupla klikkel)
Torold ki az alapertelmezett tartalmat.
Masold be a SimulationPLC.TcPOU PROGRAM MAIN reszet
(a VAR blokkot es a kod testet).
```

### Task cycle time beallitasa

```
SYSTEM --> Tasks --> PlcTask --> Cycle time: 10 ms
```

---

## 5. Aktivalas es inditás

```
1. Build --> Activate Configuration  (F8)
   Megkerdezi: "Restart TwinCAT System?" --> Yes

2. PLC --> Login  (F11)
   Kapcsolodas a runtime-hoz

3. PLC --> Run  (F5)
   PLC elindul, valtozok frissulnek

4. Ellenorzes:
   - Talcaikon ZOLD = RUN mod (mukodik)
   - KEK = Config mod (meg nem fut -- F5 szukseges)
   - PIROS = Hiba -- ellenorizd a fordito kimenetelt
```

Online monitor: dupla klikk barmely valtozora --> Watch Window hozzaadasa.
`GVL_Monitoring.nOK_Counter` masodpercenkent novekszik-e?

---

## 6. Hibaelharites

```
HIBA: ping 192.168.100.50 nem megy a Collector VM-rol
--> VM Network Adapter: Bridged legyen (VMware Settings --> Network)
--> Windows Firewall: ICMP (ping) engedelyezes
    Inbound Rules --> New --> Custom --> ICMPv4 --> Allow

HIBA: "ADS connection timeout" (ads-test.py-ban)
--> TCP 48898 tuzfalszabaly hianzik (3. lepés)
--> TwinCAT nem RUN modban --> F5

HIBA: "Route not found"
--> Edit Routes: Collector VM IP (192.168.100.10) nincs hozzaadva
--> COLLECTOR_AMS_NET_ID a .env-ben nem stimmel (pontosan: 192.168.100.10.1.1)

HIBA: "Symbol not found: GVL_Monitoring.xMachineON"
--> PLC nincs aktiválva: Build --> Activate Configuration (F8)
--> Ellenorizd a nagybetu/kisbetu: GVL_Monitoring (nem gvl_monitoring)
--> PLC nem fut: F5

HIBA: "Access denied" ADS olvasasnal
--> TwinCAT license lejart --> Activate 7 Days Trial License ismet
```

---

## 7. Ellenorzes ads-test.py-val

A Collector VM-rol (SSH-val belépve):

```bash
# pip telepit (ha meg nincs)
pip3 install pyads --user

# Teszt futtatasa (a .env valtozok alapjan)
source /opt/ot-monitoring/telegraf/.env
export TWINCAT_VM_IP TWINCAT_AMS_NET_ID TWINCAT_AMS_PORT
python3 /tmp/ads-test.py
```

Elvart kimenet:
```
=======================================================
  ADS Kapcsolat Teszt --- Phase 3
=======================================================
  Target:  192.168.100.50
  AMS ID:  192.168.100.50.1.1:851
=======================================================

[OK] ADS kapcsolat OK

Valtozok olvasasa:
-------------------------------------------------------
  [OK]  GVL_Monitoring.xMachineON    = True
  [OK]  GVL_Monitoring.xProductionRun = True
  ...
  [OK]  SIKERES --- Telegraf konfig atvalthato ADS-re
```

Ha minden zold --> atmehet a `collector-vm-patch/README.md` szerinti atallas.
