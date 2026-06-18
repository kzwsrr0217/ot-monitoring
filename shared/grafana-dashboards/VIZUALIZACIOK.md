# Grafana vizualizációk — teljes leírás

Ez a dokumentum felsorolja az összes dashboardot, panelt és adatsort, pontosan
leírva, hogy mit ábrázol, miből számítja, és miért hasznos.

---

## Adatforrások

Minden panel a **Prometheus** adatbázisból olvas, amelyet a **Telegraf** tölt fel
a PLC szimulátorból (Phase 2: HTTP scrape; Phase 3: ADS protokoll).

**9 alap PLC változó → minden panel:**

| PLC változó | Prometheus metric | Típus |
|---|---|---|
| xMachineON | `machine_on` | gauge (0/1) |
| xProductionRun | `production_run` | gauge (0/1) |
| xMachineErrorState | `machine_error_state` | gauge (0/1) |
| nOK_Counter | `ok_counter_total` | counter (növekvő) |
| nNOK_Counter | `nok_counter_total` | counter (növekvő) |
| nCycleCount | `cycle_count_total` | counter (növekvő) |
| nProdType | `prod_type` | gauge (1/2/3) |
| nLastCycleTimeMs | `last_cycle_time_ms` | gauge (ms) |
| nLastStoppageTimeMs | `last_stoppage_time_ms` | gauge (ms) |

Minden metrikán jelen lévő label-ek: `machine_id`, `site`, `environment`, `vlan`.

---

## 01 – Factory Overview / 07 – Gyárfelügyelet (Mérnöki)

**Mappa:** Mérnöki nézet / Mérnöki nézet (HU)  
**Frissítés:** 5 másodpercenként  
**Célja:** Egyszerre látni az összes gép állapotát, tempóját és selejt arányát.

### Gép BE/KI — stat panel

- **Metric:** `machine_on{machine_id=~"$machine_id"}`
- **Mit mutat:** A gép fizikailag be van-e kapcsolva (1 = BE zöld, 0 = KI piros).
- **Miért hasznos:** Azonnal látszik, melyik gép nem kapott tápot vagy leállt a
  vezérlés szintjén — ez termelési leállástól függetlenül mutatja a hardware státuszt.

### Termelés folyamatban — stat panel

- **Metric:** `production_run{machine_id=~"$machine_id"}`
- **Mit mutat:** A gép aktívan gyárt-e (1 = TERMEL zöld, 0 = LEÁLLT narancs).
- **Miért hasznos:** Megkülönbözteti a "gép be van, de nem termel" esetet a
  "gép ki van kapcsolva" esettől.

### Hibás állapot — stat panel

- **Metric:** `machine_error_state{machine_id=~"$machine_id"}`
- **Mit mutat:** Fennáll-e aktív hibajelzés (0 = RENDBEN zöld, 1 = HIBA piros).
- **Miért hasznos:** Azonnali riasztás, ha a PLC hibakódot adott ki.

### Termelési tempó (db/perc) — timeseries

- **Metric:** `rate(ok_counter_total{machine_id=~"$machine_id"}[1m]) * 60`
- **Mit mutat:** Az utolsó 1 perc alatt hány OK darabot gyártott a gép percenként.
- **Számítás:** `rate()` a counter növekedési sebességét adja meg (darab/másodperc),
  szorozva 60-cal → darab/perc.
- **Miért hasznos:** Azonnal látszik, ha a tempó leesett (leállás, lassulás, minőségi
  probléma), és összehasonlítható gépenként.

### Műszak termelés (8 óra) — stat panel

- **Metric:** `increase(ok_counter_total{machine_id=~"$machine_id"}[8h])`
- **Mit mutat:** Hány OK darabot gyártott a gép az elmúlt 8 órában.
- **Számítás:** `increase()` a counter teljes változását adja meg az időablakban.
- **Miért hasznos:** Egy műszak termelt mennyiségének azonnali áttekintése,
  összehasonlítható a tervvel.

### Selejt arány % (5 perc) — gauge (kördiagram)

- **Metric:** `rate(nok_counter_total[5m]) / clamp_min(rate(ok_counter_total[5m]) + rate(nok_counter_total[5m]), 0.001) * 100`
- **Mit mutat:** Az elmúlt 5 percben gyártott darabok hány %-a volt selejt.
- **Számítás:** NOK ráta osztva a teljes (OK+NOK) rátával, szorozva 100-zal.
  `clamp_min(..., 0.001)` megakadályozza a nullával való osztást ha nincs adat.
