import pandas as pd
import numpy as np
import random
import string
from datetime import datetime, timedelta
import os

random.seed(42)
np.random.seed(42)

OUTPUT_DIR = "/home/claude/synthetic_final"
os.makedirs(OUTPUT_DIR, exist_ok=True)

AIRPORTS_DOM = ["KEE","FUG","KSN","YML","QFX","JKS","DRW","JYN","UMK","TDX","NAB","PVS","KLC","UBR"]
AIRPORTS_INT = ["ZYR","LNR","GNP","VQR","MBT","RZP","TPX","HGV","KHV","SUQ","KUV","MFP","DPQ","SZV"]
ALL_AIRPORTS  = AIRPORTS_DOM + AIRPORTS_INT
CLASSES       = [f"Class {i}" for i in range(1, 10)]
CURRENCIES    = ["CCY-1","CCY-2","CCY-3","CCY-4"]
TRANSCODES    = ["TYPE-A","TYPE-B","TYPE-C","TYPE-D"]
PAYMENTS      = ["Payment A","Payment B","Payment C"]
FARE_BASES    = ["Basis-001","Basis-001/BG","Basis-002","Basis-002/BG","Basis-003"]
SVC_TYPES     = [f"Service Type {i}" for i in range(1,6)]
REV_CATS      = [f"Category {c}" for c in "ABCD"]
AGENTS        = [f"Agent {a}" for a in ["A1","A2","B1","B2","C1","C2"]]
EQUIP         = ["Equip-1","Equip-2","Equip-3"]

def rdate(s,e):
    s,e=datetime.strptime(s,"%Y-%m-%d"),datetime.strptime(e,"%Y-%m-%d")
    return (s+timedelta(days=random.randint(0,(e-s).days))).strftime("%Y-%m-%d")

def rdoc():
    return "".join([str(random.randint(0,9)) for _ in range(13)])

def rfn():
    return "FN-"+str(random.choice([101,105,117,119,118,132,133,394,395,508]))

def rroute(area=None):
    if area=="DOM":   o,d=random.sample(AIRPORTS_DOM,2)
    elif area=="INT": o,d=random.choice(AIRPORTS_DOM),random.choice(AIRPORTS_INT)
    else:             o,d=random.sample(ALL_AIRPORTS,2)
    return o,d

def fv(m=100,s=60): return round(abs(np.random.normal(m,s)),2)

# ── PRIMARY REVENUE (ticket) ──────────────────────────────────────────────────
rows=[]
for _ in range(2000):
    area=random.choice(["DOM","INT"])
    orig,dest=rroute(area)
    cls=random.choice(CLASSES)
    ccy=random.choice(CURRENCIES)
    f=fv(150,80); sur=fv(30,15); tax=fv(10,5)
    comm=round(f*random.uniform(0,.05),2)
    tot=round(f+sur+tax-comm,2)
    fx=random.uniform(0.8,1.2)
    rows.append({
        "carrier_code":       "XA",
        "service_date":       rdate("2025-12-01","2025-12-31"),
        "area_type":          area,
        "flight_no":          rfn(),
        "flight_detail":      "XA"+rfn(),
        "route_detail":       orig+dest,
        "route_code":         f"{orig}-{dest}",
        "doc_number":         rdoc(),
        "special_type":       random.choice(["","Category C","Category D",""]),
        "route_ref":          f"{orig}-{dest}",
        "booking_class":      cls,
        "trans_code":         random.choice(TRANSCODES),
        "tour_code":          "",
        "agent_code":         random.choice(AGENTS),
        "payment_method":     random.choice(PAYMENTS),
        "issue_date":         rdate("2025-11-01","2025-12-31"),
        "revenue_category":   random.choice(REV_CATS),
        "currency":           ccy,
        "fare_flag":          random.choice(["Y","N"]),
        "base_fare_local":    f,
        "surcharge":          round(sur/fx,2),
        "surcharge_local":    sur,
        "tax":                round(tax/fx,2),
        "tax_local":          tax,
        "commission":         round(comm/fx,2),
        "commission_local":   comm,
        "total_fare":         round(tot/fx,2),
        "total_fare_local":   tot,
        "remark":             "",
        "origin_station":     orig,
        "total_local_curr":   tot,
        "mileage":            random.randint(200,5000),
        "booking_ref":        "".join(random.choices(string.ascii_uppercase+string.digits,k=6)),
        "fare_basis_code":    random.choice(FARE_BASES),
        "base_fare_usd":      round(f/35,2),
        "surcharge_usd":      round(sur/35,2),
        "tax_usd":            round(tax/35,2),
        "commission_usd":     round(comm/35,2),
        "total_fare_usd":     round(tot/35,2),
    })
pd.DataFrame(rows).to_csv(f"{OUTPUT_DIR}/revenue_primary_202512.csv",index=False)
print("✅ revenue_primary_202512.csv — 2000 rows")

# ── ANCILLARY DOC-S ───────────────────────────────────────────────────────────
def emd_row(doc_type_ref, doc_type, remark=None):
    orig,dest=rroute()
    fu=round(abs(np.random.normal(12,5)),2)
    yu=round(abs(np.random.normal(3,1)),2)
    return {
        "currency":        random.choice(CURRENCIES),
        "issue_date":      rdate("2025-12-01","2025-12-31"),
        "doc_number":      rdoc(),
        "booking_class":   random.choice(CLASSES),
        "fare_flag":       random.choice(["Y","N"]),
        "fee_local":       round(yu*35,2),
        "service_type":    remark or random.choice(SVC_TYPES),
        "doc_type_ref":    doc_type_ref,
        "doc_type":        doc_type,
        "service_date":    rdate("2025-12-01","2025-12-31"),
        "origin":          orig,
        "destination":     dest,
        "flight_no":       rfn(),
        "trans_code":      random.choice(TRANSCODES),
        "doc_category":    "DOC",
        "base_fare_usd":   fu,
        "fee_usd":         yu,
        "equipment_type":  random.choice(EQUIP),
    }

pd.DataFrame([emd_row("Doc Type S","S") for _ in range(50)])\
  .to_csv(f"{OUTPUT_DIR}/ancillary_doc_s_202512.csv",index=False)
print("✅ ancillary_doc_s_202512.csv — 50 rows")

pd.DataFrame([emd_row("Doc Type A","A") for _ in range(1000)])\
  .to_csv(f"{OUTPUT_DIR}/ancillary_doc_a_202512.csv",index=False)
print("✅ ancillary_doc_a_202512.csv — 1000 rows")

pd.DataFrame([emd_row("Doc Type A","A","No-Show Fee") for _ in range(80)])\
  .to_csv(f"{OUTPUT_DIR}/ancillary_noshow_202512.csv",index=False)
print("✅ ancillary_noshow_202512.csv — 80 rows")

print(f"\n✅ All files saved to {OUTPUT_DIR}/")
