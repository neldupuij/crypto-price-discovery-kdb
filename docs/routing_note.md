# USDC → BTC routing: first economic verdict (1 day, Binance spot)

11 November 2026. Rules set before the calculations: [routing_protocol.md](routing_protocol.md). Hand-worked example: [routing_toy_example.md](routing_toy_example.md). Full table: `results/routing/2026-11-01/comparison_table.md`.

**Question.** For the **same net quantity** of BTC, is buying through USDC → USDT → BTC cheaper than USDC → BTC directly?

**Short answer.**
All figures are savings **estimated on the observed books**, not executable savings; every fee level is a scenario.
- **Medians.** With no fees the indirect route's **median** advantage is **below 1 bp** (+0.2 bp at 1 BTC, +0.7 bp at 5 BTC). Individual seconds can be larger (95th percentile +1.4 bp at 1 BTC, +1.9 bp at 5 BTC; best second +5.5 bp).
- **With fees.** The indirect route pays one extra fee. At 1 bp per leg the median turns negative, but the indirect route is still cheaper in **13% of the seconds at 1 BTC and 33% at 5 BTC**. At 10 bp per leg, **no gain is observed** on that day among the evaluable comparisons.
- **Coverage.** At 5 BTC, only 23% of the seconds allow both routes to be evaluated with 25 levels.

## 1. Data and checks

- **Source.** Tardis.dev, `binance` / `book_snapshot_25`, **2026-11-01**. That day was chosen for availability alone, before any calculation. It is a Sunday.
- **Files.** Three files, all MD5 verified, with metadata and SHA-256 kept. 405,124 snapshots for BTCUSDC, 463,716 for BTCUSDT, 298,805 for USDCUSDT.
- **Book quality.** Sorted, asks ascending and bids descending, never crossed, no empty values. Tardis reports no incident.
- **Alignment.** One decision every second (86,399), by an as-of join (`aj`) on the **Tardis arrival time**: only books already received are used.
- **Book age.** The median is under 0.2 s and the 99th percentile under 2 s. **No interruption above 10 s.** **No comparison was dropped for staleness** (10 s rule, fixed in advance).
- **Visible depth (25 levels).** Comparison is possible for 100 % of the seconds at 0.01 BTC, 99.9 % at 0.1 BTC, **83 % at 1 BTC** and only **23 % at 5 BTC**. At 5 BTC: 24 % direct route only, 14 % indirect only, 38 % neither. Missing levels are **never** extrapolated.
- **Checks on the calculations:**
  - a hand-worked example, which caught an operator-order error in q, since fixed ;
  - vectorized calculation identical to the scalar one on 200 real seconds ;
  - the largest apparent saving (+5.5 bp, 1 BTC, 14:14:32) recomputed independently in Python from the raw files: identical. It is real on the observed book. That second, the first BTC/USDC levels were tiny (0.0001–0.0005 BTC), while BTC/USDT offered 1.06 BTC at its best price.
- **No assumption that 1 USDC = 1 USDT.** Over the day, USDC trades between **1.00094 and 1.00126 USDT**, and the BTC pairs imply the same rate to within ±2 bp. The conversion always goes through the USDC/USDT book.

## 2. Results

Medians over the seconds where both routes can be evaluated. `economie_bps` > 0 means the indirect route is cheaper.

| Size | No fees (optimistic bound) | 1 bp per leg | 2.5 bp per leg | 10 bp per leg (current VIP 0 rate, not verified for 1 Nov) | Free stable leg, BTC at 10 bp | Free direct pair, others at 10 bp |
|---|---|---|---|---|---|---|
| 0.01 BTC | −0.18 bp (37.6 % of seconds) | −1.19 bp (4.7 %) | −2.69 bp (0 %) | −10.2 bp (0 %) | −0.18 bp (37.6 %) | −20.2 bp (0 %) |
| 0.1 BTC | −0.17 bp (38.9 %) | −1.17 bp (5.2 %) | −2.67 bp (0 %) | −10.2 bp (0 %) | −0.17 bp (38.9 %) | −20.2 bp (0 %) |
| 1 BTC | **+0.19 bp, +1.5 USDC** (61.1 %) | −0.81 bp (13.3 %) | −2.31 bp (0 %) | −9.8 bp (0 %) | **+0.19 bp** (61.1 %) | −19.8 bp (0 %) |
| 5 BTC | **+0.74 bp, +29 USDC** (91.5 %) | −0.26 bp (32.6 %) | −1.76 bp (0.8 %) | −9.3 bp (0 %) | **+0.74 bp** (91.5 %) | −19.3 bp (0 %) |

