# Kickoff Meeting — Gyárfelügyeleti Rendszer

**Cél:** A termelés és menedzsment megérti a rendszert, és meg tudja fogalmazni az igényeit.

---

## Amit megmutatsz (15 perc)

1. **Grafana megnyitása** — http://192.168.100.20:3000
2. Bejelentkezés `operator` fiókkal → csak a termelési nézet látszik
3. Bejelentkezés `menedzser` fiókkal → megjelenik az OEE és KPI is
4. Élő adatok: OEE mutató, leállás számláló, ciklusidő trend
5. Főüzenet kimondása: **"Ezt mind 9 változóból csináljuk, ami a PLC-ben már megvan."**

---

## Amit el kell mondani (5 perc)

- A PLC eddig is mérte ezeket az adatokat — csak senki nem hallgatta
- A rendszer nem változtatja meg a PLC programot, csak "belehallgat"
- Az adatok valós időben látszanak, böngészőből, bármilyen eszközről
- A historikus adatok SQL-ben tárolódnak — bármilyen riport lekérdezhető belőle
- Ha új gépet kötünk be, a monitoring infrastruktúra nem változik

---

## Kérdések a résztvevőknek

### Termelésnek
- Melyik gépen van most a legnagyobb probléma, amit "érzésből" tudtok, de adattal nem tudtok alátámasztani?
- Mikor van egy leállás? Kit kell értesíteni és mennyi idő alatt?
- Van-e olyan esemény, amit jelenleg papíron vagy Excelben rögzítetek?
- Mi a célelőírás: ciklusidő, selejt arány, OEE?

### Menedzsmentnek
- Milyen rendszerességgel kell riport: műszakonként, naponta, hetente?
- Ki kell tudnia megnézni az adatokat — csak belső hálózatról, vagy mobilról is?
- Van-e már meglévő rendszer (MES, SCADA, ERP), amivel kommunikálnia kellene?
- Mi az a egy szám, amit minden reggel tudni akarsz a gyár állapotáról?

---

## Amit dönteni kell a meeting végéig

| Kérdés | Opciók |
|---|---|
| Melyik gép/gépek kerülnek be először? | Egy pilotgép, vagy rögtön az egész sor |
| Mi a legfontosabb KPI? | OEE / Leállás idő / Selejt arány |
| Ki kapjon hozzáférést? | Csak műszakvezető / összes operátor / menedzsment is |
| Kell-e riasztás? | Email / SMS / csak dashboard |
| Van-e IT biztonsági követelmény? | Hálózat izoláció, HTTPS, SSO |

---

## Ami NEM téma ezen a meetingen

- Hogyan működik technológiailag (ez már eldöntött)
- Pontos ütemterv (ez a következő lépés)
- Költségek (PoC fázisban vagyunk)

---

## Következő lépések (javaslat)

1. Kiválasztjuk a pilotgépet
2. PLC engineer bekonfigurálja a 9 változót a TwinCAT projektbe
3. Tesztelünk 2 hétig élő adatokkal
4. Visszajelzés alapján finomítjuk a dashboardokat és a riasztásokat