- **Küszöbök:** 0–2% zöld, 2–5% sárga, 5%+ piros.
- **Miért hasznos:** Minőségi trendek korai jelzése — 5 perces ablak elég gyors
  a beavatkozáshoz, de kiszűri az egyszeri kiugrásokat.

### Ciklusidő trend — timeseries

- **Metric:** `last_cycle_time_ms{machine_id=~"$machine_id"}`
- **Mit mutat:** Az utoljára mért ciklusidő ezredmásodpercben.
- **Miért hasznos:** A ciklusidő növekedése jelzi a gép lassulását (elhasznált
  alkatrész, beállási probléma). Gépenként különböző a normál ciklusidő:
  line1 ~900ms, line2 ~1200ms, line3 ~750ms.

### Gépállapot és leállás időtartam — táblázat

- **Metric A (instant):** `production_run` — gép státusza most
- **Metric B (instant):** `last_stoppage_time_ms` — utolsó leállás időtartama ms-ban
- **Mit mutat:** Összes gép aktuális státusza és az utolsó leállásuk időtartama
  egy táblázatban, szűrhető és rendezhető.
- **Miért hasznos:** Operátor egyszerre látja melyik gép áll és mennyi ideje.

---

## 02 – Machine Detail / 05 – Gép részletek / 08 – Gép részletek (Mérnöki)

**Mappa:** Mérnöki nézet / Termelési nézet / Mérnöki nézet (HU)  
**Szűrő:** `$machine_id` — egy vagy több gép kiválasztható  
**Frissítés:** 5 másodpercenként  
**Célja:** Egyetlen gép részletes elemzése — diagnózis, trendek, ciklusidő statisztika.

### Gépállapot idővonal — timeseries (lépcsős)

- **Metric A:** `production_run` — termelési állapot (0/1)
- **Metric B:** `machine_error_state` — hibaállapot (0/1)
- **Mit mutat:** A gép állapotának időbeli változása lépcsős vonaldiagramon.
  Zöld kitöltés = termelés fut, piros kitöltés = hiba aktív.
- **Miért hasznos:** Visszanézhető az elmúlt 1 órában mikor és mennyi ideig állt
  a gép, és mikor volt hibaállapotban. Időkorrelált eseményeket mutat meg.

### Ciklusidő eloszlás — histogram

- **Metric:** `last_cycle_time_ms{machine_id=~"$machine_id"}`
- **Mit mutat:** Hány mérési pont esett az egyes ciklusidő-tartományokba
  (pl. 800–850ms, 850–900ms stb.).
- **Miért hasznos:** Megmutatja, mennyire stabil a folyamat. Szűk, egycsúcsos
  eloszlás = stabil. Széles vagy kétcsúcsos = instabil, valószínűleg két
  különböző gyártott termék (nProdType) vagy gépkopás.

### Ciklusidő + Gördülő átlag (5 perc) — timeseries

- **Metric A:** `avg_over_time(last_cycle_time_ms[5m])` — 5 perces mozgóátlag
- **Metric B:** `last_cycle_time_ms` — pillanatnyi mérés
- **Mit mutat:** Az aktuális ciklusidő és az 5 perces simítás egyszerre.
  A simított vonal kiszűri az egyszeri kiugrásokat és a valódi trendet mutatja.
- **Miért hasznos:** Ha a simított vonal felfelé tart, a gép fokozatosan lassul —
  ez megelőző karbantartásra utalhat.

### OK vs Selejt arány (db/perc) — vízszintes bargauge

- **Metric OK:** `rate(ok_counter_total[5m]) * 60` — jó darabok percenként
- **Metric NOK:** `rate(nok_counter_total[5m]) * 60` — selejt percenként
- **Mit mutat:** Az elmúlt 5 percben hány jó és hány selejt darabot gyártott a gép.
- **Miért hasznos:** Azonnali képet ad a minőségről számszerűen — 60 db/perc jó,
  5 db/perc selejt stb. Gépenként összehasonlítható.

### Leállás időtartam (ms) — timeseries (lépcsős)

- **Metric:** `last_stoppage_time_ms{machine_id=~"$machine_id"}`
- **Mit mutat:** Az utoljára mért leállás időtartamának idősora ezredmásodpercben.
- **Miért hasznos:** Látszik, hogy a leállások rövidek (mikro-leállás < 30s)
  vagy hosszabbak (valódi meghibásodás). A `max` statisztika a leghosszabb
  leállást mutatja az adott időablakban.

