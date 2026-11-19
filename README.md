# Crypto Price Discovery & Adverse Selection in kdb+/q

Where does the price of Bitcoin get formed, and what does that mean for a market maker?

This project studies the microstructure of fragmented crypto markets using **KDB-X / q**:

1. **Lead-lag**: which venue or instrument moves first (Binance spot vs perpetual, then Coinbase, OKX, Bybit), and by how many milliseconds.
2. **Markouts**: how much a liquidity provider quoting on a slow venue would lose to informed flow.
3. **Fair price & market-making simulation**: a cross-venue fair price, and a quoting strategy with inventory control (Avellaneda-Stoikov), compared against a naive quoter.

## Roadmap

- [x] Load Binance spot and USD-M perpetual trades (historical, data.binance.vision)
- [x] Lead-lag: cross-correlation of returns at 100 ms and 10 ms resolution
- [x] Lead-lag: event study (response of one market to large moves in the other)
- [x] Multi-day check: 8 days (Nov 1–8 2026), perp trade-price moves precede spot ones every day (lead-lag ratio 2.5–5.1). Observed on last-trade prices; trade frequency, stale prices and clock alignment not controlled; not a demonstrated exploitable opportunity
- [ ] Add Coinbase / OKX / Bybit via live websocket capture into a kdb tickerplant
- [ ] Markout analysis (1 s, 5 s, 30 s)
- [ ] Cross-venue fair price
- [ ] Market-making simulation with inventory skew

## Funding study (in progress)

Do funding payments come with flows compatible with position unwinding, and do spot/perp trades anticipate the related price moves?
Milestone 1 (BTCUSDT, October 2026, descriptive): see [docs/funding_report.md](docs/funding_report.md) and [docs/funding_data_notes.md](docs/funding_data_notes.md).

- [x] Data audit (trades, funding, ex-ante funding estimate rebuilt from premium index, quality check vs klines)
- [x] 1 s / 1 min variables, event study ±60 min vs placebo hours, day bootstrap
- [x] Replication on 5 new samples (BTC Aug–Sep, ETH Aug–Oct) with a frozen protocol: **not replicated**, no contradiction, negligible size — see [docs/funding_replication_report.md](docs/funding_replication_report.md)
- [ ] Out-of-sample prediction (only if a robust effect appears)
- [ ] Hedging implication (only if a robust effect appears)

Pipeline: `bash src/funding_pipeline.sh 2026-10-01 2026-10-31`, then `q src/funding.q`, `q src/check_klines.q`, `q analysis/funding_panel.q`, `q analysis/funding_events.q`, `python3 notebooks/plot_funding.py`.

## USDC → BTC routing test (feasibility, 1 day)

Is USDC → USDT → BTC cheaper than USDC → BTC on Binance spot, for the same net BTC? Tardis `book_snapshot_25`, 2026-11-01, one decision per second, as-of join on arrival time.
Verdict (savings estimated on observed books, fees are scenarios): with no fees the **median** advantage of the indirect route is below 1 bp (+0.19 bp at 1 BTC, +0.74 bp at 5 BTC). At 1 bp per leg the median turns negative, but the indirect route is still cheaper in 13% of the seconds at 1 BTC and 33% at 5 BTC. At 10 bp per leg, no gain is observed on that day among the evaluable comparisons. At 5 BTC only 23% of the seconds can be evaluated with 25 levels. See [docs/routing_note.md](docs/routing_note.md).

Guided exercise (1 BTC at 2026-11-01 16:43:00, direct vs via USDT, step by step): [docs/exercise_route_1btc.md](docs/exercise_route_1btc.md), `q analysis/exercise_route_1btc.q -fee 10 -exit -q`.

Pipeline: `bash src/tardis_download.sh binance book_snapshot_25 2026-11-01 <SYM>` (×3), `q src/route_load.q -date 2026-11-01 -sym <SYM> -q` (×3), `q analysis/route_toy_check.q -q`, `q analysis/route_costs.q -date 2026-11-01 -q`, `python3 notebooks/plot_routing.py 2026-11-01`.

## Layout

```
data/raw/        raw downloaded files
data/hdb/        kdb historical database
src/             q code: loaders, utilities, tickerplant
analysis/        q analysis scripts (lead-lag, markouts, ...)
notebooks/       Python notebooks using pykx for charts
results/         tables and figures
docs/            notes and write-up
```

## Requirements

- KDB-X (q) — https://code.kx.com/kdb-x/
- Python 3 + `pykx`, `matplotlib`, `pandas` for charts
