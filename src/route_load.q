/ ============================================================
/ src/route_load.q
/ Loads one Tardis book_snapshot_25 file (Binance spot) into a q table:
/   lt : local_timestamp = arrival time at Tardis (what we "know" at t)
/   et : exchange timestamp
/   ap, aq : ask prices / amounts, 25 levels, ASCENDING price (best first)
/   bp, bq : bid prices / amounts, 25 levels, DESCENDING price (best first)
/ Amounts are in the BASE asset (BTC for BTCUSDC/BTCUSDT, USDC for USDCUSDT).
/ --
/ Usage (from the project folder):
/   q src/route_load.q -date 2026-11-01 -sym BTCUSDC -q
/ Output: data/routing/<date>/<SYM> (q binary file). The temporary .csv is deleted.
/ ============================================================

opt:.Q.opt .z.x
DAY:first opt`date; SYM:first opt`sym
gz:"data/raw/tardis/binance/book_snapshot_25/",DAY,"/",SYM,".csv.gz"
tmp:"data/raw/tardis/binance/book_snapshot_25/",DAY,"/",SYM,".tmp.csv"

/ decompress to a temporary csv. Wrapped in sh -c: q's system captures stdout
/ itself, so a bare "> file" redirection would not write the file.
system "sh -c 'gzcat ",gz," > ",tmp,"'"

/ column layout: exchange, symbol, timestamp, local_timestamp,
/ then for each level i = 0..24: asks[i].price, asks[i].amount, bids[i].price, bids[i].amount
types:"  JJ",raze 25#enlist "FFFF"
c:(types;enlist ",") 0: hsym `$tmp                    / one column per field (header used)
system "rm -f ",tmp

n:25
/ col[c;"asks";"price"] -> one list of 25 values per row, level 0 first
/ (column names like asks[3].price are built for i = 0..24)
col:{[c;side;fld] flip c `$((side,"["),/:string til 25),\:("].",fld)}
t:([] lt:1970.01.01D0+1000*c`local_timestamp;
      et:1970.01.01D0+1000*c`timestamp;
      ap:col[c;"asks";"price"]; aq:col[c;"asks";"amount"];
      bp:col[c;"bids";"price"]; bq:col[c;"bids";"amount"])
delete c from `.;

/ checks: sorted by arrival time, asks ascending, bids descending, no crossed book
chk:enlist `sym`rows`firstLt`lastLt`sortedLt`asksAscending`bidsDescending`crossed`nullOrZero`maxGapSec!(
  `$SYM; count t; first t`lt; last t`lt;
  all 0<=1_deltas t`lt;
  all {all 0<1_deltas x} each t`ap;
  all {all 0>1_deltas x} each t`bp;
  sum (first each t`bp)>=first each t`ap;
  sum {any (null x) or x<=0} each t[`aq],'t`bq;
  1e-9*`long$max 1_deltas t`lt)
show chk

system "mkdir -p data/routing/",DAY
(hsym `$"data/routing/",DAY,"/",SYM) set t
af:hsym `$"data/routing/",DAY,"/load_checks.csv"
$[()~key af; af 0: csv 0: chk; af 0: read0[af],1_csv 0: chk]
-1 "Saved data/routing/",DAY,"/",SYM," (",string[count t]," snapshots)";
exit 0
