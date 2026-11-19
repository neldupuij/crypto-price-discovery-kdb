/ ============================================================
/ analysis/funding_check_events.q
/ Looks at a FEW individual funding payments by hand, before
/ trusting the averages, and cross-checks the minute panel (m1)
/ against the raw 1-second bars (data/hdb_1s).
/ --
/ Run from the project folder:
/   q analysis/funding_check_events.q -sym BTCUSDT -months 2026-08 2026-09 2026-10 -q
/ Output: results/funding/<TAG>/check_events.csv
/ ============================================================

root:system "cd"
\l src/params.q
m1:get hsym `$FDIR,"/m1"
f:get hsym `$FDIR,"/funding"
system "l ",HDB

/ three payments: the most negative, the median and the most positive realized rate
f:`rate xasc select from f where payTime>first m1`minute
picks:f (0; `long$0.5*count f; -1+count f)
show select payTime, rateBp:1e4*rate, est60Bp:1e4*est60 from picks

/ 1. minute view around each payment (k = -10 .. +9)
vw:{[T]
  t:select minute, k:`long$(minute-T)%0D00:01, basisBp, basisAgeS:1e-9*`long$basisAge,
      perpNotional:perp_buyN+perp_sellN, perpImb:perp_imb,
      spotNotional:spot_buyN+spot_sellN, spotImb:spot_imb,
      perpRet:perp_ret, spotRet:spot_ret
    from m1 where minute within (T-0D00:10; T+0D00:09);
  update payTime:T from t}
v:raze vw each picks`payTime
show v
(hsym `$root,"/",RDIR,"/check_events.csv") 0: csv 0: v

/ 2. cross-check: perp buy/sell notional of the minute BEFORE each payment,
/    recomputed directly from the 1 s bars, must equal m1
chk:{[T]
  d:`date$T-0D00:01;
  / (on a partitioned table, use select then take the values)
  raw:first select buyNotional:sum buyNotional, sellNotional:sum sellNotional from bar
      where date=d, venue=`BINANCE_PERP, sec within (T-0D00:01; T-0D00:00:01);
  pan:exec first perp_buyN, first perp_sellN from m1 where minute=T-0D00:01;
  `payTime`rawBuy`panelBuy`rawSell`panelSell!(T;raw`buyNotional;pan`perp_buyN;raw`sellNotional;pan`perp_sellN)}
show chk each picks`payTime

/ 3. cross-check of the basis at the payment time: last trade prices from the bars
bchk:{[T]
  s:last exec close from select close from bar where date within (`date$T-0D01;`date$T), venue=`BINANCE_SPOT, sec<T;
  p:last exec close from select close from bar where date within (`date$T-0D01;`date$T), venue=`BINANCE_PERP, sec<T;
  `payTime`spot`perp`basisRawBp`basisPanelBp!(T;s;p;1e4*(p%s)-1; exec first basisBp from m1 where minute=T-0D00:01)}
show bchk each picks`payTime
