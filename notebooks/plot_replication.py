"""
Forest plot of the replication (protocol v2): payment - placebo with 95% day-bootstrap
intervals, for the exploratory sample and the five validation samples.

Reads  results/funding/replication_summary.csv (notebooks/replication_table.py)
Writes results/figures/funding_replication.png

Run from the project folder:  python3 notebooks/plot_replication.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
t = pd.read_csv(ROOT / "results" / "funding" / "replication_summary.csv")

COLORS = {"BTCUSDT": "#2a78d6", "ETHUSDT": "#eb6834"}
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
PANELS = [
    ("primary", "PRIMARY — basis change, payment → +60 min (bp)\nexpected > 0"),
    ("S1", "S1 — basis change, −5 → +5 min (bp)\nexpected > 0"),
    ("S2", "S2 / H — perp flow asymmetry aligned on funding sign\nS2 expects < 0, unwinding hypothesis H expects > 0"),
]

fig, axes = plt.subplots(1, 3, figsize=(15, 5.2), facecolor=SURFACE, sharey=True)
for ax, (check, title) in zip(axes, PANELS):
    d = t[t.check == check].reset_index(drop=True)
    ax.set_facecolor(SURFACE)
    for i, r in d.iterrows():
        y = len(d) - 1 - i
        sym = r["sample"].split("_")[0]
        explo = r.role == "exploratory"
        ax.errorbar(r["diff"], y, xerr=[[r["diff"] - r.lo95], [r.hi95 - r["diff"]]], fmt="o",
                    color=COLORS[sym], mfc=SURFACE if explo else COLORS[sym], ms=8, mew=2,
                    elinewidth=2, capsize=3, zorder=3)
    ax.axvline(0, color=INK2, lw=0.9)
    ax.axhline(len(d) - 1.5, color=GRID, lw=1)
    ax.set_title(title, fontsize=10, color=INK, loc="left")
    ax.grid(axis="x", color=GRID, lw=0.8, zorder=0)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=9)
    ax.set_xlabel("payment − placebo (95% day-bootstrap interval)", fontsize=9, color=INK2)
labels = [s.replace("_", "  ") + ("  (exploratory)" if r == "exploratory" else "")
          for s, r in zip(t[t.check == "primary"]["sample"], t[t.check == "primary"].role)]
axes[0].set_yticks(range(len(labels)))
axes[0].set_yticklabels(labels[::-1], fontsize=9.5, color=INK)
fig.suptitle("Replication on 5 new samples (frozen protocol v2): the October effect is not confirmed",
             fontsize=12.5, color=INK, x=0.01, ha="left")
fig.text(0.01, 0.01, "Hollow marker = exploratory sample (BTC Oct). Filled = validation. "
         "A sample replicates only if its whole interval is on the expected side of 0. Last-trade prices, descriptive.",
         fontsize=8.5, color=INK2)
fig.tight_layout(rect=(0, 0.03, 1, 0.93))
out = ROOT / "results" / "figures" / "funding_replication.png"
fig.savefig(out, dpi=150, facecolor=SURFACE)
print(f"Saved {out}")
