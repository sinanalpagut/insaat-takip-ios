#!/bin/sh
# Emülatörü UYGULAMANIN proje kimliğiyle başlatır (Firestore + Auth).
#
# Neden ayrı betik: `npm test` kural testlerini `demo-insaattakip` kimliğiyle
# koşturuyor — "demo-" öneki Firebase araçlarının uzak servise hiç bağlanmamasını
# garanti ediyor. Ama UYGULAMA `GoogleService-Info.plist` içindeki gerçek kimlikle
# yapılandırılıyor ve emülatör aynı kimliği kullanmazsa jetonlar eşleşmiyor.
#
# Proje kimliği plist'ten okunuyor; plist gitignore'lu, dolayısıyla kimlik
# depoya girmiyor. Uzak veritabanına DOKUNULMUYOR: uygulama `-emulator` ile
# başlatıldığında SDK yalnızca yerel adrese bağlanıyor.
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# plist uygulama hedefinin klasöründe (Xcode 16 eşlenik klasörü).
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

exec sh "$ROOT/scripts/with-java.sh" \
  npx firebase emulators:start --only firestore,auth --project "$PROJECT_ID"
