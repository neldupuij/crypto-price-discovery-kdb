/ ============================================================
/ src/check_klines.q
/ Data-quality check: compares OUR minute flows (built from aggTrades)
/ with Binance's own 1-minute klines (independent dataset).
/ klines give quote_volume (USDT) and taker_buy_quote_volume, i.e.
/ exactly our buy+sell notional and our aggressive-buy notional.
/ --
/ Run from the project folder (after analysis/funding_panel.q):
/   q src/check_klines.q -sym BTCUSDT -months 2026-08 2026-09 2026-10 -q
/ Output: data/funding_<SYM>/quality (one row per minute, flags),
/         results/funding/<TAG>/data_quality.csv (summary)
/ ============================================================

\l src/params.q
dir:"data/raw/binance/funding/"
m1:get hsym `$FDIR,"/m1"

/ perp klines: times in ms ; spot klines: times in MICROseconds (since 2025)
/ the perp file has a header line, the spot file does not: read without
/ header, name the columns, drop the header row if there was one
kcols:`open_time`open`high`low`close`volume`close_time`quote_volume`count`taker_buy_volume`taker_buy_quote_volume`ignore
rd:{[file;mult]
  k:flip kcols!("JFFFFFJFJFFF";",") 0: hsym `$dir,file;
  k:select from k where not null open_time;
  select minute:1970.01.01D0+mult*open_time, kTrades:count, kQuote:quote_volume, kBuyQuote:taker_buy_quote_volume from k}
kp:raze {rd["perpKlines/",SYM,"-1m-",x,".csv";1000000]} each MONTHS
ks:raze {rd["spotKlines/",SYM,"-1m-",x,".csv";1000]} each MONTHS

/ relative gap between our total notional and the klines'
cmp:{[k;pre]
  b:m1 `$pre,"buyN"; s:m1 `$pre,"sellN";
  t:k lj `minute xkey ([] minute:m1`minute; ours:b+s; oursBuy:b);
  update relGap:(ours-kQuote)%kQuote, relGapBuy:(oursBuy-kBuyQuote)%kBuyQuote from t}
qp:cmp[kp;"perp_"]
qs:cmp[ks;"spot_"]

/ a minute is "bad" if our notional differs from the klines by more than 1%
bad:{[t] select from t where 0.01<abs relGap}
-1 "Perp minutes with >1% notional gap: ",string count bad qp;
-1 "Spot minutes with >1% notional gap: ",string count bad qs;
show select n:count i, first minute, last minute by date:`date$minute from bad qp
show select n:count i, first minute, last minute by date:`date$minute from bad qs

/ per-minute relative gaps; a window is excluded later if any of its
/ minutes has a gap above 10% (src: analysis/funding_events.q)
quality:([] minute:qp`minute; perpGap:qp`relGap; spotGap:(qs`relGap) qs[`minute]?qp`minute)
quality:update perpBad:0.01<abs perpGap, spotBad:0.01<abs spotGap, severe:(QMAXGAP<abs perpGap)|QMAXGAP<abs spotGap from quality
(hsym `$FDIR,"/quality") set quality

summary:([] market:`perp`spot;
  minutes:count each (qp;qs);
  badMinutes:count each (bad qp; bad qs);
  medianAbsGap:{med abs x`relGap} each (qp;qs);
  medianAbsGapBuy:{med abs x`relGapBuy} each (qp;qs);
  totalOursUSDbn:1e-9*{sum x`ours} each (qp;qs);
  totalKlinesUSDbn:1e-9*{sum x`kQuote} each (qp;qs))
show summary
system "mkdir -p ",RDIR
(hsym `$RDIR,"/data_quality.csv") 0: csv 0: summary
/ every severe minute (gap > 10%), for the data note
(hsym `$RDIR,"/severe_minutes.csv") 0: csv 0: select from quality where severe
