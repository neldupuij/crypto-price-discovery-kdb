/ ============================================================
/ analysis/route_toy_check.q
/ Hand-checkable example of the route costs (docs/routing_toy_example.md
/ gives the same numbers computed by hand, step by step).
/ Run from the project folder:  q analysis/route_toy_check.q -q
/ ============================================================
\l src/route_lib.q
\P 12

/ toy books (best level first)
btcusdc:(100 101 102f; 1 2 5f; 99f)          / asks prices, asks BTC, best bid
btcusdt:(100.2 101.1f; 1 3f)                  / asks prices, asks BTC
usdcusdt:(1.001 1.0005f; 50 500f; 1.0012)     / bids prices, bids USDC, best ask

q:1.5; f:0.001                                 / target 1.5 BTC net, 10 bp on every leg
d:direct[btcusdc; q; f]
i:indirect[btcusdt; usdcusdt; btcusdc 2; q; f; f]
show d
show i
-1 "economie_bps = ",string 1e4*(d[`cost]-i`cost)%d`cost;

/ no-fee case
d0:direct[btcusdc; q; 0]; i0:indirect[btcusdt; usdcusdt; btcusdc 2; q; 0; 0]
-1 "no fees: direct ",string[d0`cost],"  indirect ",string[i0`cost],"  economie_bps ",string 1e4*(d0[`cost]-i0`cost)%d0`cost;

/ depth check: 9 BTC is more than the 8 BTC visible on BTCUSDC -> not evaluable
-1 "9 BTC direct feasible? ",string (direct[btcusdc; 9; 0])`ok;

/ the vectorized versions must give the same numbers (books given as 1-element lists)
dv:directV[enlist each btcusdc; q; f]
iv:indirectV[enlist each btcusdt; enlist each usdcusdt; enlist btcusdc 2; q; f; f]
-1 "vectorized direct ",string[first dv`cost],"  indirect ",string first iv`cost;
-1 "same as scalar: ",string (1e-9>abs (first dv`cost)-d`cost) & 1e-9>abs (first iv`cost)-i`cost;
\\
