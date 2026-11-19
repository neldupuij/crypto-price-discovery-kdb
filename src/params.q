/ ============================================================
/ src/params.q
/ Command-line options shared by the funding-study scripts.
/ --
/   q analysis/funding_events.q -sym ETHUSDT -months 2026-08 2026-09 2026-10 -q
/ Defaults: -sym BTCUSDT -months 2026-10
/ --
/ Folders (one set per symbol):
/   data/hdb_1s_<SYM>/        1-second bars (partitioned by date)
/   data/funding_<SYM>/       funding, premium, m1, s1, quality tables
/   results/funding/<TAG>/    csv results, TAG = <SYM>_<first month>[_<last month MM>]
/ ============================================================

opt:.Q.opt .z.x
SYM:$[`sym in key opt; first opt`sym; "BTCUSDT"]
MONTHS:$[`months in key opt; opt`months; enlist "2026-10"]
HDB:"data/hdb_1s_",SYM
FDIR:"data/funding_",SYM
TAG:SYM,"_",first[MONTHS],$[1<count MONTHS; "_",-2#last MONTHS; ""]
RDIR:"results/funding/",TAG
/ ------------------------------------------------------------
/ FROZEN ANALYSIS CHOICES (pre-registration, docs/funding_preregistration.md)
/ Fixed on the exploratory sample BTCUSDT 2026-10 and NOT changed afterwards.
/ ------------------------------------------------------------
QMAXGAP:0.1              / data quality: a minute is "severe" if our notional differs from klines by > 10%
STALEMAX:0D00:01         / a basis built on a price older than 60 s is set to null
EST_T1:2.5824645062775739e-05   / funding-estimate terciles (rate per 8 h), taken from the 87
EST_T2:6.892264596765075e-05    / BTCUSDT 2026-10 payment windows, applied unchanged everywhere
NREP:2000                / day-bootstrap replications
SEED:42                  / random seed

-1 "params: sym=",SYM,"  months=",(", " sv MONTHS),"  hdb=",HDB,"  results=",RDIR;
