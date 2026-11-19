#!/bin/bash
# ============================================================
# src/tardis_download.sh
# Downloads one free Tardis.dev daily CSV (first day of each month needs no API key),
# checks the MD5 published by Tardis (x-md5 header), and writes a metadata file.
#
# Usage (from the project folder):
#   bash src/tardis_download.sh binance book_snapshot_25 2026-11-01 USDCUSDT
# Output: data/raw/tardis/<exchange>/<type>/<date>/<SYMBOL>.csv.gz  (+ .meta.json)
# Existing files are never overwritten.
# ============================================================
set -euo pipefail

EX=${1:?exchange}; TYPE=${2:?data type}; DAY=${3:?YYYY-MM-DD}; SYM=${4:?symbol}
URL="https://datasets.tardis.dev/v1/$EX/$TYPE/${DAY//-//}/$SYM.csv.gz"
DIR="data/raw/tardis/$EX/$TYPE/$DAY"
OUT="$DIR/$SYM.csv.gz"
mkdir -p "$DIR"

if [[ -f "$OUT" && -f "$OUT.meta.json" ]]; then echo "$OUT: already there"; exit 0; fi

HDR=$(mktemp)
curl -sf -D "$HDR" -o "$OUT.part" "$URL"
MD5_PUB=$(tr -d '\r' < "$HDR" | grep -i '^x-md5:' | cut -d'"' -f2 || true)
MD5_OUR=$(md5 -q "$OUT.part")
SHA_OUR=$(shasum -a 256 "$OUT.part" | cut -d' ' -f1)
SIZE=$(stat -f %z "$OUT.part")
if [[ -n "$MD5_PUB" && "$MD5_PUB" != "$MD5_OUR" ]]; then
  echo "MD5 MISMATCH for $URL: published $MD5_PUB, got $MD5_OUR"; rm -f "$OUT.part" "$HDR"; exit 1
fi
mv "$OUT.part" "$OUT"
cat > "$OUT.meta.json" <<EOF
{"url": "$URL", "downloaded_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "bytes": $SIZE,
 "md5_published": "$MD5_PUB", "md5_computed": "$MD5_OUR", "sha256_computed": "$SHA_OUR",
 "md5_ok": $([[ "$MD5_PUB" == "$MD5_OUR" ]] && echo true || echo false)}
EOF
rm -f "$HDR"
echo "$OUT: $SIZE bytes, md5 ok"
