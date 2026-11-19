/ ============================================================
/ src/build_bars.q
/ Turns ONE day of raw Binance aggTrades (spot + perp) into
/ 1-second bars, and writes them to a separate database: data/hdb_1s_<SYM>
/ --
/ Usage (from the project folder):
/   q src/build_bars.q -date 2026.10.01 -sym BTCUSDT -q
/ Normally called by src/funding_pipeline.sh, one day at a time,
/ so that only one day of raw trades is ever in memory.
/ --
/ IMPORTANT
/ - A bar exists only for seconds WITH at least one trade.
/   A second without trades has NO row: we never invent a flow of 0
/   from missing data. Prices are carried forward later, with their age.
/ - "price" = last trade price. It is NOT a mid quote and NOT an
/   executable price (no order book data here).
/ - Binance aggTrades: one row = fills of one taker order at one price.
/   "n" therefore counts aggregated trades, not individual fills.
/ - Side: is_buyer_maker = true -> the seller was the taker (aggressor).
/ ============================================================

\l src/binance.q
\l src/params.q

d:"D"$first opt`date                                 / the day, from the command line
if[null d; -2 "usage: q src/build_bars.q -date 2026.10.01 -sym BTCUSDT"; exit 1];

fname:SYM,"-aggTrades-",ssr[string d;".";"-"],".csv"

/ bars1s[t; v]: 1-second bars for one market
/ xbar 0D00:00:01 rounds each timestamp DOWN to its second
bars1s:{[t;v]
  t:update notional:price*qty from t;               / USDT notional, same unit on spot and perp
  b:select n:count i,
           nBuy:sum side=`buy,
           buyQty:sum qty*side=`buy,
           sellQty:sum qty*side=`sell,
           buyNotional:sum notional*side=`buy,
           sellNotional:sum notional*side=`sell,
           maxNotional:max notional,
           open:first price, high:max price, low:min price, close:last price,
           lastTime:last time                        / exact time of the last trade of that second
    by sec:0D00:00:01 xbar time from t;
  update venue:v from 0!b
  }

spot:.binance.read[`spot;"data/raw/binance/spot/",fname]
perp:.binance.read[`perp;"data/raw/binance/perp/",fname]

/ sanity checks on the raw day (printed, and stored in an audit table)
audit:([] date:2#d; venue:`BINANCE_SPOT`BINANCE_PERP;
  nTrades:count each (spot;perp);
  firstTime:first each (spot`time;perp`time);
  lastTime:last each (spot`time;perp`time);
  sorted:{all 0<=1_deltas x} each (spot`time;perp`time);
  nullPrice:{sum null x} each (spot`price;perp`price);
  outsideDay:{sum not d=`date$x} each (spot`time;perp`time))

`bar set `sec xasc (bars1s[spot;`BINANCE_SPOT]),bars1s[perp;`BINANCE_PERP]
delete spot, perp from `.;                            / free the raw trades

/ write the day: data/hdb_1s_<SYM>/<date>/bar/ , grouped by venue
.Q.dpft[hsym `$HDB; d; `venue; `bar]

/ append the audit line to a small csv
af:hsym `$HDB,"_audit.csv"
$[()~key af; af 0: csv 0: audit; af 0: read0[af],1_csv 0: audit]

show audit
-1 string[d],": ",string[count bar]," bars written";
exit 0
