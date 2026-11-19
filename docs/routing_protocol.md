# USDC → BTC routing — analysis rules (written before any cost calculation)

11 November 2026. Purpose: check whether buying BTC with USDC through **USDC → USDT → BTC** costs less than **USDC → BTC** directly, on Binance spot, for one historical day. This is a first verdict only, not an engine.

## 1. Data (checked before choosing)
- Source: Tardis.dev, `binance` / `book_snapshot_25`. The 25 best levels on each side are written **at every change** to those levels. The day is free, with no API key, on the first day of each month.
- Day chosen **for availability alone**, before any economic calculation: **2026-11-01**. It is the most recent free day on which all three pairs (BTCUSDC, BTCUSDT, USDCUSDT) exist. Verified: the files are complete (104 columns, no empty field), the MD5 matches the Tardis `x-md5` header, and SHA-256 and metadata are kept in `*.meta.json`. Tardis lists no incident since September 2026.
- Kept for a later validation, not examined: 2026-10-01, also available.

## 2. Decision instants and alignment
- Decision instants: **every second** of the day (86,400 instants).
- Information available at instant t: for each pair, the **last snapshot received** (`local_timestamp` ≤ t, Tardis arrival time). We use an as-of join (`aj`) in q, on the arrival time, never on future data.
- **Book age** = t − `local_timestamp` of the snapshot used. It is kept for each pair.
- **Too-old rule**: a comparison is **excluded** if one of the books it needs is **more than 10 s** old. Since Tardis only writes on change, an old book can be a quiet book or a gap in the feed. The two cannot be told apart, so the rule is cautious.
- **Interruption**: any interval of more than 10 s between two consecutive snapshots of a pair. These are listed.

## 3. Calculations (Binance spot market order, "taker" side)
Target **Q** = net BTC received, tested at 0.01, 0.1, 1 and 5 BTC.

- **Direct** (BTCUSDC): you buy BTC, which **consumes the asks**. Fee rate f_d, charged in BTC, the asset received. You must buy G = Q / (1 − f_d), **rounded up** to the step of 0.00001 BTC. Cost = Σ ask price × quantity taken, level by level, in USDC.
- **Indirect**:
  1. BTCUSDT: you buy G' = Q / (1 − f_b), rounded up to 0.00001 BTC, on the **asks**. Cost C in USDT.
  2. USDCUSDT: you **sell USDC**, which consumes the **bids**. The fee f_s is charged in USDT, the asset received. You need gross proceeds ≥ C / (1 − f_s). Number of USDC to sell: walk the bids, then **round up to a whole number** (step of 1 USDC).
- **Exact same net BTC**: rounding gives slightly more than Q. The extra BTC is credited at the BTCUSDC **best bid** of the same instant. The leftover USDT is credited at the price to buy USDC back, i.e. the USDCUSDT **ask**. Both corrections are reported.
- **Never** assume 1 USDC = 1 USDT. The conversion always goes through the USDCUSDT book.
- **Not evaluable**: if the 25 visible levels are not enough to fill the quantity, the route is **not evaluable** at that instant. Missing levels are never extrapolated. Cases where only one route is evaluable are reported separately.
- Minimum notional: 5 USD on all three pairs (current rule); it is met by every target size.
- **Current** rules (2026-11-11 `exchangeInfo`): step of 0.00001 BTC, step of 1 USDC, tick of 0.01 and 0.00001. Rules in force on 2026-11-01 are assumed to be the same, **not verified**.
- `economie_bps = 10000 × (cout_direct − cout_indirect) / cout_direct`, computed **only** when both routes are evaluable and not too old.

## 4. Fees (scenarios)
Binance shows only its **current** schedule, and the rates of 1 November 2026 are not verifiable. Every fee calculation is therefore a **scenario**:

| Scenario | BTCUSDC (direct) | BTCUSDT | USDCUSDT | Meaning |
|---|---|---|---|---|
| F0 | 0 | 0 | 0 | optimistic bound (no fees) |
| U1, U2.5, U5, U7.5, U10 | f | f | f | same rate on every leg; U10 = current VIP 0 rate without BNB (0.10%), read on 2026-11-11 |
| A-stable | 10 bp | 10 bp | **0** | the stablecoin leg is free (hypothetical promotion) |
| A-direct | **0** | 10 bp | 10 bp | the direct pair is free (hypothetical USDC promotion) |

## 5. Caveats stated in advance
- These are costs **estimated on observed books**: a market order can move the book, and the visible depth is limited to 25 levels.
- The indirect route has **two non-atomic operations**. The price can move between them. Its cost is **not guaranteed**.
- **One single day** only. A Sunday, with little activity.