### Termelési tempó vs Ciklusidő (kettős Y) — timeseries

- **Metric TP (bal Y):** `rate(ok_counter_total[1m]) * 60` — tempó (db/perc)
- **Metric CT (jobb Y):** `last_cycle_time_ms` — ciklusidő (ms)
- **Mit mutat:** A termelési tempó és a ciklusidő inverz kapcsolata egyszerre
  látható. Ha a ciklusidő nő, a tempó csökken — és fordítva.
- **Miért hasznos:** Azonosítható, hogy a tempócsökkenés valóban a ciklusidő
  növekedéséből ered-e, vagy más okból (pl. leállások, hiányzó anyag).

---

## 03 – OEE & KPI / 06 – OEE és KPI / 09 – OEE és KPI (Mérnöki)

**Mappa:** Mérnöki nézet / Vezetői KPI / Mérnöki nézet (HU)  
**Frissítés:** 5 másodpercenként  
**Célja:** Gyárszintű hatékonyság mutatók — OEE és összetevői.

> **OEE = Rendelkezésre állás × Teljesítmény × Minőség**  
> Ipari benchmark: 85%+ world-class, 65–85% átlagos, <65% fejlesztendő.

### OEE % (8 órás becslés) — körmutató (gauge)

- **Számítás (egyetlen PromQL):**
  ```
  avg_over_time(production_run[8h])               ← Rendelkezésre állás
  × clamp_max(900 / avg_over_time(last_cycle_time_ms[8h]), 1)   ← Teljesítmény
  × (rate(ok_counter_total[8h]) / (rate(ok_counter_total[8h]) + rate(nok_counter_total[8h])))  ← Minőség
  × 100
  ```
- **Mit mutat:** Az elmúlt 8 óra átlagos OEE értéke százalékban.
- **Küszöbök:** <65% piros, 65–85% sárga, 85%+ zöld.
- **Miért hasznos:** Egyetlen szám, ami a gyártási hatékonyság összesített mutatója.
  Ha alacsony, az OEE összetevők (A, P, Q) mutatják hol a probléma.

### Rendelkezésre állás % (8 óra) — stat panel

- **Metric:** `avg_over_time(production_run{machine_id=~"$machine_id"}[8h]) * 100`
- **Mit mutat:** Hány % -ban volt termelési állapotban a gép az elmúlt 8 órában.
  Pl. 85% = 8 órából 6,8 óra termelés.
- **Küszöbök:** <80% piros, 80–90% sárga, 90%+ zöld.
- **Miért hasznos:** Megmutatja az összes leállás (tervezett + nem tervezett)
  összesített hatását. Ez az OEE első tényezője.

### Teljesítmény % (ideális alap: 900ms) — stat panel

- **Metric:** `clamp_max(900 / clamp_min(avg_over_time(last_cycle_time_ms[5m]), 1), 100) * 100`
- **Mit mutat:** A tényleges ciklusidő viszonya az ideális 900ms-hoz.
  Ha a gép 900ms-ban gyárt → 100%. Ha 1200ms-ban gyárt → 75%.
- **Küszöbök:** <75% piros, 75–90% sárga, 90%+ zöld.
- **Megjegyzés:** `clamp_max(..., 100)` megakadályozza, hogy 100% fölé menjen
  (pl. ha a gép az ideálisnál gyorsabban fut).
- **Miért hasznos:** A sebesség-veszteség mutatója. Az OEE második tényezője.

### Minőség % (5 perc) — stat panel

- **Metric:** `rate(ok_counter_total[5m]) / clamp_min(rate(ok_counter_total[5m]) + rate(nok_counter_total[5m]), 0.001) * 100`
- **Mit mutat:** Az elmúlt 5 percben termelt darabok hány %-a volt jó.
- **Küszöbök:** <95% piros, 95–98% sárga, 98%+ zöld.
- **Miért hasznos:** A minőségi veszteség mutatója. Az OEE harmadik tényezője.

### MTBF becslés (8 óra, órában) — stat panel

- **Metric:** `avg_over_time(production_run[8h]) * 8 / clamp_min(changes(production_run[8h]) / 2, 1)`
- **Mit mutat:** Mean Time Between Failures — átlagos meghibásodások közötti idő.
  `changes(production_run[8h]) / 2` = leállások száma (minden 1→0→1 átmenet = 1 leállás).
  Teljes üzemidő osztva leállások számával = MTBF.
