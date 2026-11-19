"""
Robustness chart: payment - placebo, per month and per symbol, with 95% day-bootstrap intervals.

Reads  results/funding/<TAG>/by_month.csv and event_vs_placebo.csv for each TAG given
Writes results/figures/funding_compare.png

Run from the project folder:
  python3 notebooks/plot_funding_compare.py BTCUSDT_2026-08_10 ETHUSDT_2026-08_10
"""
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "results" / "funding"
FIG = ROOT / "results" / "figures"
TAGS = sys.argv[1:] or ["BTCUSDT_2026-08_10", "ETHUSDT_2026-08_10"]

COLORS = ["#2a78d6", "#eb6834"]                    # fixed order: 1st symbol blue, 2nd orange
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"

METRICS = [
    ("dBasisPost", "Basis change, payment → +60 min (bp)"),
    ("dBasis10", "Basis change, −5 → +5 min (bp)"),
    ("perpImbAsym", "Perp flow imbalance, after − before (30 min)"),
    ("aPerpImbAsym", "Same, aligned on the sign of the funding estimate\n(hypothesis: > 0)"),
]

rows = []
for tag in TAGS:
    sym = tag.split("_")[0]
    bm = pd.read_csv(RES / tag / "by_month.csv")
    bm["label"] = bm["month"].astype(str).str.replace(".", "-", regex=False).str[:7]
    bm["sym"] = sym
    allm = pd.read_csv(RES / tag / "event_vs_placebo.csv")
    allm["label"] = "all"
    allm["sym"] = sym
    rows.append(pd.concat([bm, allm], ignore_index=True))
df = pd.concat(rows, ignore_index=True)
labels = [l for l in sorted(df.label.unique()) if l != "all"] + ["all"]
syms = list(dict.fromkeys(df.sym))

fig, axes = plt.subplots(2, 2, figsize=(13, 8), facecolor=SURFACE)
for ax, (metric, title) in zip(axes.flat, METRICS):
    ax.set_facecolor(SURFACE)
    d = df[df.metric == metric]
    width = 0.35
    for j, sym in enumerate(syms):
        ds = d[d.sym == sym].set_index("label").reindex(labels)
        x = [i + (j - 0.5) * width for i in range(len(labels))]
        ax.bar(x, ds["diff"], width=width * 0.85, color=COLORS[j], label=sym, zorder=3)
        ax.errorbar(x, ds["diff"], yerr=[ds["diff"] - ds["lo95"], ds["hi95"] - ds["diff"]],
                    fmt="none", ecolor=INK2, elinewidth=0.9, capsize=2, zorder=4)
    ax.axhline(0, color=INK2, lw=0.8)
    ax.axvline(len(labels) - 1.5, color=GRID, lw=1)
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, fontsize=9, color=INK2)
    ax.set_title(title, fontsize=10.5, color=INK, loc="left")
    ax.grid(axis="y", color=GRID, lw=0.8, zorder=0)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=9)
axes[0, 0].legend(frameon=False, fontsize=9, loc="upper left")
fig.suptitle("Funding payment minus placebo hours, by month and symbol (95% day-bootstrap intervals)",
             fontsize=12.5, color=INK, x=0.01, ha="left")
fig.text(0.01, 0.005, "Descriptive. Last-trade prices (not mid quotes). Flows compatible with, not proof of, "
         "position unwinding. 'all' = the three months pooled.", fontsize=8.5, color=INK2)
fig.tight_layout(rect=(0, 0.02, 1, 0.95))
fig.savefig(FIG / "funding_compare.png", dpi=150, facecolor=SURFACE)
print("Saved results/figures/funding_compare.png")
