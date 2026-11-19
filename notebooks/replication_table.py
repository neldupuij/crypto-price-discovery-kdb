"""
Collects the frozen results of each symbol/month into the replication table
defined by docs/funding_replication_protocol_v2_2026-11-11.md. No new statistics
are computed here: only results/funding/<SYM>_<MONTH>/*.csv are read and laid out.

Run from the project folder:  python3 notebooks/replication_table.py
Writes results/funding/replication_summary.csv and results/funding/replication_categories.csv
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "results" / "funding"
SAMPLES = [  # (tag, role)
    ("BTCUSDT_2026-10", "exploratory"),
    ("BTCUSDT_2026-08", "validation"),
    ("BTCUSDT_2026-09", "validation"),
    ("ETHUSDT_2026-08", "validation"),
    ("ETHUSDT_2026-09", "validation"),
    ("ETHUSDT_2026-10", "validation"),
]
# protocol v2, section 3: variable -> expected sign
CHECKS = [("dBasisPost", "primary", +1), ("dBasis10", "S1", +1),
          ("aPerpImbAsym", "S2", -1), ("aPerpImbAsym", "H", +1)]


def verdict(lo, hi, sign):
    if sign > 0:
        return "replicates" if lo > 0 else ("contradicts" if hi < 0 else "inconclusive")
    return "replicates" if hi < 0 else ("contradicts" if lo > 0 else "inconclusive")


rows, cats = [], []
for tag, role in SAMPLES:
    d = RES / tag
    evp = pd.read_csv(d / "event_vs_placebo.csv").set_index("metric")
    desc = pd.read_csv(d / "descriptive.csv")
    win = pd.read_csv(d / "windows.csv")
    grp = pd.read_csv(d / "by_funding_group.csv")
    ev = win[win.kind == "event"]
    for metric, label, sign in CHECKS:
        e = desc[(desc.metric == metric) & (desc.kind == "event")].iloc[0]
        p = desc[(desc.metric == metric) & (desc.kind == "placebo")].iloc[0]
        r = evp.loc[metric]
        rows.append(dict(
            sample=tag, role=role, check=label, metric=metric, expected="> 0" if sign > 0 else "< 0",
            nEvents=int(e.n), nPlacebos=int(p.n),
            eventMean=e["mean"], eventMedian=e["median"], eventSd=e.sd,
            placeboMean=p["mean"], placeboMedian=p["median"],
            diff=r["diff"], lo95=r.lo95, hi95=r.hi95, p=r.pTwoSided,
            verdict=verdict(r.lo95, r.hi95, sign),
            diffOverEventSd=r["diff"] / e.sd,
            usdPer1M=r["diff"] * 100 if metric.startswith("dBasis") else None,
            fundingMedianBp=1e4 * ev.rate.median(), fundingMinBp=1e4 * ev.rate.min(),
            fundingMaxBp=1e4 * ev.rate.max(),
        ))
    # category counts with the BTC-October thresholds (protocol v2, section 4)
    n = grp[grp.metric == "dBasisPost"].set_index("group")
    cats.append(dict(sample=tag, **{g: int(n.loc[g, "nEvents"]) for g in n.index},
                     **{f"dBasisPost_{g}": n.loc[g, "diff"] for g in n.index},
                     **{f"lo_{g}": n.loc[g, "lo95"] for g in n.index},
                     **{f"hi_{g}": n.loc[g, "hi95"] for g in n.index}))

tab = pd.DataFrame(rows)
cat = pd.DataFrame(cats)
tab.to_csv(RES / "replication_summary.csv", index=False)
cat.to_csv(RES / "replication_categories.csv", index=False)

pd.set_option("display.width", 250, "display.max_columns", 30)
for label in ("primary", "S1", "S2", "H"):
    t = tab[tab.check == label]
    print(f"\n=== {label}: {t.metric.iloc[0]} (expected {t.expected.iloc[0]}) ===")
    print(t[["sample", "role", "nEvents", "nPlacebos", "eventMean", "eventMedian", "placeboMean",
             "placeboMedian", "eventSd", "diff", "lo95", "hi95", "p", "verdict", "diffOverEventSd"]]
          .round(3).to_string(index=False))
    v = t[t.role == "validation"]
    print(f"validation: {sum(v.verdict == 'replicates')} replicate, {sum(v.verdict == 'contradicts')} contradict, "
          f"{sum(v.verdict == 'inconclusive')} inconclusive; same sign as expected: "
          f"{sum((v['diff'] > 0) == (v.expected == '> 0'))}/5")
print("\n=== funding categories (BTC-October thresholds) ===")
print(cat[["sample", "realizedNeg", "realizedPos", "estLow", "estMid", "estHigh"]].to_string(index=False))
print(cat[["sample"] + [c for c in cat.columns if c.startswith("dBasisPost_")]].round(2).to_string(index=False))
