/ ============================================================
/ src/funding.q
/ Loads Binance funding data (one symbol, one or more months) and rebuilds the funding
/ ESTIMATE that was knowable BEFORE each payment.
/ --
/ Usage (from the project folder):
/   q src/funding.q -sym BTCUSDT -months 2026-08 2026-09 2026-10 -q
/ Output: data/funding_<SYM>/funding, data/funding_<SYM>/premium
/         results/funding/<TAG>/funding_estimate_check.csv
/ --
/ Two very different things:
/ 1. the REALIZED rate (last_funding_rate): known only at payment time
/ 2. an ESTIMATE known before payment, rebuilt here from the premium index
/ A study that conditions on (1) is descriptive: you could not have
/ sorted events by it in advance. Only (2) can be used to predict.
/ ============================================================

\l src/params.q
dir:"data/raw/binance/funding/"

/ ------------------------------------------------------------
/ 1. Realized funding (data.binance.vision, futures/um/monthly/fundingRate)
/    calc_time = ms since 1970, a few ms after the scheduled hour
/ ------------------------------------------------------------
f:raze {("JIF";enlist ",") 0: hsym `$dir,"fundingRate/",SYM,"-fundingRate-",x,".csv"} each MONTHS
f:select calcTime:1970.01.01D0+1000000*calc_time,
         intervalH:funding_interval_hours,
         rate:last_funding_rate
  from f
/ scheduled payment time = calcTime rounded down to the hour
f:update payTime:0D01 xbar calcTime from f
f:`payTime xcols f

/ checks: interval always 8 h, payments only at 00/08/16 UTC, 8 h apart
-1 "Funding payments: ",string count f;
-1 "Intervals (h): ",-3!distinct f`intervalH;
-1 "Hours (UTC): ",-3!asc distinct `hh$f`payTime;
-1 "Gaps between payments: ",-3!distinct 1_deltas f`payTime;
-1 "calcTime - payTime (max): ",string max f[`calcTime]-f`payTime;


/ ------------------------------------------------------------
/ 2. Premium index, 1-minute klines (futures/um/monthly/premiumIndexKlines)
/    Binance samples the premium index every 5 s (12 samples per minute).
/    We only have each minute's open/high/low/close, so the minute
/    average is APPROXIMATED by (open+close)/2.
/ ------------------------------------------------------------
p:raze {("JFFFF";enlist ",") 0: hsym `$dir,"premiumIndexKlines/",SYM,"-1m-",x,".csv"} each MONTHS
p:select minute:1970.01.01D0+1000000*open_time, prem:0.5*open+close from p


/ ------------------------------------------------------------
/ 3. Funding estimate knowable at time t, for the payment at T
/ Binance FAQ: over the 8 h interval [T-8h, T), average premium with
/   increasing weights 1,2,...,n (later samples weigh more),
/   F = P + clamp(I - P, -0.05%, +0.05%), I = 0.01% per 8 h,
/   then capped (BTCUSDT and ETHUSDT cap/floor = +/-0.3% from /fapi/v1/fundingInfo).
/ At time t < T, a trader only has the minutes of [T-8h, t).
/ Using the same weights on the partial interval gives an estimate.
/ ------------------------------------------------------------
I:0.0001
clamp:{[lo;hi;x] lo|hi&x}
fundingFrom:{[P] clamp[-0.003;0.003] P + clamp[-0.0005;0.0005] I-P}

/ estimate at time t for payment at T: uses minutes in [T-8h, t)
estimate:{[T;t]
  m:exec prem from p where minute>=T-0D08, minute<t;
  if[0=count m; :0n];
  w:1+til count m;                                   / weights 1..n
  fundingFrom w wavg m
  }

f:update est60:estimate'[payTime; payTime-0D01],    / known 60 min before
         est15:estimate'[payTime; payTime-0D00:15],  / known 15 min before
         estFull:estimate'[payTime; payTime]         / whole interval (= what Binance computes)
  from f

/ how good is the reconstruction?
chk:select n:count i,
  corrFull:rate cor estFull, maeFullBp:1e4*avg abs rate-estFull,
  corr60:rate cor est60,     mae60Bp:1e4*avg abs rate-est60,
  corr15:rate cor est15,     mae15Bp:1e4*avg abs rate-est15,
  sameSign60:avg (signum rate)=signum est60
  from f where not null est60
show chk

/ distribution of the realized rate, in bp
show select n:count i, minBp:1e4*min rate, medBp:1e4*med rate, maxBp:1e4*max rate,
  negative:sum rate<0, atBaseline:sum rate>=0.0000999 from f

/ ------------------------------------------------------------
/ 4. Save
/ ------------------------------------------------------------
system "mkdir -p ",FDIR," ",RDIR;
(hsym `$FDIR,"/funding") set f
(hsym `$FDIR,"/premium") set p
(hsym `$RDIR,"/funding_estimate_check.csv") 0: csv 0: chk
/ funding level per month, in bp
(hsym `$RDIR,"/funding_by_month.csv") 0: csv 0: 0!select n:count i, minBp:1e4*min rate, medBp:1e4*med rate, maxBp:1e4*max rate, negative:sum rate<0, atBaseline:sum rate>=0.0000999 by month:`month$payTime from f
-1 "Saved ",FDIR,"/funding and ",FDIR,"/premium";
