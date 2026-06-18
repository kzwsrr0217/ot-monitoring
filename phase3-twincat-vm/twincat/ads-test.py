#!/usr/bin/env python3
"""
ADS Connection Tester — Phase 3
Futtatás: python3 ads-test.py
Telepítés: pip install pyads --user

Futtasd ezt a Collector VM-en MIELOTT a telegraf-ads.conf-ra valtasz.
Ha ez zold, a Telegraf ADS input is mukodni fog.
"""
import pyads
import time
import sys
import os

TWINCAT_IP = os.environ.get("TWINCAT_VM_IP",      "192.168.1.50")
AMS_NET_ID = os.environ.get("TWINCAT_AMS_NET_ID", "192.168.1.50.1.1")
AMS_PORT   = int(os.environ.get("TWINCAT_AMS_PORT", "851"))

VARIABLES = {
    "GVL_Monitoring.xMachineON":          pyads.PLCTYPE_BOOL,
    "GVL_Monitoring.xProductionRun":      pyads.PLCTYPE_BOOL,
    "GVL_Monitoring.xMachineErrorState":  pyads.PLCTYPE_BOOL,
    "GVL_Monitoring.nOK_Counter":         pyads.PLCTYPE_DINT,
    "GVL_Monitoring.nNOK_Counter":        pyads.PLCTYPE_DINT,
    "GVL_Monitoring.nCycleCount":         pyads.PLCTYPE_UDINT,
    "GVL_Monitoring.nProdType":           pyads.PLCTYPE_INT,
    "GVL_Monitoring.nLastCycleTimeMs":    pyads.PLCTYPE_UDINT,
    "GVL_Monitoring.nLastStoppageTimeMs": pyads.PLCTYPE_UDINT,
}


def test():
    print(f"\n{'='*55}")
    print(f"  ADS Kapcsolat Teszt --- Phase 3")
    print(f"{'='*55}")
    print(f"  Target:  {TWINCAT_IP}")
    print(f"  AMS ID:  {AMS_NET_ID}:{AMS_PORT}")
    print(f"{'='*55}\n")

    try:
        plc = pyads.Connection(AMS_NET_ID, AMS_PORT, TWINCAT_IP)
        plc.open()
        print("[OK] ADS kapcsolat OK\n")

        print("Valtozok olvasasa:")
        print("-" * 55)
        errors = 0
        for name, plc_type in VARIABLES.items():
            try:
                val = plc.read_by_name(name, plc_type)
                print(f"  [OK]  {name:<45} = {val}")
            except Exception as e:
                print(f"  [!!]  {name:<45} --> {e}")
                errors += 1

        print(f"\nFolyamatos olvasas (5 mp):")
        print("-" * 55)
        for i in range(5):
            ok  = plc.read_by_name("GVL_Monitoring.nOK_Counter",      pyads.PLCTYPE_DINT)
            run = plc.read_by_name("GVL_Monitoring.xProductionRun",   pyads.PLCTYPE_BOOL)
            cyc = plc.read_by_name("GVL_Monitoring.nLastCycleTimeMs", pyads.PLCTYPE_UDINT)
            print(f"  [{i+1}] ok={ok:6d}  run={str(run):<5}  cycle_ms={cyc}")
            time.sleep(1)

        plc.close()

        print(f"\n{'='*55}")
        if errors == 0:
            print("  [OK] SIKERES --- Telegraf konfig atvalthato ADS-re")
            print(f"{'='*55}\n")
            return True
        else:
            print(f"  [!!] {errors} valtozo olvasasa sikertelen --- ellenorizd a GVL-t")
            print(f"{'='*55}\n")
            return False

    except Exception as e:
        print(f"[!!] ADS kapcsolat SIKERTELEN: {e}\n")
        print("Ellenorizd:")
        print(f"  1. ping {TWINCAT_IP}  --- elerh eto-e a Collector VM-rol")
        print("  2. TwinCAT talcaikon zold-e (RUN mod)")
        print("  3. Windows Firewall: TCP 48898 nyitva")
        print("  4. TwinCAT Router: Collector VM IP engedelyezve")
        print(f"  5. .env: TWINCAT_AMS_NET_ID helyes-e")
        return False


if __name__ == "__main__":
    sys.exit(0 if test() else 1)