The percentages in brackets are the share of seconds where the indirect route is cheaper.

Spread of `economie_bps`, from the 5th to the 95th percentile, with no fees:

| Size | 5th percentile | 95th percentile |
|---|---|---|
| 0.01 BTC | −1.3 bp | +1.0 bp |
| 1 BTC | −0.9 bp | +1.4 bp |
| 5 BTC | −0.2 bp | +1.9 bp |

The largest no-fee saving of the day is +5.5 bp.

- **Why fees weigh so much.** Both routes buy BTC once, but the indirect route **also** converts USDC into USDT. With an equal fee f on every leg, it pays roughly one extra f. Its median gross advantage is below 1 bp, so the **median** changes sign at **about 0.7 bp per leg at 5 BTC**, about 0.2 bp at 1 BTC, and below 0 for small sizes. This is the break-even of the median, not the point where every saving disappears: at 1 bp, 13% (1 BTC) and 33% (5 BTC) of the seconds still favour the indirect route; at 2.5 bp, 0.8% of the seconds at 5 BTC; at 5 bp, a single second at 1 BTC; from 7.5 bp, none.
- **Where the gross advantage comes from.** Depth: for large sizes, the BTC/USDT book is deeper than BTC/USDC. For small orders, the direct route is slightly better.

## 3. Limits

- **Fees.** Binance only publishes its **current** schedule. Rates and any USDC promotions on 1 November are unknown, so every row is a **scenario**.
- **Trading rules.** Steps and minimum notional come from the 11 November API and are assumed identical on 1 November.
- **Execution.**
  - These are costs estimated on observed books. A market order also moves the book.
  - The two indirect legs are **not atomic**: the price can move between them. The gross advantage (0.2–0.7 bp) is of the same order as BTC's moves over a few hundred milliseconds.
- **Depth.** At 5 BTC, 25 levels are not enough for most seconds. The full book (`incremental_book_L2`) would be needed.
- **One single day**, a Sunday.

## 4. Verdict

**Does the apparent saving survive fees?** Not as a median: with an equal fee on every leg, the median saving is negative from 1 bp per leg upwards. Some seconds remain favourable at 1 bp (13% at 1 BTC, 33% at 5 BTC) and, rarely, up to 5 bp. At 10 bp per leg (the VIP 0 rate published today, not verified for 1 November), no second of the day favours the indirect route among the evaluable comparisons; the median gap is about −10 bp.

**For which sizes?** The median is positive only at 1 and 5 BTC, with no fees or if the USDC/USDT conversion is **free** while both BTC pairs carry **the same fee** (a scenario, not a verified condition). Even then:
- the median saving is +0.2 bp at 1 BTC (about 1.5 USDC) and +0.7 bp at 5 BTC (about 29 USDC) ;
- at 5 BTC, it can only be measured in 23 % of the seconds ;
- it is exposed to the price risk between the two operations.

**Does it deserve more work?** **Not as it stands.** The estimated advantage is small and depends heavily on fees that could not be verified for the period, and no executable saving was measured. It would only be worth taking up again if a **verified** fee condition made the USDC/USDT conversion free, or much cheaper than the BTC pairs, for the account concerned. In that case, the next step would be:
1. validation on other days, starting with 2026-10-01, which is already available, using the full book for large sizes ;
2. a test of the delay between the two operations.
