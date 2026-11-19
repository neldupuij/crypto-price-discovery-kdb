"""
Chart of the lead-lag cross-correlation (Binance BTCUSDT perp vs spot).

Reads  results/leadlag_100ms.csv and results/leadlag_10ms.csv (made by analysis/leadlag.q)
Writes results/figures/leadlag.png

Run from the project folder:  python3 notebooks/plot_leadlag.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "results"

# Colors (one series per panel -> one hue)
BLUE = "#2a78d6"
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK2 = "#52514e"
GRID = "#e4e3df"

panels = [
    ("leadlag_100ms.csv", "100 ms grid, lags ±2 s"),
    ("leadlag_10ms.csv", "10 ms grid, lags ±500 ms"),
]

fig, axes = plt.subplots(1, 2, figsize=(12, 4.6), facecolor=SURFACE)

for ax, (fname, subtitle) in zip(axes, panels):
    df = pd.read_csv(RES / fname)
    step = df["lagms"].diff().dropna().iloc[0]

    ax.set_facecolor(SURFACE)
    ax.bar(df["lagms"], df["corr"], width=step * 0.7, color=BLUE, zorder=3)
    ax.axhline(0, color=INK2, linewidth=0.8, zorder=2)
    ax.axvline(0, color=INK2, linewidth=0.8, linestyle=":", zorder=2)

    # Label the three bars that tell the story: -1 step, 0, +1 step
    offsets = {-step: (-6, 2, "right"), 0: (0, 4, "center"), step: (6, 2, "left")}
    for lag, (dx, dy, ha) in offsets.items():
        row = df[df["lagms"] == lag]
        if not row.empty:
            v = row["corr"].iloc[0]
            ax.annotate(f"{v:.2f}", (lag, v), textcoords="offset points",
                        xytext=(dx, dy), ha=ha, fontsize=9, color=INK)
    ax.set_ylim(top=df["corr"].max() * 1.12)

    # Lead-lag ratio: squared correlations on the right / on the left
    right = (df.loc[df["lag"] > 0, "corr"] ** 2).sum()
    left = (df.loc[df["lag"] < 0, "corr"] ** 2).sum()
    ax.text(0.98, 0.95, f"lead-lag ratio = {right / left:.1f}",
            transform=ax.transAxes, ha="right", va="top", fontsize=10, color=INK)

    ax.set_title(subtitle, fontsize=11, color=INK, loc="left")
    ax.set_xlabel("lag k (ms):  corr( perp return at t , spot return at t + k )",
                  fontsize=9, color=INK2)
    ax.set_ylabel("correlation", fontsize=9, color=INK2)
    ax.grid(axis="y", color=GRID, linewidth=0.8, zorder=0)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=9)

fig.suptitle("Binance BTCUSDT, 2026-11-08: the perpetual leads the spot "
             "(bars on the right are taller than on the left)",
             fontsize=12, color=INK, x=0.01, ha="left")
fig.tight_layout(rect=(0, 0, 1, 0.94))

out = RES / "figures" / "leadlag.png"
out.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(out, dpi=160, facecolor=SURFACE)
print(f"Saved {out}")
