#!/bin/sh
# Swift birim testlerini koşturur.
#
#   sh scripts/test.sh                # tümü
#   sh scripts/test.sh KurusTests     # tek sınıf
#
# Simülatör kimliği verilmezse ilk uygun iPhone seçilir; belirli bir cihaz için:
#   SIM="iPhone 17 Pro" sh scripts/test.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

NAME=${SIM:-}
if [ -z "$NAME" ]; then
  NAME=$(xcrun simctl list devices available | grep -oE 'iPhone [0-9][^(]*' | head -1 | sed 's/ *$//')
fi
if [ -z "$NAME" ]; then
  echo "Uygun bir iPhone simülatörü bulunamadı." >&2
  exit 1
fi

FILTER=""
if [ -n "$1" ]; then
  FILTER="-only-testing:InsaatTakipTests/$1"
fi

echo "Simülatör: $NAME"
# `xcbeautify` yok; çıktı süzülerek okunur tutuluyor.
set +e
xcodebuild -project InsaatTakip.xcodeproj \
           -scheme InsaatTakip \
           -destination "platform=iOS Simulator,name=$NAME" \
           $FILTER \
           test 2>&1 | grep -E "Test Case '.*' (passed|failed)|Executed .* tests, with|error:|\*\* TEST"
STATUS=${PIPESTATUS:-$?}
set -e
exit "$STATUS"
