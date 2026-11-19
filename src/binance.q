/ ============================================================
/ src/binance.q
/ Reads Binance "aggTrades" CSV files (data.binance.vision)
/ and turns them into a clean q table.
/ --
/ The spot and perpetual (USD-M) files differ:
/   - spot: no header, times in MICROseconds, 8 columns
/   - perp: header,    times in MILLIseconds, 7 columns
/ This file hides those differences.
/ ============================================================

/ All functions live in the .binance namespace (like a Python module)

/ Column types to read, one letter per column:
/   J = long (integer), F = float, S = symbol, space = skip the column
/ We keep: id, price, quantity, time, is_buyer_maker
/ We skip: first_trade_id, last_trade_id (and isBestMatch for spot)
.binance.types:`spot`perp!("JFF  JS ";"JFF  JS")

/ .binance.read[market; file]
/   market : `spot or `perp
/   file   : file path (string)
/ Returns a table: time, price, qty, side
.binance.read:{[market;file]
  / 1. read the CSV as a list of columns (no header)
  c:(.binance.types market;",") 0: hsym `$file;

  / 2. name the columns
  t:flip `id`price`qty`ts`buyerMaker!c;

  / 3. drop the header line (on the perp file it reads as an empty id)
  t:select from t where not null id;

  / 4. convert the time: Binance counts from 1970, q timestamps are in nanoseconds
  /    spot = microseconds (x1000), perp = milliseconds (x1000000)
  mult:$[market=`spot;1000;1000000];

  / 5. side of the aggressor (the one who crossed the spread):
  /    buyer is maker -> the seller was aggressive -> `sell
  select time:1970.01.01D0+mult*ts,
         price,
         qty,
         side:?[(lower buyerMaker)=`true;`sell;`buy]
    from t
  }
