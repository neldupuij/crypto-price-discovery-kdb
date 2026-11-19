"""
Multi-day lead-lag chart (8 days, last-trade prices, descriptive).

Reads  results/multiday_summary.csv and results/multiday_events_*.csv (made by analysis/multiday.q)
Writes results/figures/multiday.png

Run from the project folder:  python3 notebooks/plot_multiday.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "results"

COLORS = {"perp": "#2a78d6", "spot": "#eb6834"}
NAMES = {"perp": "Perpetual", "spot": "Spot"}
BAR = "#52514e"
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"


def style(ax):
    ax.set_facecolor(SURFACE)
    ax.grid(axis="y", color=GRID, linewidth=0.8, zorder=0)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=9)


summary = pd.read_csv(RES / "multiday_summary.csv", parse_dates=["date"])
evP = pd.read_csv(RES / "multiday_events_perp_jumps.csv")
evS = pd.read_csv(RES / "multiday_events_spot_jumps.csv")

fig, axes = plt.subplots(1, 3, figsize=(16, 4.8), facecolor=SURFACE,
                         gridspec_kw={"width_ratios": [1, 1.15, 1.15]})

# 1. Lead-lag ratio per day
ax = axes[0]
style(ax)
labels = summary["date"].dt.strftime("%b %d")
ax.bar(labels, summary["llr100"], width=0.6, color=BAR, zorder=3)
for x, v in zip(labels, summary["llr100"]):
    ax.annotate(f"{v:.1f}", (x, v), textcoords="offset points", xytext=(0, 3),
                ha="center", fontsize=9, color=INK)
ax.axhline(1, color=INK2, linewidth=1, linestyle="--", zorder=2)
ax.set_title("Lead-lag ratio per day (100 ms grid)", fontsize=11, color=INK, loc="left", pad=20)
ax.text(0.0, 1.015, "dashed line = 1 (no leader); > 1 on 8 / 8 days",
        transform=ax.transAxes, fontsize=9, color=INK2, va="bottom")
ax.set_ylim(0, summary["llr100"].max() * 1.15)
ax.tick_params(axis="x", rotation=45)

# 2 and 3. Pooled event studies
for ax, df, title, n in [
    (axes[1], evP, "PERPETUAL jumps: spot trade price moves after", summary["nPerpJumps"].sum()),
    (axes[2], evS, "SPOT jumps: perp trade price had partly moved before", summary["nSpotJumps"].sum()),
]:
    style(ax)
    for col in ("perp", "spot"):
        ax.plot(df["lagms"], df[col], drawstyle="steps-post", linewidth=2,
                color=COLORS[col], label=NAMES[col], zorder=3)
        ax.annotate(NAMES[col], (df["lagms"].iloc[-1], df[col].iloc[-1]),
                    textcoords="offset points", xytext=(4, 0), va="center",
                    fontsize=9, color=INK)
    ax.axvline(0, color=INK2, linewidth=0.8, linestyle=":", zorder=2)
    ax.axhline(0, color=INK2, linewidth=0.8, zorder=2)
    ax.set_title(title, fontsize=11, color=INK, loc="left", pad=20)
    ax.text(0.0, 1.015, f"{n} jumps > 3 bp in 10 ms, all 8 days pooled",
            transform=ax.transAxes, fontsize=9, color=INK2, va="bottom")
    ax.set_xlabel("time from the jump (ms)", fontsize=9, color=INK2)
    ax.set_xlim(-200, 1150)
    ax.set_ylim(-2.5, 5)

axes[1].set_ylabel("avg move in the jump direction (bp)", fontsize=9, color=INK2)
axes[1].legend(loc="lower right", frameon=False, fontsize=9)

fig.suptitle("Binance BTCUSDT trade prices, Nov 1–8 2026: perpetual moves precede spot moves on all 8 days (observed)",
             fontsize=13, color=INK, x=0.01, ha="left")
fig.tight_layout(rect=(0, 0, 1, 0.93))

out = RES / "figures" / "multiday.png"
fig.savefig(out, dpi=160, facecolor=SURFACE)
print(f"Saved {out}")
