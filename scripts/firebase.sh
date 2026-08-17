#!/bin/sh
# Firebase CLI'yi projenin kendi kimliğiyle çalıştırır.
#
#   sh scripts/firebase.sh deploy --only firestore:rules
#
# Proje kimliği `GoogleService-Info.plist`ten okunuyor. Böylece `.firebaserc`
# oluşturmaya gerek kalmıyor ve kimlik depoya girmiyor — plist gitignore'lu.
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PLIST="$ROOT/InsaatTakip/GoogleService-Info.plist"

if [ ! -f "$PLIST" ]; then
  echo "GoogleService-Info.plist bulunamadı: $PLIST" >&2
  exit 1
fi

PROJECT_ID=$(/usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "$PLIST" 2>/dev/null || true)
if [ -z "$PROJECT_ID" ]; then
  echo "plist içinde PROJECT_ID yok." >&2
  exit 1
fi

cd "$ROOT"
exec npx firebase --project "$PROJECT_ID" "$@"
