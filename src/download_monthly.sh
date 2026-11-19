#!/bin/bash
# ============================================================
# src/download_monthly.sh
# Small monthly files needed by the funding study, from data.binance.vision:
#   fundingRate            -> data/raw/binance/funding/fundingRate/
#   premiumIndexKlines 1m  -> data/raw/binance/funding/premiumIndexKlines/
#   perp klines 1m         -> data/raw/binance/funding/perpKlines/
#   spot klines 1m         -> data/raw/binance/funding/spotKlines/
# Each zip is checked against its published SHA-256.
#
# Usage (from the project folder):
#   bash src/download_monthly.sh ETHUSDT 2026-08 2026-09 2026-10
# ============================================================
set -euo pipefail

SYM=${1:?symbol}; shift
BASE=https://data.binance.vision/data
DIR=data/raw/binance/funding
mkdir -p "$DIR"

for M in "$@"; do
  # name | remote path | csv name inside the zip
  for spec in \
    "fundingRate|futures/um/monthly/fundingRate/$SYM/$SYM-fundingRate-$M.zip|$SYM-fundingRate-$M.csv" \
    "premiumIndexKlines|futures/um/monthly/premiumIndexKlines/$SYM/1m/$SYM-1m-$M.zip|$SYM-1m-$M.csv" \
    "perpKlines|futures/um/monthly/klines/$SYM/1m/$SYM-1m-$M.zip|$SYM-1m-$M.csv" \
    "spotKlines|spot/monthly/klines/$SYM/1m/$SYM-1m-$M.zip|$SYM-1m-$M.csv"; do
    IFS='|' read -r name rel csv <<< "$spec"
    if [[ -f "$DIR/$name/$csv" ]]; then echo "$name $SYM $M: already there"; continue; fi
    zip="$name-${rel##*/}"
    curl -sf -o "$DIR/$zip" "$BASE/$rel"
    curl -sf -o "$DIR/$zip.CHECKSUM" "$BASE/$rel.CHECKSUM"
    (cd "$DIR" && sed "s/  ${rel##*/}/  $zip/" "$zip.CHECKSUM" | shasum -a 256 -c - >/dev/null && unzip -o -q "$zip" -d "$name")
    echo "$name $SYM $M: ok"
  done
done
