"""
Charts of the funding study (BTCUSDT, Binance, October 2026).

Reads  results/funding/<TAG>/*.csv (made by analysis/funding_events.q)
Writes results/figures/funding_<TAG>_profiles.png, _by_hour.png, _estimate.png

Run from the project folder:  python3 notebooks/plot_funding.py BTCUSDT_2026-08_10
(without argument: the milestone-1 files in results/funding/, Oct 2026 BTC)
"""
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
TAG = sys.argv[1] if len(sys.argv) > 1 else ""
RES = ROOT / "results" / "funding" / TAG
FIG = ROOT / "results" / "figures"
PRE = f"funding_{TAG}_" if TAG else "funding_"
LABEL = TAG.replace("_", " ") if TAG else "BTCUSDT Oct 2026"
FIG.mkdir(parents=True, exist_ok=True)

EVENT = "#2a78d6"      # payment windows
PLACEBO = "#8c8b85"    # control windows (neutral)
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"


def style(ax, title, subtitle=None):
    ax.set_facecolor(SURFACE)
    ax.grid(axis="y", color=GRID, linewidth=0.8, zorder=0)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=9)
    ax.set_title(title, fontsize=11, color=INK, loc="left", pad=18 if subtitle else 6)
    if subtitle:
        ax.text(0, 1.015, subtitle, transform=ax.transAxes, fontsize=9, color=INK2, va="bottom")


# ------------------------------------------------------------
# 1. Profiles around the payment: events vs placebos
# ------------------------------------------------------------
pr = pd.read_csv(RES / "profiles.csv")
ev = pr[pr.grp == "event"].sort_values("k")
pl = pr[pr.grp == "placebo"].sort_values("k")
n_ev, n_pl = int(ev.n.iloc[0]), int(pl.n.iloc[0])

fig, axes = plt.subplots(2, 2, figsize=(13, 8), facecolor=SURFACE)
panels = [
    (axes[0, 0], "dBasisMean", "Basis change since -60 min (bp)", "mean; band = interquartile range of payment windows"),
    (axes[0, 1], "perpImb", "Perp aggressive-flow imbalance", "(buy - sell) / (buy + sell), notional, pooled per minute"),
    (axes[1, 0], "spotImb", "Spot aggressive-flow imbalance", "(buy - sell) / (buy + sell), notional, pooled per minute"),
    (axes[1, 1], "cumPerp", "Perp cumulative return since -60 min (bp)", "mean over windows"),
]
for ax, col, title, sub in panels:
    style(ax, title, sub)
    if col == "dBasisMean":
        ax.fill_between(ev.k, ev.dBasisQ25, ev.dBasisQ75, step="post", color=EVENT, alpha=0.12, lw=0)
    ax.plot(pl.k, pl[col], drawstyle="steps-post", color=PLACEBO, lw=1.6,
            label=f"other full hours (placebo, n={n_pl})", zorder=3)
    ax.plot(ev.k, ev[col], drawstyle="steps-post", color=EVENT, lw=2,
            label=f"funding payments (n={n_ev})", zorder=4)
    ax.axvline(0, color=INK2, lw=0.8, ls=":")
    ax.axhline(0, color=INK2, lw=0.6)
    ax.set_xlim(-60, 60)
    ax.set_xlabel("minutes from the payment (00/08/16 UTC) or from the placebo hour", fontsize=9, color=INK2)
axes[0, 0].legend(loc="lower left", frameon=False, fontsize=9)
fig.suptitle(f"Funding payments vs other full hours, Binance {LABEL} — descriptive",
             fontsize=13, color=INK, x=0.01, ha="left")
fig.text(0.01, 0.005, "Prices are last trades (not mid quotes, not executable). Flows = aggressor side from public "
         "trades: compatible with, not proof of, position unwinding.", fontsize=8.5, color=INK2)
fig.tight_layout(rect=(0, 0.02, 1, 0.95))
fig.savefig(FIG / f"{PRE}profiles.png", dpi=150, facecolor=SURFACE)
plt.close(fig)

# ------------------------------------------------------------
# 2. Hour-of-day control: basis change after the full hour, every hour
# ------------------------------------------------------------
bh = pd.read_csv(RES / "by_hour_all.csv").sort_values("hour")
fig, axes = plt.subplots(1, 2, figsize=(13, 4.6), facecolor=SURFACE, sharey=True)
for ax, col, se, title in [
    (axes[0], "dBasisPost", "seBasisPost", "Basis change from the hour to +60 min (bp)"),
    (axes[1], "dBasis10", "seBasis10", "Basis change from -5 to +5 min (bp)"),
]:
    style(ax, title, "mean ± 1.96 × day-bootstrap s.e.; blue = funding payment hours")
    colors = [EVENT if p == 1 else PLACEBO for p in bh.isPayment]
    ax.bar(bh.hour, bh[col], color=colors, width=0.65, zorder=3)
    ax.errorbar(bh.hour, bh[col], yerr=1.96 * bh[se], fmt="none", ecolor=INK2, elinewidth=0.9, capsize=2, zorder=4)
    ax.axhline(0, color=INK2, lw=0.8)
    ax.set_xticks(range(0, 24, 2))
    ax.set_xlabel("hour of the day (UTC)", fontsize=9, color=INK2)
fig.suptitle(f"Is the payment hour special? Same measure at every full hour ({LABEL})",
             fontsize=12, color=INK, x=0.01, ha="left")
fig.tight_layout(rect=(0, 0, 1, 0.93))
fig.savefig(FIG / f"{PRE}by_hour.png", dpi=150, facecolor=SURFACE)
plt.close(fig)

# ------------------------------------------------------------
# 3. Realized funding vs the estimate knowable 60 min before
# ------------------------------------------------------------
w = pd.read_csv(RES / "windows.csv")
w = w[w.kind == "event"]
fig, ax = plt.subplots(figsize=(6.2, 5.4), facecolor=SURFACE)
style(ax, "Funding: realized vs estimate 60 min before (bp)",
      "estimate rebuilt from 1-min premium index klines")
ax.scatter(1e4 * w.est, 1e4 * w.rate, s=22, color=EVENT, zorder=3)
lo, hi = -0.6, 1.1
ax.plot([lo, hi], [lo, hi], color=INK2, lw=0.8, ls="--")
ax.set_xlim(lo, hi); ax.set_ylim(lo, hi)
ax.set_xlabel("estimate at T - 60 min (bp)", fontsize=9, color=INK2)
ax.set_ylabel("realized rate paid at T (bp)", fontsize=9, color=INK2)
fig.tight_layout()
fig.savefig(FIG / f"{PRE}estimate.png", dpi=150, facecolor=SURFACE)
plt.close(fig)

print(f"Saved {PRE}profiles.png, {PRE}by_hour.png, {PRE}estimate.png in results/figures/")
