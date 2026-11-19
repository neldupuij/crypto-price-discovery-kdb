# Funding — replication assessment (frozen protocol v2)

11 November 2026. Protocol: [funding_replication_protocol_v2_2026-11-11.md](funding_replication_protocol_v2_2026-11-11.md) (v1 kept). Exploratory sample: BTCUSDT 2026-10. Five validation samples, **retrospective**: BTCUSDT 2026-08 and 2026-09, ETHUSDT 2026-08, 2026-09 and 2026-10. Reserved period, not examined: from 12 November 2026.

**Short verdict.**
- **Not confirmed**: under the replication criterion, the basis effect observed after payment in October **does not replicate** (0 samples out of 5).
- **No contradiction**: no sample shows a significant effect in the opposite direction.
- **Economic size**: negligible.

---

## 1. Data and quality checks

| Sample | Spot / perp trades | Payments analysed / excluded | Placebos | Funding: min / median / max (bp per 8 h) |
|---|---|---|---|---|
| BTC Oct (exploratory) | 25.7 M / 32.5 M | 87 / 5 (+1 outside the month) | 622 | −0.41 / 0.45 / 1.00 |
| BTC Aug | 23.9 M / 35.7 M | 87 / 5 | 625 | 0.06 / 0.68 / 1.00 |
| BTC Sep | 26.7 M / 36.0 M | 89 / 0 | 616 | −0.26 / 0.48 / 1.00 |
| ETH Aug | 20.5 M / 33.0 M | 89 / 3 | 630 | −0.09 / 0.52 / 1.00 |
| ETH Sep | 22.3 M / 35.9 M | 85 / 4 | 614 | −1.08 / 0.52 / 1.00 |
| ETH Oct | 18.9 M / 30.9 M | 89 / 3 | 639 | −1.36 / 0.37 / 1.00 |

Excluded payments, beyond the counts above: one window per month is also dropped because it would need data from the previous month (the first payment of the month, at 00:00), as the protocol requires.

- **Audit of the raw files**: 92 days per symbol. Timestamps are sorted, there are no missing prices and no trades outside their day. Funding is always paid every 8 hours, at 00, 08 and 16 UTC, over the three months and for both symbols.
- **Comparison with the official candles**:
  - Spot: identical minute by minute on both symbols.
  - Perp: 722 minutes (BTC) and 606 minutes (ETH) out of 132,480 differ by more than 1%. The totals agree to within 0.01%.
  - The 27-minute hole in the perp file on **27 October, 00:03–00:29 UTC**, shows up for **both** symbols. It is a gap in the Binance dataset.
- **Exclusions**: windows containing a minute with a gap above 10% are dropped, with the threshold set in advance. The anomalous minutes are spread over the day. The excess at 00:00 comes from the 27 October hole.
- **Price age**: at the 99th percentile, 3.4 s for BTC and 6.4 s for ETH. The ETH spot trades less often.
- **Funding estimate known 60 min before payment**, rebuilt from the premium index (three months):

  | Symbol | Correlation with the paid rate | Mean absolute error | Same sign |
  |---|---|---|---|
  | BTC | 0.958 | 0.07 bp | 96% |
  | ETH | 0.955 | 0.09 bp | 96% |

- **Deviations from the protocol**: none on the parameters. Two process points:
  - A first run of the preparation scripts took the default parameters, because zsh passed the arguments as a single string. It was redone with the arguments split correctly. BTC October still reproduces milestone 1 exactly.
  - The scripts `notebooks/replication_table.py` and `plot_replication.py` were written after the computations. They only lay out the frozen CSVs and apply the criterion of protocol section 3. They compute no new statistic.

## 2. The effect observed in the exploratory sample (reminder)

BTC October: the basis rises by **+0.29 bp** more after a payment than after another full hour. The 95% interval is [0.05 ; 0.52], and that was 1 significant measure out of 23 tested. The asymmetry of perp flows aligned on the funding sign was **−0.046**, the opposite of the unwinding hypothesis.

## 3. Stability on the new samples

### Primary variable: basis change from payment to +60 min (expected > 0)

| Sample | Mean at payments / at placebos | Median at payments / at placebos | Payment − placebo | 95% interval | Verdict |
|---|---|---|---|---|---|
| BTC Oct (explo.) | 0.25 / −0.04 | 0.30 / −0.03 | **+0.29** | [0.05 ; 0.52] | (exploratory) |
| BTC Aug | 0.02 / 0.00 | −0.04 / −0.07 | +0.01 | [−0.30 ; 0.34] | inconclusive |
| BTC Sep | 0.04 / 0.00 | 0.09 / −0.04 | +0.04 | [−0.21 ; 0.29] | inconclusive |
| ETH Aug | 0.13 / −0.03 | 0.10 / −0.05 | +0.15 | [−0.08 ; 0.39] | inconclusive |
| ETH Sep | 0.22 / −0.03 | 0.09 / −0.08 | +0.25 | [−0.03 ; 0.53] | inconclusive |
| ETH Oct | 0.02 / 0.00 | 0.03 / 0.01 | +0.02 | [−0.26 ; 0.27] | inconclusive |