- **Miért hasznos:** Ha az MTBF csökken, a gép egyre gyakrabban áll le —
  megelőző karbantartás szükséges.

### Leállási események (utolsó 1 óra) — stat panel (háttérszín)

- **Metric:** `changes(production_run{machine_id=~"$machine_id"}[1h]) / 2`
- **Mit mutat:** Hányszor állt le és indult újra a gép az elmúlt 1 órában.
  `changes()` az összes értékváltást számolja (0→1 és 1→0 is), osztva 2-vel = leállások.
- **Küszöbök:** 0–5 zöld, 5–15 sárga, 15+ piros háttér.
- **Miért hasznos:** Magas érték esetén a gép "chatterel" — figyelmeztet, mielőtt
  a probléma komolyabbá válna.

### Mikro-leállások < 30mp (utolsó 1 óra) — stat panel (háttérszín)

- **Metric:** `count_over_time((last_stoppage_time_ms > 0 and last_stoppage_time_ms < 30000)[1h:15s])`
- **Mit mutat:** Hány olyan pillanat volt az elmúlt 1 órában, amikor a leállás
  időtartama 0 és 30000ms (30 másodperc) között volt — 15 másodperces mintavételezéssel.
- **Küszöbök:** 0–10 zöld, 10–30 sárga, 30+ piros.
- **Miért hasznos:** A mikro-leállások (rövid, nem naplózott megakadások) rejtett
  hatékonyságveszteséget okoznak. Ez a panel egyedi insight — hagyományos
  gyárnaplók ezeket nem rögzítik.

### OEE összehasonlítás gépenként — vízszintes oszlopdiagram

- **Metric:** Ugyanaz mint az OEE gauge (kombinált PromQL), de gépenként külön sáv.
- **Mit mutat:** Az összes kiválasztott gép OEE értéke egymás mellett, összehasonlítható.
- **Miért hasznos:** Azonnal kiderül melyik gép a "bottleneck" a termelési sorban.

### Rendelkezésre állás trend (5 perces gördülő) — timeseries

- **Metric:** `avg_over_time(production_run{machine_id=~"$machine_id"}[5m]) * 100`
- **Mit mutat:** A rendelkezésre állás 5 percenként gördülő átlaga az elmúlt 1 órában.
- **Küszöbök (vonal):** 85% alatt piros, 65% alatt sárga jel a grafikonon.
- **Miért hasznos:** Látszik, hogy egy leállás egyszeri esemény volt-e vagy tendencia.
  Több gép görbéje egyszerre látható — korrelált leállásokat jelez (pl. anyagellátás
  vagy közös segédrendszer problémája).

---

## Változó szűrők (minden dashboardon)

### `$machine_id` legördülő

- **Forrás:** `label_values(machine_on, machine_id)` — Prometheus-ból automatikusan
  tölti be az összes ismert gépnevet.
- **Alapértelmezett:** All (mind a három gép egyszerre látható)
- **Működés:** A panel lekérdezésekben `machine_id=~"$machine_id"` regex szűrőként
  jelenik meg. "All" esetén `.*` regex — minden gép adatát mutatja.

---

## Időablak és frissítés

- **Alapértelmezett időablak:** Utolsó 1 óra (`now-1h` → `now`)
- **Frissítési ütem:** 5 másodperc (valós idejű monitorozáshoz)
- **Ajánlott nézetek:**
  - Élő monitorozás: 5–15 perc ablak, 5s frissítés
  - Műszak értékelés: 8 óra ablak
  - Nap végi riport: 24 óra ablak

---

## Metrikák számítási megjegyzései

| Fogalom | Számítás | Megjegyzés |
|---|---|---|
| Termelési tempó | `rate(ok_counter_total[1m]) * 60` | Darab/perc, 1 perces ablak |
| Selejt arány | `rate(nok_total[5m]) / (rate(ok_total[5m]) + rate(nok_total[5m])) * 100` | 5 perces ablak |
| OEE | `Availability × Performance × Quality × 100` | 8 órás becslés |
| Availability | `avg_over_time(production_run[8h])` | Arány, nem % |
| Performance | `min(900 / avg_cycle_time, 1)` | 900ms az ideális ciklusidő |
| Quality | `rate(ok_total[8h]) / rate(total[8h])` | 8 órás ablak |
| MTBF | `uptime_hours / stoppage_count` | Becsült, nem pontos |
| Micro-stoppages | Leállások ahol 0 < időtartam < 30s | 15s mintavétel |
