/ ============================================================
/ analysis/funding_panel.q
/ Builds the variables of the funding study from the 1-second bars:
/   s1 : one row per SECOND of the month (both markets aligned)
/   m1 : one row per MINUTE (aggregated from s1)
/ --
/ Run from the project folder:
/   q analysis/funding_panel.q -sym BTCUSDT -months 2026-08 2026-09 2026-10 -q
/ Needs: data/hdb_1s_<SYM> (src/funding_pipeline.sh)
/ Output: data/funding_<SYM>/s1/ , data/funding_<SYM>/m1
/ --
/ KEY JOINS
/ 1. Prices: aj (as-of join) on a full grid of seconds.
/    For second s, aj takes the LAST bar with bar.sec <= s, i.e. the last
/    trade that happened before the end of second s. Only past data:
/    no look-ahead. Its age = end of second s - time of that trade.
/ 2. Flows: lj (left join) on the exact second. A second with no trade
/    gets NULL flows (not 0): we do not invent a flow. When summing over
/    a minute, nulls are skipped; a minute with no trade at all keeps a
/    volume of 0 (no trade happened) but an imbalance of NULL (undefined).
/ CAVEAT: "price" is the last trade price, not a mid quote and not an
/ executable price. The basis inherits the bid/ask bounce of trades.
/ ============================================================

root:system "cd"
\l src/params.q
system "l ",HDB
/ note: loading the HDB moved us into it; outputs use absolute paths (root,...)
fp:{hsym `$root,"/",x}

/ only the requested months
days:date where (ssr[;".";"-"] each 7#'string date) in MONTHS
-1 "Days in ",HDB,": ",string[count days]," (",string[first days]," to ",string[last days],")";

sec1:0D00:00:01

/ ------------------------------------------------------------
/ One market, one day -> one row per second
/ ------------------------------------------------------------
perSecond:{[d;v]
  g:([] sec:(d+0D)+sec1*til 86400);
  b:select sec, n, buyNotional, sellNotional, maxNotional, close, lastTime
    from bar where date=d, venue=v;
  / seed with the last bar of the previous day, so that the first
  / seconds of the day still have a (stale) price, with its age
  seed:$[(d-1) in days; select sec, n:0N, buyNotional:0n, sellNotional:0n, maxNotional:0n, close, lastTime
                          from bar where date=d-1, venue=v, i=last i; 0#b];
  b:seed,b;
  / (1) price as of the end of each second  -> aj, past data only
  px:aj[`sec; g; select sec, close, lastTime from b];
  px:update age:(sec+sec1)-lastTime from px;
  / (2) flows of that exact second -> lj, nulls when no trade
  px:px lj `sec xkey select sec, n, buyNotional, sellNotional, maxNotional from b where sec>=d+0D;
  / 1-second log return of the carried price, in bp
  update ret:1e4*log close%prev close from px
  }

/ ------------------------------------------------------------
/ One day -> seconds (both markets side by side) and minutes
/ ------------------------------------------------------------
oneDay:{[d]
  s:perSecond[d;`BINANCE_SPOT];
  p:perSecond[d;`BINANCE_PERP];

  / seconds table: what the flow lead-lag analysis needs
  sx:([] sec:s`sec;
          spotNet:(0^s`buyNotional)-0^s`sellNotional;   / no trade -> net flow 0 (nothing traded)
          perpNet:(0^p`buyNotional)-0^p`sellNotional;
          spotRet:s`ret; perpRet:p`ret;
          basisBp:1e4*(p[`close]%s`close)-1;
          ageSpot:s`age; agePerp:p`age);
  fp[FDIR,"/s1/"] upsert sx;

  / minute aggregation, per market
  agg:{[t;pre]
    m:select n:sum n,
             buyN:sum buyNotional, sellN:sum sellNotional,
             maxSize:max maxNotional,
             ret:sum ret,                         / sum of 1 s log returns = minute log return (bp)
             rv:sqrt sum ret*ret,                 / realized volatility over the minute (bp)
             close:last close,
             ageEnd:last age, ageMax:max age
      by minute:0D00:01 xbar sec from t;
    m:update imb:(buyN-sellN)%buyN+sellN, avgSize:(buyN+sellN)%n from m;
    m:update imb:0n from m where 0=buyN+sellN;   / undefined, not zero
    (`minute,`$pre,/:string 1_cols m) xcol 0!m
    };
  m:agg[s;"spot_"] lj `minute xkey agg[p;"perp_"];
  m:update basisBp:1e4*(perp_close%spot_close)-1,
           basisAge:spot_ageEnd|perp_ageEnd     / staleness of the worst of the two prices
    from m;
  / a basis built on a price older than 60 s is not a basis: set it to null
  m:update basisBp:0n from m where basisAge>STALEMAX;
  -1 string[d]," ok";
  m
  }

/ start from empty folders
system "mkdir -p ",root,"/",FDIR;
system "rm -rf ",root,"/",FDIR,"/s1";
m1:raze oneDay each days
fp[FDIR,"/m1"] set m1

/ quick look
show select minutes:count i,
  nullBasis:sum null basisBp,
  medBasisBp:med basisBp,
  p99BasisAgeSec:1e-9*`long$(asc basisAge) `long$0.99*count basisAge,
  maxBasisAgeSec:1e-9*`long$max basisAge,
  minutesNoSpotTrade:sum spot_n=0, minutesNoPerpTrade:sum perp_n=0
  from m1
-1 "Saved ",FDIR,"/m1 and ",FDIR,"/s1/";
