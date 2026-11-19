/ ============================================================
/ analysis/multiday.q
/ Same lead-lag + event study as before, but on EVERY day of the HDB.
/ Question: is "the perpetual leads the spot" true every day,
/ or was Nov 8 a lucky day?
/ --
/ Run from the project folder:  q analysis/multiday.q
/ Output:
/   results/multiday_summary.csv   one line per day
/   results/multiday_events.csv    event study pooled over all days
/ ============================================================

root:system "cd"
\l data/hdb


/ ------------------------------------------------------------
/ Tools (same ideas as leadlag.q and event_study.q,
/ but every function now takes the day as a parameter)
/ ------------------------------------------------------------

/ prices of one venue on a grid of `step`, for day d
onGrid:{[d;step;v]
  g:([] time:(d+0D)+step*til `long$1D%step);
  exec price from aj[`time; g; select time, price from trade where date=d, venue=v]
  }

bps:{0^ 1e4*log x % prev x}                         / returns in basis points

/ cross-correlation at lag k: perp at t vs spot at t+k
xcorr:{[a;b;k] cor[a; 0^ neg[k] xprev b]}

/ lead-lag ratio from a list of lags and their correlations
llr:{[lags;c] (sum c[where lags>0] xexp 2) % sum c[where lags<0] xexp 2}

/ events: jumps above `threshold` bp, at least `gap` steps apart
threshold:3
gap:100
spaced:{[idx] $[0=count idx; idx; {[kept;i] $[(i-last kept)>=gap; kept,i; kept]}/[enlist first idx; 1_idx]]}
jumps:{[r] spaced where threshold<abs r}

ks:-20+til 121                                       / -200 ms .. +1 s (10 ms steps)
path:{[p;ev;s] s * 1e4 * -1 + p[ev +\: ks] % p ev-1}


/ ------------------------------------------------------------
/ Everything for one day
/ ------------------------------------------------------------
oneDay:{[d]
  / 100 ms grid
  a:bps onGrid[d;0D00:00:00.1;`BINANCE_PERP];
  b:bps onGrid[d;0D00:00:00.1;`BINANCE_SPOT];
  l100:-20+til 41;  c100:xcorr[a;b] each l100;

  / 10 ms grid
  pp:onGrid[d;0D00:00:00.01;`BINANCE_PERP];
  ps:onGrid[d;0D00:00:00.01;`BINANCE_SPOT];
  rp:bps pp; rs:bps ps;
  l10:-50+til 101;  c10:xcorr[rp;rs] each l10;

  / events (drop those too close to the start/end of the day)
  keep:{[ev;n] ev where (ev>20) & ev<n-100};
  eP:keep[jumps rp; count rp];  sP:signum rp eP;
  eS:keep[jumps rs; count rs];  sS:signum rs eS;

  / paths: one row per event (kept for the pooled average)
  `pathsPerpJ upsert flip `date`perp`spot!(count[eP]#d; path[pp;eP;sP]; path[ps;eP;sP]);
  `pathsSpotJ upsert flip `date`perp`spot!(count[eS]#d; path[pp;eS;sS]; path[ps;eS;sS]);

  -1 string[d]," done";
  `date`corrM100`corr0_100`corrP100`llr100`corrM10`corr0_10`corrP10`llr10`nPerpJumps`nSpotJumps!(
    d;
    c100 l100?-1; c100 l100?0; c100 l100?1; llr[l100;c100];
    c10 l10?-1;  c10 l10?0;  c10 l10?1;  llr[l10;c10];
    count eP; count eS)
  }

/ empty tables that oneDay fills with one row per event
pathsPerpJ:([] date:`date$(); perp:(); spot:())
pathsSpotJ:([] date:`date$(); perp:(); spot:())

summary:oneDay each date
summary


/ ------------------------------------------------------------
/ Event study pooled over all days, and per-day pre-moves
/ ------------------------------------------------------------

/ average path over ALL events of all days
pooled:{[t] ([] lagms:10*ks; perp:avg t`perp; spot:avg t`spot)}
evPerp:pooled pathsPerpJ
evSpot:pooled pathsSpotJ

/ per day: how much the OTHER market moved in the 200 ms BEFORE the jump
/ (first column of the path = -200 ms; minus sign: move from -200 ms to -10 ms)
pre:select spotPreBeforePerpJump:neg avg first each spot by date from pathsPerpJ
pre:pre lj select perpPreBeforeSpotJump:neg avg first each perp by date from pathsSpotJ
summary:summary lj pre
summary

/ the headline numbers, all days together
-1 "";
-1 "Days: ",string count summary;
-1 "Lead-lag ratio (100 ms): min ",string[min summary`llr100],", median ",string[med summary`llr100],", max ",string max summary`llr100;
-1 "Days where perp leads (ratio > 1): ",string[sum 1<summary`llr100]," / ",string count summary;
-1 "Events: ",string[count pathsPerpJ]," perp jumps, ",string[count pathsSpotJ]," spot jumps";
-1 "Perp move in the 200 ms before a spot jump (all days): ",string[neg first evSpot`perp]," bp";
-1 "Spot move in the 200 ms before a perp jump (all days): ",string[neg first evPerp`spot]," bp";


/ ------------------------------------------------------------
/ Save
/ ------------------------------------------------------------
save1:{[name;t] (hsym `$root,"/results/",name) 0: csv 0: t}
save1["multiday_summary.csv"; summary]
save1["multiday_events_perp_jumps.csv"; evPerp]
save1["multiday_events_spot_jumps.csv"; evSpot]
-1 "Saved results/multiday_*.csv";
