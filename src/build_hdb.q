/ ============================================================
/ src/build_hdb.q
/ Builds the kdb historical database (HDB) from the raw files.
/ --
/ Run from the project folder:
/   q src/build_hdb.q
/ or in VS Code: Cmd+Shift+D on this file.
/ --
/ Result: data/hdb/<date>/trade/  (one folder per day)
/ To add days: download them (bash src/download.sh 2026-11-09 2026-11-10)
/ then add the dates to "days" below and run this file again.
/ ============================================================

\l src/binance.q

/ The days to load: 2026.11.01 + 0 1 2 ... 7  ->  Nov 1 to Nov 8
days:2026.11.01+til 8

/ buildDay[d]: reads the two raw files of day d and writes them to the HDB
buildDay:{[d]
  / Raw file names for that day: BTCUSDT-aggTrades-2026-11-08.csv
  / string d gives "2026.11.08", we replace the dots with dashes
  fname:"BTCUSDT-aggTrades-",ssr[string d;".";"-"],".csv";

  spot:.binance.read[`spot;"data/raw/binance/spot/",fname];
  perp:.binance.read[`perp;"data/raw/binance/perp/",fname];

  / One single table for every market, with two extra columns:
  /   sym   = the instrument, venue = where it trades
  / That way, adding Coinbase or OKX later is just more rows.
  spot:update sym:`BTCUSDT, venue:`BINANCE_SPOT from spot;
  perp:update sym:`BTCUSDT, venue:`BINANCE_PERP from perp;

  / Merge and sort by time.
  / .Q.dpft needs a GLOBAL table, hence `trade set ... (not trade:...)
  `trade set `time`sym`venue`price`qty`side xcols `time xasc spot,perp;

  / Write the day to disk.
  / .Q.dpft = "date, partition, field, table":
  /   it saves the table under data/hdb/<date>/trade/,
  /   grouped by venue so that "where venue=..." is fast.
  .Q.dpft[`:data/hdb; d; `venue; `trade];

  -1 string[d],": ",string[count trade]," trades";
  }

/ Run it for every day
buildDay each days;

/ Check: number of trades per day and venue
\l data/hdb
show select n:count i by date, venue from trade
