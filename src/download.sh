#!/bin/bash
# ============================================================
# src/download.sh
# Downloads Binance BTCUSDT aggTrades (spot + USD-M perpetual)
# from data.binance.vision, checks the SHA-256 and unzips.
#
# Usage (from the project folder):
#   bash src/download.sh 2026-11-01 2026-11-07 [SYMBOL, default BTCUSDT]
# Files go to data/raw/binance/{spot,perp}/
# ============================================================
set -euo pipefail

START=${1:?start date YYYY-MM-DD}
END=${2:-$START}
SYM=${3:-BTCUSDT}
BASE=https://data.binance.vision/data
RAW=data/raw/binance

# where each market lives on data.binance.vision
url_path() {
  case $1 in
    spot) echo "spot/daily/aggTrades/$SYM" ;;
    perp) echo "futures/um/daily/aggTrades/$SYM" ;;
  esac
}

d=$START
while [[ "$d" < "$END" || "$d" == "$END" ]]; do
  for m in spot perp; do
    f="$SYM-aggTrades-$d.zip"
    dir="$RAW/$m"
    mkdir -p "$dir"
    if [[ -f "$dir/${f%.zip}.csv" ]]; then
      echo "$m $d: already there"
      continue
    fi
    curl -sf -o "$dir/$f" "$BASE/$(url_path $m)/$f"
    curl -sf -o "$dir/$f.CHECKSUM" "$BASE/$(url_path $m)/$f.CHECKSUM"
    (cd "$dir" && shasum -a 256 -c "$f.CHECKSUM" >/dev/null && unzip -o -q "$f")
    echo "$m $d: ok"
  done
  d=$(date -j -v+1d -f %Y-%m-%d "$d" +%Y-%m-%d)
done
