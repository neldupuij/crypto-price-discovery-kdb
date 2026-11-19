# Hand-detailed example (test of `src/route_lib.q`)

Script: `q analysis/route_toy_check.q -q`. Target: **1.5 BTC net**, fee of **10 bp on every leg**, always charged in the asset received.

## Toy books

| BTCUSDC asks (USDC, BTC) | BTCUSDT asks (USDT, BTC) | USDCUSDT bids (USDT per USDC, USDC) |
|---|---|---|
| 100 × 1 | 100.2 × 1 | 1.001 × 50 |
| 101 × 2 | 101.1 × 3 | 1.0005 × 500 |
| 102 × 5 | | |
| best bid: 99 | | best ask: 1.0012 |

## Direct route (USDC → BTC)

1. **Gross BTC to buy.** 1.5 / (1 − 0.001) = 1.5015015…, rounded up to a 0.00001 step: **1.50151 BTC**.
2. **Walking the asks.** 1 BTC at 100, then 0.50151 BTC at 101. Cost: 100 + 50.65251 = **150.65251 USDC**.
3. **Net BTC received.** 1.50151 × 0.999 = 1.50000849 BTC, so **0.00000849 BTC** above the target.
4. **Credit for that excess** at the best bid: 0.00000849 × 99 = 0.00084051.
5. **Direct cost = 150.651669 USDC.**

## Indirect route (USDC → USDT → BTC)

1. **Gross BTC.** Same reasoning: **1.50151 BTC**.
2. **Walking the BTCUSDT asks.** 100.2 + 101.1 × 0.50151 = **150.902661 USDT** needed.
3. **Gross USDT to receive.** The selling fee is charged in USDT: 150.902661 / 0.999 = **151.053715 USDT**.
4. **Selling USDC, walking the bids.**
   - The first level gives 50 × 1.001 = 50.05 USDT.
   - 101.003715 USDT is still missing, so (151.053715 − 50.05) / 1.0005 = 100.953238 USDC at 1.0005.
   - In total, 150.953238 USDC, rounded up to the step of 1: **151 USDC**.
5. **Actual proceeds.** 50.05 + 101 × 1.0005 = 151.1005 USDT gross, so 150.949400 USDT net after the fee.
6. **USDT left over.** 150.949400 − 150.902661 = 0.0467385 USDT. Credited at the USDC ask: 0.0467385 / 1.0012 = 0.046682 USDC.
7. **Indirect cost** = 151 − 0.046682 − 0.000841 = **150.952477 USDC**.

## Result

- `economie_bps` = 10000 × (150.651669 − 150.952477) / 150.651669 = **−19.97 bp**: the indirect route is more expensive.
- Without fees: direct 150.5, indirect 150.649920, i.e. **−9.96 bp**.
- **9 BTC** requested on the direct route exceeds the 8 BTC visible: the route is **not evaluable**, with no extrapolation.

**Error found by this test.** In q, `xr-(left%u)-ex*bb` is read `xr − (left/u − ex×bb)`, because q evaluates from right to left. The cost added back the excess-BTC credit instead of subtracting it. The fix is `xr-(left%u)+ex*bb`. q and the hand calculation (done independently in Python) now agree to the ninth decimal.
