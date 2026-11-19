/ ============================================================
/ analysis/exercise_route_1btc.q
/ Guided exercise: buy 1 BTC net at 2026-11-01 16:43:00, directly (USDC -> BTC)
/ and via USDT (USDC -> USDT -> BTC), step by step, on the books already loaded.
/ Same rules as src/route_lib.q and docs/routing_protocol.md; nothing new is computed
/ for the project: every step is checked against route_lib.q and the saved CSV.
/ --
/ Run from the project folder, line by line in VS Code (Cmd+D), or all at once:
/   q analysis/exercise_route_1btc.q -fee 10 -exit -q
/   q analysis/exercise_route_1btc.q -fee 0 -exit -q
/ (-exit leaves q at the end; without it q stays open for your own queries)
/ Change T or Q below to redo the exercise on another case.
/ Guide: docs/exercise_route_1btc.md
/ ============================================================

\l src/route_lib.q
\P 12                                          / show 12 significant digits

T:2026.11.01D16:43:00                          / decision instant
Q:1f                                           / target: 1 BTC NET (after fees)
/ fee per leg in bp, same on all legs: 10 by default, or  -fee 0  /  -fee 1  on the command line
opt:.Q.opt .z.x
FEE:1e-4*$[`fee in key opt; "F"$first opt`fee; 10f]
FD:FEE; FB:FEE; FS:FEE                         / fees: BTCUSDC, BTCUSDT, USDCUSDT (fractions)
-1 "Fee per leg: ",string[1e4*FEE]," bp";


/ ------------------------------------------------------------
/ STEP 1. Which snapshot do we "know" at T?
/ ------------------------------------------------------------
/ The last snapshot that had ARRIVED (lt = Tardis arrival time) at or before T.
/ lt is sorted, so  lt bin T  gives the index of the last lt <= T.
/ This is exactly what aj does in analysis/route_costs.q.
ld:{get hsym `$"data/routing/2026-11-01/",x}
bU:ld "BTCUSDC"; bT:ld "BTCUSDT"; uU:ld "USDCUSDT"
snap:{[t] t t[`lt] bin T}
sD:snap bU; sB:snap bT; sU:snap uU
-1 "\n== STEP 1: book age at T (must be <= 10 s) ==";
show ([] book:`BTCUSDC`BTCUSDT`USDCUSDT; arrived:(sD`lt;sB`lt;sU`lt); ageMs:1e-6*`long$T-(sD`lt;sB`lt;sU`lt))


