/ ============================================================
/ analysis/leadlag.q
/ Lead-lag between Binance BTCUSDT perpetual and spot.
/ Question: which market moves first, and by how much?
/ --
/ Run from the project folder:  q analysis/leadlag.q
/ or in VS Code: Cmd+Shift+D (whole file) / Cmd+D (line by line)
/ Output: results/leadlag_100ms.csv, results/leadlag_10ms.csv
/ ============================================================

/ Remember the project folder: loading the database moves us into data/hdb
root:system "cd"
\l data/hdb

day:2026.11.08


/ ------------------------------------------------------------
/ STEP 1. One price every 100 ms for each market
/ ------------------------------------------------------------

/ The trades of one market, only the columns we need
perp:select time, price from trade where date=day, venue=`BINANCE_PERP
spot:select time, price from trade where date=day, venue=`BINANCE_SPOT

/ A "grid" of times: 00:00:00.0, 00:00:00.1, 00:00:00.2 ... for the whole day
/ 1 day = 864 000 steps of 100 ms
/ 100 ms = 100 000 000 nanoseconds
grid:{[step] ([] time:(day+0D)+step*til `long$1D%step)}

/ Price on the grid = last trade at or before each grid time.
/ This is exactly what aj (as-of join) does.
onGrid:{[step;t] exec price from aj[`time; grid step; t]}

/ Example, 100 ms:
pPerp:onGrid[0D00:00:00.1; perp]
pSpot:onGrid[0D00:00:00.1; spot]
count pPerp                                / 864000
10#pPerp


/ ------------------------------------------------------------
/ STEP 2. Returns = price changes from one step to the next
/ ------------------------------------------------------------

/ log return: log(p_t / p_(t-1)), 0 if no price yet
ret:{0^ log x % prev x}

rPerp:ret pPerp
rSpot:ret pSpot

/ Most 100 ms steps have no price change at all:
avg 0=rPerp                                / share of steps with no move (perp)
avg 0=rSpot                                / same for spot


/ ------------------------------------------------------------
/ STEP 3. Cross-correlation at each lag
/ ------------------------------------------------------------
/ For a lag k (in steps), we compare:
/   the perp return at time t   with   the spot return at time t+k
/ If the correlation is highest for k > 0:
/   the perp moves, and the spot follows k steps later -> PERP LEADS.
/ If highest for k < 0: SPOT LEADS.
/ --
/ xprev shifts a list: (neg k) xprev x  gives  x[t+k]
xcorr:{[a;b;k] cor[a; 0^ neg[k] xprev b]}

/ Everything for one grid step, from -maxlag to +maxlag
leadlag:{[step;maxlag]
  a:ret onGrid[step; perp];
  b:ret onGrid[step; spot];
  lags:neg[maxlag]+til 1+2*maxlag;
  ([] lag:lags; lagms:lags*`long$step%1000000; corr:xcorr[a;b] each lags)
  }

ll100:leadlag[0D00:00:00.1; 20]            / +/- 2 seconds, step 100 ms
ll100

/ Where is the peak?
select from ll100 where corr=max corr

/ Lead-lag ratio (Huth & Abergel): sum of squared corr. for k>0 / for k<0
/ > 1 means perp leads, < 1 means spot leads
llr:{[t] (exec sum corr*corr from t where lag>0) % exec sum corr*corr from t where lag<0}
llr ll100


/ ------------------------------------------------------------
/ STEP 3b. Same thing with a finer grid: 10 ms
/ (closer look at the first few hundred milliseconds)
/ ------------------------------------------------------------

ll10:leadlag[0D00:00:00.01; 50]            / +/- 500 ms, step 10 ms
select from ll10 where corr=max corr
llr ll10


/ ------------------------------------------------------------
/ STEP 4. Save the results for the chart (results/*.csv)
/ ------------------------------------------------------------

save1:{[name;t] (hsym `$root,"/results/",name) 0: csv 0: t}
save1["leadlag_100ms.csv"; ll100]
save1["leadlag_10ms.csv"; ll10]

-1 "Saved results/leadlag_100ms.csv and results/leadlag_10ms.csv";
