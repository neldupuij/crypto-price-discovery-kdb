/ ============================================================
/ analysis/funding_events.q
/ Event study around funding payments (Binance, one symbol), DESCRIPTIVE.
/ --
/ Run from the project folder:
/   q analysis/funding_events.q -sym BTCUSDT -months 2026-08 2026-09 2026-10 -q
/ Needs: data/funding_<SYM>/m1, s1/, funding, premium, quality
/ Output: results/funding/<TAG>/*.csv
/ --
/ Design
/ - EVENT window   : 60 min before -> 60 min after each payment (00/08/16 UTC)
/ - PLACEBO window : the same 2 h window around every OTHER full hour
/                    (01:00, 02:00, ...). It controls for "top of the hour"
/                    and day effects. It cannot remove a pure 00/08/16 UTC
/                    clock effect: those hours are ALWAYS payment hours.
/ - Unit of observation = one window, not one trade. Trades inside a
/   window are strongly dependent, so uncertainty comes from a
/   BOOTSTRAP BY DAY (we resample whole days).
/ - Funding sign/size is used in two ways:
/     realized rate  -> descriptive only (unknown before payment)
/     est60          -> estimate knowable 60 min before (src/funding.q)
/ - Words: we measure flows COMPATIBLE with position unwinding.
/   Public trades cannot tell an opening from a closing.
/ ============================================================

\l src/params.q
system "S ",string SEED                             / reproducible bootstrap
ld:{get hsym `$FDIR,"/",x}
m1:ld "m1"
s1:ld "s1/"
f:ld "funding"
p:ld "premium"

/ keep only the requested months (events, placebos and their data).
/ A window that would need data outside these months is dropped (fixed rule).
inMonths:{(ssr[;".";"-"] each 7#'string `date$x) in MONTHS}
m1:select from m1 where inMonths minute
s1:select from s1 where inMonths sec
f:select from f where inMonths payTime
system "mkdir -p ",RDIR
out:{[name;t] (hsym `$RDIR,"/",name) 0: csv 0: t}

ks:-60+til 120                                       / minute offsets, -60 .. +59
mStart:first m1`minute; mEnd:last m1`minute

/ ------------------------------------------------------------
/ 0. Funding estimate knowable at time t for the payment at T
/    (same formula as src/funding.q)
/ ------------------------------------------------------------
I:0.0001
clamp:{[lo;hi;x] lo|hi&x}
estimate:{[T;t]
  m:exec prem from p where minute>=T-0D08, minute<t;
  $[0=count m; 0n; clamp[-0.003;0.003] P + clamp[-0.0005;0.0005] I-P:(1+til count m) wavg m]}


/ ------------------------------------------------------------
/ 1. Windows: events and placebos
/ ------------------------------------------------------------
hoursAll:mStart+0D01*til 1+`long$(mEnd-mStart)%0D01
inside:{[c] ((c-0D01)>=mStart) & (c+0D00:59)<=mEnd}  / the whole window is in the data

ev:select center:payTime, kind:`event, rate from f where inside payTime
pl:([] center:hoursAll where not (`hh$hoursAll) in 0 8 16; kind:`placebo; rate:0n)
pl:select from pl where inside center

W:ev,pl
/ next payment after (or at) the center, and its estimate 60 min before the center
W:update nextPay:{2000.01.01D0+0D08*ceiling (x-2000.01.01D0)%0D08} each center from W   / next 00/08/16 UTC
W:update est:estimate'[nextPay; center-0D01] from W
W:update id:i, date:`date$center, hour:`hh$center, sgn:signum est from W
/ est is null for placebos at 01/09/17 h (the interval has just started):
/ those windows are kept, they only drop out of the sign-aligned metrics

/ data quality (src/check_klines.q): drop windows containing a minute where our
/ notional differs from Binance klines by more than 10% (e.g. the 27-minute
/ hole in the perp aggTrades file on 2026-10-27 00:03-00:29 UTC)
quality:ld "quality"
severeMin:exec minute from quality where severe
W:update dataIssue:{[c] any severeMin within (c-0D01;c+0D00:59)} each center from W
-1 "Windows dropped for data quality: ",string[exec count i from W where dataIssue, kind=`event]," events, ",
   string[exec count i from W where dataIssue, kind=`placebo]," placebos";
-1 "  event windows dropped: ",-3!exec center from W where dataIssue, kind=`event;
W:select from W where not dataIssue
-1 "Windows: ",string[exec count i from W where kind=`event]," events, ",
   string[exec count i from W where kind=`placebo]," placebos";


/ ------------------------------------------------------------
/ 2. Panel: one row per (window, minute offset k)
/    minute = center + k ; data joined from m1 (lj on the minute)
/ ------------------------------------------------------------
P:([] id:raze (count ks)#/:W`id; k:raze (count W)#enlist ks)
P:update minute:(W`center)[W[`id]?id]+0D00:01*k from P
P:P lj `minute xkey m1
P:P lj `id xkey select id, kind, center, rate, est, sgn, date, hour from W
P:`id`k xasc P
/ basis change since the start of the window, cumulative returns since the start
P:update dBasis:basisBp-first basisBp,
         cumSpot:sums 0^spot_ret, cumPerp:sums 0^perp_ret,
         lvSpot:log 1+spot_buyN+spot_sellN, lvPerp:log 1+perp_buyN+perp_sellN
  by id from P


/ ------------------------------------------------------------
/ 3. One line per window: the numbers we test
/    pre  = the 30 minutes before the payment   (k -30 .. -1)
/    post = the 30 minutes after                 (k   0 .. 29)
/    short versions: 5 minutes                  (k -5..-1 / 0..4)
/ ------------------------------------------------------------
imbw:{[b;s] (sum[b]-sum s)%sum[b]+sum s}             / notional-weighted imbalance
in_:{[k;lo;hi] k within (lo;hi)}

M:select
  dBasisPre:(last basisBp where k<0)-first basisBp,          / -60 min -> payment
  dBasisPost:(last basisBp)-last basisBp where k<0,          / payment -> +60 min
  dBasis10:(first basisBp where k=4)-first basisBp where k=-6, / -5 min -> +5 min
  spotImbPre:imbw[spot_buyN where in_[k;-30;-1]; spot_sellN where in_[k;-30;-1]],
  spotImbPost:imbw[spot_buyN where in_[k;0;29]; spot_sellN where in_[k;0;29]],
  perpImbPre:imbw[perp_buyN where in_[k;-30;-1]; perp_sellN where in_[k;-30;-1]],
  perpImbPost:imbw[perp_buyN where in_[k;0;29]; perp_sellN where in_[k;0;29]],
  perpImbPre5:imbw[perp_buyN where in_[k;-5;-1]; perp_sellN where in_[k;-5;-1]],
  perpImbPost5:imbw[perp_buyN where in_[k;0;4]; perp_sellN where in_[k;0;4]],
  spotVolRatio:log (sum (spot_buyN+spot_sellN) where in_[k;0;29])%sum (spot_buyN+spot_sellN) where in_[k;-30;-1],
  perpVolRatio:log (sum (perp_buyN+perp_sellN) where in_[k;0;29])%sum (perp_buyN+perp_sellN) where in_[k;-30;-1],
  spotRetPre:sum spot_ret where in_[k;-30;-1], spotRetPost:sum spot_ret where in_[k;0;29],
  perpRetPre:sum perp_ret where in_[k;-30;-1], perpRetPost:sum perp_ret where in_[k;0;29],
  rvPerpPre:sqrt sum (perp_rv xexp 2) where in_[k;-30;-1],
  rvPerpPost:sqrt sum (perp_rv xexp 2) where in_[k;0;29],
  maxBasisAgeSec:1e-9*`long$max basisAge
  by id from P
M:(0!M) lj `id xkey select id, kind, center, date, hour, rate, est, sgn from W
M:update spotImbAsym:spotImbPost-spotImbPre, perpImbAsym:perpImbPost-perpImbPre,
         perpImbAsym5:perpImbPost5-perpImbPre5 from M
/ "funding-aligned" versions: multiplied by the sign of the ex-ante estimate.
/ Hypothesis (positive funding, longs pay): perp selling before, buying after,
/ basis falling before and recovering after. Aligned values make positive
/ and negative funding comparable: hypothesis = aligned asymmetry > 0.
M:update aBasisPre:sgn*dBasisPre, aBasisPost:sgn*dBasisPost,
         aPerpImbAsym:sgn*perpImbAsym, aSpotImbAsym:sgn*spotImbAsym,
         aPerpImbAsym5:sgn*perpImbAsym5 from M
out["windows.csv"; M]


/ ------------------------------------------------------------
/ 4. Day bootstrap: event mean - placebo mean, with a 95% interval
/ ------------------------------------------------------------
nrep:NREP
days:asc distinct M`date

/ boot2[col; evMask; plMask]: masks = boolean lists over M saying which events
/ and which placebos to use. Only the days covered by the masks are resampled.
boot2:{[col;evMask;plMask]
  x:M col;
  evMask:evMask & `event=M`kind; plMask:plMask & `placebo=M`kind;
  dd:asc distinct M[`date] where evMask|plMask;
  E:0!select se:sum v, ne:count i by date from ([] date:M`date; v:x; e:evMask) where e, not null v;
  Q:0!select sp:sum v, np:count i by date from ([] date:M`date; v:x; k:plMask) where k, not null v;
  E:([] date:dd) lj `date xkey E; Q:([] date:dd) lj `date xkey Q;
  E:0^E; Q:0^Q;
  stat:{[E;Q;ix] (sum[E[`se] ix]%sum E[`ne] ix)-sum[Q[`sp] ix]%sum Q[`np] ix};
  obs:stat[E;Q;til count dd];
  bs:asc {[E;Q;st;n] st[E;Q;n?n]}[E;Q;stat] each nrep#count dd;
  `diff`lo95`hi95`pTwoSided`nEvents!(obs; bs `long$0.025*nrep; bs `long$0.975*nrep;
     2*min (avg bs<=0; avg bs>=0); sum E`ne)
  }
/ boot[col; evMask]: events selected by evMask against ALL placebos
boot:{[col;evMask] boot2[col;evMask;count[M]#1b]}

/ descriptive stats of one column, by kind
descStats:{[col;mask] t:([] kind:M`kind; v:M col) where mask & not null M col;
  0!select n:count v, mean:avg v, median:med v, sd:dev v,
     q25:{(asc x) `long$0.25*count x} v, q75:{(asc x) `long$0.75*-1+count x} v by kind from t}

metrics:`dBasisPre`dBasisPost`dBasis10`spotImbPre`spotImbPost`perpImbPre`perpImbPost,
        `spotImbAsym`perpImbAsym`perpImbAsym5`spotVolRatio`perpVolRatio,
        `spotRetPre`spotRetPost`perpRetPre`perpRetPost`rvPerpPre`rvPerpPost,
        `aBasisPre`aBasisPost`aPerpImbAsym`aSpotImbAsym`aPerpImbAsym5

all1:count[M]#1b
res:{[c] (enlist[`metric]!enlist c),boot[c;all1]} each metrics
-1 "\nEVENT minus PLACEBO (all events, day bootstrap):";
show res
out["event_vs_placebo.csv"; res]

descr:raze {[c] update metric:c from descStats[c;all1]} each metrics
out["descriptive.csv"; `metric xcols descr]


/ ------------------------------------------------------------
/ 5. Q3: does it depend on the sign / size of funding?
/    by realized sign (descriptive) and by ex-ante estimate terciles
/ ------------------------------------------------------------
isEv:`event=M`kind
r:M`rate; e:M`est
/ terciles FIXED on the exploratory sample (BTCUSDT 2026-10), see src/params.q
t1:EST_T1
t2:EST_T2
groups:(`realizedNeg`realizedPos`estLow`estMid`estHigh)!(isEv&r<0; isEv&r>=0; isEv&e<t1; isEv&(e>=t1)&e<t2; isEv&e>=t2)
-1 "\nEstimate terciles (bp): ",string[1e4*t1]," / ",string 1e4*t2;
key3:`dBasisPre`dBasisPost`perpImbAsym`spotImbAsym`perpImbAsym5`perpRetPost`spotRetPost
row3:{[g;c] (`group`metric!(g;c)),boot[c;groups g]}
byGroup:row3 ./: key[groups] cross key3
-1 "\nBy funding group (event - placebo):";
show byGroup
out["by_funding_group.csv"; byGroup]


/ ------------------------------------------------------------
/ 6. Q5: persistence - by payment hour and by week
/ ------------------------------------------------------------
week:{1+(x-first days) div 7}                        / week number since the first day
pers:select n:count i,
  dBasisPre:avg dBasisPre, dBasisPost:avg dBasisPost,
  perpImbAsym:avg perpImbAsym, spotImbAsym:avg spotImbAsym,
  aPerpImbAsym:avg aPerpImbAsym
  by kind, grp:(`$"h",/:string hour) from M where kind=`event
plw:select n:count i, dBasisPre:avg dBasisPre, dBasisPost:avg dBasisPost,
  perpImbAsym:avg perpImbAsym, spotImbAsym:avg spotImbAsym, aPerpImbAsym:avg aPerpImbAsym
  by kind, grp:(`$"w",/:string week date) from M
-1 "\nBy payment hour (events only):"; show pers
-1 "\nBy week (events and placebos):"; show plw
out["persistence_hour.csv"; 0!pers]

/ hour-of-day control: the same numbers for EVERY hour of the day
/ (events at 00/08/16, placebos elsewhere). If 00:00 looks like 23:00
/ or 01:00, the effect is a clock effect, not a funding effect.
/ se = standard error from a day bootstrap of the hourly mean
seDay:{[h;col]
  v:M col; m:(h=M`hour) & not null v;
  bd:value exec v by date from ([] date:M[`date] where m; v:v where m);   / one list of values per day
  n:count bd;
  dev {[bd;n;x] avg raze bd n?n}[bd;n] each til 500}
allH:0!select n:count i, isPayment:first kind=`event, dBasisPost:avg dBasisPost, dBasis10:avg dBasis10,
  perpImbAsym:avg perpImbAsym, perpVolRatio:avg perpVolRatio by hour from M
allH:update seBasisPost:seDay[;`dBasisPost] each hour, seBasis10:seDay[;`dBasis10] each hour from allH
-1 "\nAll hours of the day:"; show allH
out["by_hour_all.csv"; allH]
out["persistence_week.csv"; 0!plw]

/ by MONTH: event - placebo of the same month, day bootstrap within the month
M:update month:`month$date from M
keyM:`dBasisPre`dBasisPost`dBasis10`perpImbAsym`spotImbAsym`aPerpImbAsym`perpVolRatio`rvPerpPost
rowM:{[m;c] mm:m=M`month; (`month`metric!(m;c)),boot2[c;mm;mm]}
byMonth:rowM ./: (asc distinct M`month) cross keyM
-1 "\nBy month (event - placebo of the same month):"; show byMonth
out["by_month.csv"; byMonth]


/ ------------------------------------------------------------
/ 7. Profiles for the charts: mean / median / quartiles at each minute k
/ ------------------------------------------------------------
q:{[x;pc] x:asc x where not null x; $[0=count x; 0n; x `long$pc*-1+count x]}
prof:{[mask;g]
  t:select from P where id in (exec id from M where mask);
  0!select n:count i,
    dBasisMean:avg dBasis, dBasisMed:med dBasis, dBasisQ25:q[dBasis;0.25], dBasisQ75:q[dBasis;0.75],
    perpImb:imbw[perp_buyN;perp_sellN], spotImb:imbw[spot_buyN;spot_sellN],
    lvPerp:avg lvPerp, lvSpot:avg lvSpot,
    cumPerp:avg cumPerp, cumSpot:avg cumSpot,
    basisAgeP99:1e-9*`long$q[basisAge;0.99]
    by grp:g, k from t}
isPl:`placebo=M`kind
profiles:raze (prof[isEv;`event]; prof[isPl;`placebo];
  prof[isEv & (M`est)>0; `eventEstPos]; prof[isEv & (M`est)<=0; `eventEstNeg])
out["profiles.csv"; profiles]


/ ------------------------------------------------------------
/ 8. Q4: do perp flows lead spot flows? (1-second data, +/- 10 min)
/    For each window: corr(perp net flow at t, spot net flow at t+L)
/    L in seconds. L>0 large -> perp flow comes first.
/ ------------------------------------------------------------
lags:-10+til 21
xc:{[a;b;L] cor[a; 0^ neg[L] xprev b]}
llr:{[c] (sum c[where lags>0] xexp 2) % sum c[where lags<0] xexp 2}
secs:s1`sec
win1s:{[c] i0:secs bin c-0D00:10; i0+til 1200}
flowLL:{[c] ix:win1s c; xc[s1[`perpNet] ix; s1[`spotNet] ix] each lags}
retLL:{[c] ix:win1s c; xc[0^s1[`perpRet] ix; 0^s1[`spotRet] ix] each lags}
ffE:flowLL each exec center from M where kind=`event
ffP:flowLL each exec center from M where kind=`placebo
rrE:retLL each exec center from M where kind=`event
rrP:retLL each exec center from M where kind=`placebo
ll:([] lag:lags; flowEvent:avg ffE; flowPlacebo:avg ffP; retEvent:avg rrE; retPlacebo:avg rrP)
-1 "\nFlow lead-lag ratio, events: ",string[llr ll`flowEvent],"  placebos: ",string llr ll`flowPlacebo;
-1 "Return lead-lag ratio, events: ",string[llr ll`retEvent],"  placebos: ",string llr ll`retPlacebo;
out["leadlag_flows.csv"; ll]

-1 "\nSaved ",RDIR,"/*.csv";
