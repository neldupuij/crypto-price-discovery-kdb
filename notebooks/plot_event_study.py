"""
Chart of the event study: average path of perp and spot prices around big jumps.

Reads  results/event_perp_jumps.csv, results/event_spot_jumps.csv (made by analysis/event_study.q)
Writes results/figures/event_study.png

Run from the project folder:  python3 notebooks/plot_event_study.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "results"

# One color per market, the same in both panels
COLORS = {"perp": "#2a78d6", "spot": "#eb6834"}
NAMES = {"perp": "Perpetual", "spot": "Spot"}
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"

panels = [
    ("event_perp_jumps.csv", "When the PERPETUAL jumps (> 3 bp in 10 ms)",
     "the spot follows within 10–20 ms"),
    ("event_spot_jumps.csv", "When the SPOT jumps (> 3 bp in 10 ms)",
     "the perpetual had already moved before"),
]

fig, axes = plt.subplots(1, 2, figsize=(12, 4.8), facecolor=SURFACE, sharey=True)

for ax, (fname, title, note) in zip(axes, panels):
    df = pd.read_csv(RES / fname)
    ax.set_facecolor(SURFACE)
    for col in ("perp", "spot"):
        ax.plot(df["lagms"], df[col], drawstyle="steps-post", linewidth=2,
                color=COLORS[col], label=NAMES[col], zorder=3)
        # direct label at the right end of each line
        ax.annotate(NAMES[col], (df["lagms"].iloc[-1], df[col].iloc[-1]),
                    textcoords="offset points", xytext=(4, 0), va="center",
                    fontsize=9, color=INK)
    ax.axvline(0, color=INK2, linewidth=0.8, linestyle=":", zorder=2)
    ax.axhline(0, color=INK2, linewidth=0.8, zorder=2)
    ax.text(5, -2.6, "jump", fontsize=9, color=INK2)

    ax.set_title(title, fontsize=11, color=INK, loc="left")
    ax.text(0.97, 0.97, note, transform=ax.transAxes, ha="right", va="top",
            fontsize=10, color=INK2)
    ax.set_xlabel("time from the jump (ms)", fontsize=9, color=INK2)
    ax.set_xlim(-200, 1090)
    ax.grid(axis="y", color=GRID, linewidth=0.8, zorder=0)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=9)

axes[0].set_ylabel("average price move in the jump direction (bp)", fontsize=9, color=INK2)
axes[0].legend(loc="lower right", frameon=False, fontsize=9)
axes[0].set_ylim(-2.8, 5)

fig.suptitle("Binance BTCUSDT, 2026-11-08: event study around big 10 ms jumps "
             "(price relative to 10 ms before the jump)",
             fontsize=12, color=INK, x=0.01, ha="left")
fig.tight_layout(rect=(0, 0, 1, 0.94))

out = RES / "figures" / "event_study.png"
out.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(out, dpi=160, facecolor=SURFACE)
print(f"Saved {out}")
