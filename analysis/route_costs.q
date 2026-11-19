/ ============================================================
/ analysis/route_costs.q
/ Direct vs indirect USDC -> BTC route, every second of one day (docs/routing_protocol.md)
/ Run from the project folder:  q analysis/route_costs.q -date 2026-11-01 -q
/ Needs: data/routing/<date>/{BTCUSDC,BTCUSDT,USDCUSDT} (src/route_load.q)
/ Output: results/routing/<date>/*.csv
/ --
/ KEY JOIN: aj (as-of join) on the Tardis ARRIVAL time (local_timestamp).
/ At decision instant t we take, for each pair, the last snapshot that had
/ ARRIVED at or before t. Nothing after t is used. The age of each book
/ (t - arrival time) is kept; a comparison is dropped if any book it needs
/ is older than MAXAGE (10 s, fixed in the protocol before the analysis).
/ ============================================================

\l src/route_lib.q
opt:.Q.opt .z.x
DAY:$[`date in key opt; first opt`date; "2026-11-01"]
dd:"D"$DAY
dir:"data/routing/",DAY,"/"
RD:"results/routing/",DAY
system "mkdir -p ",RD
out:{[n;t] (hsym `$RD,"/",n) 0: csv 0: t}

MAXAGE:0D00:00:10
SIZES:0.01 0.1 1 5f
/ scenarios: name -> fees (BTCUSDC direct; BTCUSDT; USDCUSDT), as fractions
SCEN:`F0`U1`U2_5`U5`U7_5`U10`Astable`Adirect!(
  0 0 0f; 3#0.0001; 3#0.00025; 3#0.0005; 3#0.00075; 3#0.001; 0.001 0.001 0f; 0 0.001 0.001)

/ ------------------------------------------------------------
/ 1. Decision instants and as-of alignment
/ ------------------------------------------------------------
grid:([] t:(dd+0D)+0D00:00:01*1+til 86399)           / 00:00:01 .. 23:59:59

ld:{get hsym `$dir,x}
bU:ld "BTCUSDC"; bT:ld "BTCUSDT"; uU:ld "USDCUSDT"

A:aj[`t; grid; select t:lt, ltD:lt, apD:ap, aqD:aq, bbD:first each bp from bU]
A:aj[`t; A;    select t:lt, ltB:lt, apB:ap, aqB:aq from bT]
A:aj[`t; A;    select t:lt, ltU:lt, bpU:bp, bqU:bq, aaU:first each ap, abU:first each bp from uU]
A:update ageD:t-ltD, ageB:t-ltB, ageU:t-ltU from A
A:update staleD:(null ageD)|ageD>MAXAGE, staleI:(null ageB)|(null ageU)|(ageB>MAXAGE)|ageU>MAXAGE from A
delete bU, bT, uU from `.;

/ interruptions: more than 10 s between two consecutive snapshots of a pair
gaps:raze {[s] t:ld s; d:1_deltas t`lt; w:where d>MAXAGE;
  ([] sym:(count w)#`$s; from:(-1_t`lt) w; gapSec:1e-9*`long$d w)} each ("BTCUSDC";"BTCUSDT";"USDCUSDT")
-1 "Interruptions > 10 s: ",string count gaps;
out["interruptions.csv"; gaps]

/ ages (seconds) at the decision instants
/ sort FIRST: inside a (..;..;..) list q evaluates the items right to left
ageStats:{[n;a] a:asc 1e-9*`long$a; k:count a; `book`median`p95`p99`max!(n; med a; a `long$0.95*k-1; a `long$0.99*k-1; last a)}
ages:(ageStats["BTCUSDC";A`ageD]; ageStats["BTCUSDT";A`ageB]; ageStats["USDCUSDT";A`ageU])
show ages
out["book_ages.csv"; ages]

/ no-fee parity diagnostic: BTCUSDT best ask / BTCUSDC best ask vs USDCUSDT mid
A:update impliedUsdcUsdt:(first each apB)%first each apD, midU:0.5*aaU+abU from A
out["parity_sample.csv"; select t, impliedUsdcUsdt, midU, usdcBid:abU, usdcAsk:aaU from A where 0=(`second$t) mod 60]


/ ------------------------------------------------------------
/ 2. Costs for each size and scenario
/ ------------------------------------------------------------
/ vectorized: all 86 399 instants at once (directV / indirectV in src/route_lib.q)
oneCase:{[sc;q]
  f:SCEN sc;
  d:directV[(A`apD; A`aqD; A`bbD); q; f 0];
  i:indirectV[(A`apB; A`aqB); (A`bpU; A`bqU; A`aaU); A`bbD; q; f 1; f 2];
  r:([] t:A`t; scenario:sc; size:q;
        costD:d`cost; okD:d[`ok] & not A`staleD;
        costI:i`cost; okI:i[`ok] & not A`staleI;
        depthD:d`ok; depthI:i`ok; staleD:A`staleD; staleI:A`staleI;
        usdcSold:i`usdcSold; leftUsdt:i`leftUsdt);
  r:update status:?[okD&okI; `both; ?[okD; `directOnly; ?[okI; `indirectOnly; `neither]]] from r;
  update saveUsdc:?[status=`both; costD-costI; 0n],
         economie_bps:?[status=`both; 1e4*(costD-costI)%costD; 0n] from r}

/ consistency check: vectorized == scalar on 200 random instants (U10, 1 BTC)
system "S 7"
ix:200?count A
cv:oneCase[`U10;1f]
sd:{direct[(A[`apD] x; A[`aqD] x; A[`bbD] x); 1f; 0.001]`cost} each ix
si:{indirect[(A[`apB] x; A[`aqB] x); (A[`bpU] x; A[`bqU] x; A[`aaU] x); A[`bbD] x; 1f; 0.001; 0.001]`cost} each ix
-1 "vectorized vs scalar on 200 real instants, max abs diff (USDC): direct ",string[max abs sd-cv[`costD] ix],"  indirect ",string max abs si-cv[`costI] ix;

R:raze oneCase ./: key[SCEN] cross SIZES
-1 "Computed ",string[count R]," instant x size x scenario rows";

/ ------------------------------------------------------------
/ 3. Summary table
/ ------------------------------------------------------------
pc:{[x;p] x:asc x where not null x; $[0=count x; 0n; x `long$p*-1+count x]}
summ:0!select instants:count i,
   both:sum status=`both, directOnly:sum status=`directOnly, indirectOnly:sum status=`indirectOnly,
   neither:sum status=`neither,
   noDepthD:sum not depthD, noDepthI:sum not depthI, staleD:sum staleD, staleI:sum staleI,
   medCostD:med costD where status=`both, medCostI:med costI where status=`both,
   shareIndirectCheaper:avg (economie_bps>0) where status=`both,
   medSaveUsdc:med saveUsdc where status=`both,
   bpsP05:pc[economie_bps;0.05], bpsP25:pc[economie_bps;0.25], bpsMed:pc[economie_bps;0.5],
   bpsP75:pc[economie_bps;0.75], bpsP95:pc[economie_bps;0.95], bpsMax:max economie_bps,
   bpsMean:avg economie_bps
  by scenario, size from R
show summ
out["summary.csv"; summ]

/ per-second economie for the charts (F0 and U10 only, to keep the file small)
out["economie_F0_U10.csv"; select t, scenario, size, economie_bps, status from R where scenario in `F0`U10]

/ ------------------------------------------------------------
/ 4. The largest apparent savings, to inspect by hand
/ ------------------------------------------------------------
top:select from R where status=`both, scenario in `F0`U10
top:5 sublist `economie_bps xdesc top
top:top lj `t xkey select t, ageD, ageB, ageU, bestAskD:first each apD, bestAskB:first each apB, usdcBid:abU, usdcAsk:aaU from A
show top
out["top_savings.csv"; top]
-1 "Saved ",RD,"/*.csv";
exit 0
