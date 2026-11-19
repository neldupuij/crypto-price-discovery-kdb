"""
Charts of the USDC -> BTC routing test (one day, Binance spot, Tardis books).

Reads  results/routing/<date>/summary.csv, economie_F0_U10.csv
Writes results/figures/routing_<date>_fees.png, _timeline.png, _coverage.png

Run from the project folder:  python3 notebooks/plot_routing.py 2026-11-01
"""
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

DAY = sys.argv[1] if len(sys.argv) > 1 else "2026-11-01"
ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "results" / "routing" / DAY
FIG = ROOT / "results" / "figures"
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
SIZE_COLORS = {0.01: "#2a78d6", 0.1: "#eb6834", 1.0: "#1baf7a", 5.0: "#6250d6"}  # fixed order


def style(ax, title, sub=None):
    ax.set_facecolor(SURFACE)
    ax.grid(axis="y", color=GRID, lw=0.8, zorder=0)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=9)
    ax.set_title(title, fontsize=11, color=INK, loc="left", pad=18 if sub else 6)
    if sub:
        ax.text(0, 1.015, sub, transform=ax.transAxes, fontsize=9, color=INK2, va="bottom")


s = pd.read_csv(RES / "summary.csv")
uni = {"F0": 0, "U1": 1, "U2_5": 2.5, "U5": 5, "U7_5": 7.5, "U10": 10}
u = s[s.scenario.isin(uni)].copy()
u["fee"] = u.scenario.map(uni)

# 1. Saving vs fee level, per size
fig, axes = plt.subplots(1, 2, figsize=(13, 4.8), facecolor=SURFACE)
ax = axes[0]
style(ax, "Median saving of the indirect route (bp)", "economie_bps; band = 5th–95th percentile of the seconds")
for size, c in SIZE_COLORS.items():
    d = u[u["size"] == size].sort_values("fee")
    ax.fill_between(d.fee, d.bpsP05, d.bpsP95, color=c, alpha=0.10, lw=0)
    ax.plot(d.fee, d.bpsMed, marker="o", ms=5, lw=2, color=c, label=f"{size:g} BTC")
ax.axhline(0, color=INK2, lw=0.9)
ax.set_xlabel("fee per leg, same on all legs (bp)", fontsize=9, color=INK2)
ax.legend(frameon=False, fontsize=9, loc="lower left")
ax = axes[1]
style(ax, "Share of seconds where the indirect route is cheaper", "only seconds where both routes are evaluable")
for size, c in SIZE_COLORS.items():
    d = u[u["size"] == size].sort_values("fee")
    ax.plot(d.fee, 100 * d.shareIndirectCheaper, marker="o", ms=5, lw=2, color=c, label=f"{size:g} BTC")
ax.set_ylim(0, 100)
ax.set_ylabel("% of seconds", fontsize=9, color=INK2)
ax.set_xlabel("fee per leg, same on all legs (bp)", fontsize=9, color=INK2)
fig.suptitle(f"USDC → BTC on Binance spot, {DAY}: indirect (via USDT) minus direct, on observed books",
             fontsize=12, color=INK, x=0.01, ha="left")
fig.text(0.01, 0.01, "Fees are scenarios (historical rates not verifiable). Taker market orders, 25 visible levels, "
         "the two indirect legs are not atomic: costs are estimates, not guaranteed.", fontsize=8.5, color=INK2)
fig.tight_layout(rect=(0, 0.03, 1, 0.94))
fig.savefig(FIG / f"routing_{DAY}_fees.png", dpi=150, facecolor=SURFACE)
plt.close(fig)

# 2. Through the day, no-fee bound and 10 bp scenario, 1 and 5 BTC (5-minute medians)
e = pd.read_csv(RES / "economie_F0_U10.csv")
e["t"] = pd.to_datetime(e.t.str.replace("D", "T", regex=False))   # q timestamp -> ISO
e = e[e.status == "both"]
fig, ax = plt.subplots(figsize=(13, 4.6), facecolor=SURFACE)
style(ax, "Saving through the day (5-minute median of the seconds where both routes are evaluable)",
      "solid = no fees (optimistic bound); dashed = 10 bp per leg")
for size in (1.0, 5.0):
    for sc, ls in (("F0", "-"), ("U10", "--")):
        d = e[(e["size"] == size) & (e.scenario == sc)].set_index("t").economie_bps.resample("5min").median()
        ax.plot(d.index, d.values, ls=ls, lw=1.6, color=SIZE_COLORS[size],
                label=f"{size:g} BTC, {'no fees' if sc == 'F0' else '10 bp/leg'}")
ax.axhline(0, color=INK2, lw=0.9)
ax.set_ylabel("economie_bps", fontsize=9, color=INK2)
ax.legend(frameon=False, fontsize=9, ncol=4, loc="lower left")
fig.tight_layout()
fig.savefig(FIG / f"routing_{DAY}_timeline.png", dpi=150, facecolor=SURFACE)
plt.close(fig)

# 3. Coverage: which comparisons are possible (no-fee bound)
f0 = s[s.scenario == "F0"].sort_values("size")
cats = [("both", "both routes", "#1baf7a"), ("directOnly", "direct only", "#2a78d6"),
        ("indirectOnly", "indirect only", "#eb6834"), ("neither", "neither (depth)", "#8c8b85")]
fig, ax = plt.subplots(figsize=(8, 4.4), facecolor=SURFACE)
style(ax, "Which seconds can be evaluated with 25 visible levels", "no-fee scenario; no second was dropped for old books")
left = [0] * len(f0)
for col, lab, c in cats:
    v = (100 * f0[col] / f0.instants).tolist()
    ax.barh([f"{x:g} BTC" for x in f0["size"]], v, left=left, color=c, label=lab, height=0.6, zorder=3)
    left = [a + b for a, b in zip(left, v)]
ax.set_xlim(0, 100)
ax.set_xlabel("% of the 86 399 seconds", fontsize=9, color=INK2)
ax.legend(frameon=False, fontsize=9, ncol=2, loc="lower right", bbox_to_anchor=(1, -0.35))
fig.tight_layout()
fig.savefig(FIG / f"routing_{DAY}_coverage.png", dpi=150, facecolor=SURFACE)
plt.close(fig)
print(f"Saved routing_{DAY}_fees.png, _timeline.png, _coverage.png")