Standard deviation per window: 1.0 to 1.2 bp.

→ **0 replications, 0 contradictions, 5 inconclusive.** Under the protocol, the finding is **NOT REPLICATED**.

Descriptively, outside the criterion: all 5 differences are positive. But they are much smaller than in October, averaging +0.10 bp (range 0.01 to 0.25). That pattern fits a small or zero effect, which the exploratory sample, chosen because it stood out, overestimated.

**Hour control.** The 00:00 payment, which drove the October effect (ranked 1st out of 24 hours), ranks 3rd, 7th, 9th, 8th and 16th in the new samples. The payment hours are never systematically at the top of the 24-hour distribution.

### Secondary measures

These are not decisive under the protocol.

| | Sense expected | Replicate | Contradict | Inconclusive | Same sign |
|---|---|---|---|---|---|
| S1: basis change, −5 → +5 min | > 0 | 1 (ETH Oct, +0.22 [0.06 ; 0.39]) | 0 | 4 | 5/5 |
| S2: aligned perp asymmetry | < 0 | 0 | 0 | 5 | 3/5 |
| H: unwinding hypothesis (same measure) | > 0 | 0 | 0 | 5 | 2/5 |

- The October "contradiction" of the unwinding hypothesis **does not come back** either: the signs alternate, and every interval contains 0.
- **No sample shows flows compatible with unwinding.**

## 4. What can really be anticipated with the information available before payment

- **The funding itself: yes.** The estimate at T − 60 min predicts the paid rate well, with a correlation of 0.96 and the right sign 96% of the time, on both symbols.
- **A price or flow move associated with it: no, on this evidence.**
  - No effect replicates, either across all payments or by funding category.
  - The categories built from the estimate, with the thresholds fixed on BTC October, give results that **change sign from one sample to the next**. For example, the "low estimate" category gives +0.36 and +0.49 bp on BTC in August and September, then −0.35 bp on ETH in October.
- **Transferability of the thresholds**, shown here because the protocol asks for it:

  | Sample | Low / mid / high estimate | Realized negative / positive |
  |---|---|---|
  | BTC Oct | 29 / 29 / 29 | 15 / 72 |
  | BTC Aug | **8** / 33 / 46 | **0** / 87 |
  | BTC Sep | 17 / 42 / 30 | 5 / 84 |
  | ETH Aug | 22 / 33 / 34 | 4 / 85 |
  | ETH Sep | 24 / 37 / 24 | 9 / 76 |
  | ETH Oct | 29 / 43 / **17** | 18 / 71 |

  The thresholds transfer, but the groups become unbalanced: 8 events in the low category of BTC August, and no negative funding at all that month. The analysis by category has too few events to say anything per month.

## 5. Economic size

- **Primary effect, validation samples**: +0.01 to +0.25 bp, about **0.10 bp on average**. That is **1 to 25 USD per million USD of notional**, roughly 10 USD on average.
- **Exploratory, for reference**: 0.29 bp, or 29 USD per million.
- **Relative to the noise of a single event**: 0.01 to 0.24 standard deviations.
- **Relative to costs**:
  - the standard published Binance USDⓈ-M fees are about **5 bp taker / 2 bp maker per side** (order of magnitude, to be confirmed) ;
  - the observed effect is **20 to 50 times smaller than one taker fee** ;
  - it is also smaller than the funding paid itself (≤ 1 bp).
- These are last-trade prices: no spread and no depth. It is not an achievable PnL. Even if the effect were real, it would not pay for one side of a trade.

## 6. Conclusion and options (for your decision)

- **What we can say**: on 5 samples analysed with a protocol frozen in advance, we observe no robust signature, either in the basis or in flows compatible with unwinding, around funding payments on Binance BTCUSDT and ETHUSDT. These are periods when the funding stays between −1.4 and +1 bp per 8 hours.
- **The October effect** looks like a sampling fluctuation, possibly amplified by a 00:00 UTC clock effect.
- **What we cannot say**: that no effect exists when funding is high (> 1 bp). That regime **is absent** from the data examined.
- **Options**, not started:
  1. Stop here and present this result as is. It shows a methodology that holds up in an interview: exploration, then pre-registration, then replication.
  2. Look for a high-funding period in the past (2024–2025). That requires re-checking the payment interval and the data formats.
  3. Keep the period from 12 November for a final chronological test, if a new hypothesis is formulated beforehand.

## Files

- Results per sample: `results/funding/<SYM>_<MONTH>/*.csv`.
- Summary: `results/funding/replication_summary.csv` and `replication_categories.csv`.
- Charts:
  - `results/figures/funding_replication.png` (intervals per sample) ;
  - `funding_by_hour.png` and `funding_profiles.png` (exploratory) ;
  - and their equivalents per sample through `python3 notebooks/plot_funding.py <TAG>`.
