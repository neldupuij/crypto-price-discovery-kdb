#!/bin/bash
# ============================================================
# src/funding_pipeline.sh
# Downloads and processes Binance aggTrades ONE DAY AT A TIME
# (spot + USD-M perp) into 1-second bars (data/hdb_1s_<SYM>), then deletes
# the large unzipped CSVs to save disk. With DELETE_ZIPS=1 the zips are
# deleted too (the .CHECKSUM files are kept as a record).
#
# Usage (from the project folder):
#   bash src/funding_pipeline.sh 2026-10-01 2026-10-31 [SYMBOL]
#   DELETE_ZIPS=1 bash src/funding_pipeline.sh 2026-08-01 2026-08-31 ETHUSDT
# Days already present in data/hdb_1s_<SYM> are skipped.
# ============================================================
set -euo pipefail

START=${1:?start date YYYY-MM-DD}
END=${2:-$START}
SYM=${3:-BTCUSDT}
Q=~/.kx/bin/q

d=$START
while [[ "$d" < "$END" || "$d" == "$END" ]]; do
  qd=${d//-/.}
  if [[ -d "data/hdb_1s_$SYM/$qd" ]]; then
    echo "$d: already processed"
  else
    bash src/download.sh "$d" "$d" "$SYM"
    $Q src/build_bars.q -date "$qd" -sym "$SYM" -q
    for m in spot perp; do
      rm -f "data/raw/binance/$m/$SYM-aggTrades-$d.csv"
      if [[ "${DELETE_ZIPS:-0}" == "1" ]]; then rm -f "data/raw/binance/$m/$SYM-aggTrades-$d.zip"; fi
    done
  fi
  d=$(date -j -v+1d -f %Y-%m-%d "$d" +%Y-%m-%d)
done