/ ------------------------------------------------------------
/ STEP 2. Look at the books (first 6 levels)
/ ------------------------------------------------------------
lv:{[p;s] 6#([] level:til 25; price:p; amount:s; cumAmount:sums s)}
-1 "\n== STEP 2a: BTCUSDC asks (USDC per BTC, BTC) ==";   show lv[sD`ap; sD`aq]
-1 "== STEP 2b: BTCUSDT asks (USDT per BTC, BTC) ==";    show lv[sB`ap; sB`aq]
-1 "== STEP 2c: USDCUSDT bids (USDT per USDC, USDC) ==";  show lv[sU`bp; sU`bq]
-1 "BTCUSDC best bid: ",string[first sD`bp],"   USDCUSDT best ask: ",string first sU`ap;


/ ------------------------------------------------------------
/ STEP 3. DIRECT route: buy BTC on the BTCUSDC asks
/ ------------------------------------------------------------
/ 3a. The fee is taken in BTC: to RECEIVE Q we must BUY Q/(1-FD), rounded UP to 0.00001 BTC
gD:roundUp[Q%1-FD; STEP_BTC]
/ 3b. Walk the asks: on each level take what is still missing, capped by the level amount
/     missing before level i = gD - (sum of the amounts of the levels before i)
fillD:sD[`aq] & 0|gD-0^prev sums sD`aq
costGrossD:sum sD[`ap]*fillD                   / USDC paid
/ 3c. Net BTC received above the target, credited at the BTCUSDC best bid
exD:(gD*1-FD)-Q
costD:costGrossD-exD*first sD`bp
-1 "\n== STEP 3: DIRECT ==";
-1 "gross BTC to buy: ",string gD;
show select level, price, fill, usdc:price*fill from ([] level:til 25; price:sD`ap; fill:fillD) where fill>0
-1 "USDC paid: ",string[costGrossD],"   excess BTC: ",string[exD],"   DIRECT COST (USDC): ",string costD;


/ ------------------------------------------------------------
/ STEP 4. INDIRECT route: USDC -> USDT (sell USDC on the bids), then USDT -> BTC (asks)
/ ------------------------------------------------------------
/ We work BACKWARDS from the BTC we want.
/ 4a. Gross BTC to buy on BTCUSDT (fee in BTC), same rounding as 3a
gB:roundUp[Q%1-FB; STEP_BTC]
/ 4b. USDT needed: walk the BTCUSDT asks
fillB:sB[`aq] & 0|gB-0^prev sums sB`aq
usdtNeeded:sum sB[`ap]*fillB
/ 4c. The USDC sale pays its fee in USDT: gross USDT to receive
usdtGross:usdtNeeded%1-FS
/ 4d. How many USDC to sell on the USDCUSDT bids to receive usdtGross?
/     value of each level in USDT = price*amount; on a level we sell (USDT still missing)/price
valU:sU[`bp]*sU`bq
fillU:sU[`bq] & 0|(usdtGross-0^prev sums valU)%sU`bp
usdcExact:sum fillU
usdcSold:roundUp[usdcExact; STEP_USDC]          / whole USDC only
/ 4e. What the rounded sale really gives, net of the fee
usdtNet:(1-FS)*sum sU[`bp]*sU[`bq] & 0|usdcSold-0^prev sums sU`bq
leftUsdt:usdtNet-usdtNeeded                     / USDT left over (>= 0 because of the rounding)
/ 4f. Credits: leftover USDT at the USDCUSDT best ask, excess BTC at the BTCUSDC best bid
exB:(gB*1-FB)-Q
costI:usdcSold-(leftUsdt%first sU`ap)+exB*first sD`bp
/      careful: q reads right to left, so this is usdcSold - (leftUsdt/ask + exB*bid)
-1 "\n== STEP 4: INDIRECT ==";
-1 "gross BTC to buy on BTCUSDT: ",string gB;
show select level, price, fill, usdt:price*fill from ([] level:til 25; price:sB`ap; fill:fillB) where fill>0
-1 "USDT needed: ",string[usdtNeeded],"   gross USDT to receive: ",string usdtGross;
show select level, price, fill, usdt:price*fill from ([] level:til 25; price:sU`bp; fill:fillU) where fill>0
-1 "USDC to sell: ",string[usdcExact]," -> rounded: ",string usdcSold;
-1 "net USDT received: ",string[usdtNet],"   left over: ",string[leftUsdt],"   excess BTC: ",string exB;
-1 "INDIRECT COST (USDC): ",string costI;


/ ------------------------------------------------------------
/ STEP 5. Compare
/ ------------------------------------------------------------
eco:1e4*(costD-costI)%costD                     / > 0 means indirect is cheaper
-1 "\n== STEP 5 ==";
-1 "saving of the indirect route: ",string[costD-costI]," USDC = ",string[eco]," bp";


/ ------------------------------------------------------------
/ STEP 6. Checks against the project code and results
/ ------------------------------------------------------------
libD:direct[(sD`ap; sD`aq; first sD`bp); Q; FD]
libI:indirect[(sB`ap; sB`aq); (sU`bp; sU`bq; first sU`ap); first sD`bp; Q; FB; FS]
-1 "\n== STEP 6: checks ==";
-1 "route_lib direct  : ",string[libD`cost],"  ok=",string[libD`ok],"  diff=",string costD-libD`cost;
-1 "route_lib indirect: ",string[libI`cost],"  ok=",string[libI`ok],"  diff=",string costI-libI`cost;
/ the saved CSV only holds the 0 bp (F0) and 10 bp (U10) scenarios
sc:$[all 0=FD,FB,FS; `F0; all 0.001=FD,FB,FS; `U10; `none]
/ (the file name contains "-", so it is built with hsym `$"...": a `:... literal would stop at the first "-")
csvE:hsym `$"results/routing/2026-11-01/economie_F0_U10.csv"
savedEco:$[sc~`none; 0n; first exec economie_bps from (("PSFFS";enlist",") 0: csvE) where t=T, scenario=sc, size=Q]
-1 $[sc~`none; "saved economie_bps: only the 0 bp and 10 bp scenarios are in the CSV";
     null savedEco; "saved economie_bps (",string[sc],"): none, the comparison is not evaluable at this second";
     "saved economie_bps (",string[sc],"): ",string savedEco];
/ a route whose size exceeds the 25 visible levels is NOT evaluable: its "cost" above is meaningless
if[not libD`ok; -1 "WARNING: DIRECT route not evaluable (not enough depth in 25 levels): ignore its cost"];
if[not libI`ok; -1 "WARNING: INDIRECT route not evaluable (not enough depth in 25 levels): ignore its cost"];

if[`exit in key opt; exit 0]
