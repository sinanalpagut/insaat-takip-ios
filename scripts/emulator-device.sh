#!/bin/sh
# Emülatörü GERÇEK CİHAZ için başlatır: yerel ağ arayüzünü dinler.
#
# NEDEN AYRI BETİK: `emulator-app.sh` yalnızca 127.0.0.1'i dinliyor — simülatör
# Mac ile aynı makinede olduğu için bu yeterli ve en dar yüzey. Gerçek iPhone
# ise ayrı bir cihaz: Mac'in yerel ağ adresine bağlanmak zorunda.
#
# GÜVENLİK: bu betik emülatörü AYNI Wi-Fi'daki herkese açar. Emülatörde yalnızca
# test verisi var ve süreç kapanınca her şey uçuyor; yine de güvenilmeyen bir
# ağda (kafe, otel) ÇALIŞTIRMA. Varsayılan hâlâ loopback — açma kararı burada,
# açıkça veriliyor.
#
# Kullanım:
#   sh scripts/emulator-device.sh
#   → ekrana yazılan adresle uygulamayı cihaza kur:
#     -backend firestore -emulator <IP>:8080
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

IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
if [ -z "$IP" ]; then
  echo "Yerel ağ adresi bulunamadı — Wi-Fi bağlı mı?" >&2
  exit 1
fi

echo "─────────────────────────────────────────────"
echo " Emülatör yerel ağda: $IP"
echo " Cihaz derlemesine ver:  -emulator $IP:8080"
echo " iPhone ve Mac AYNI Wi-Fi'da olmalı."
echo "─────────────────────────────────────────────"

exec sh "$ROOT/scripts/with-java.sh" \
  npx firebase emulators:start \
    --only firestore,auth,functions,storage \
    --project "$PROJECT_ID" \
    --config "$ROOT/firebase.device.json"
