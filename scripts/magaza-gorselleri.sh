#!/bin/sh
# App Store Connect görselleri — simülatörden DOĞAL çözünürlükte çeker.
#
#     sh scripts/magaza-gorselleri.sh [hedef-dizin]
#
# Varsayılan hedef: ~/Desktop/InsaatTakip-ASC
#
# NEDEN BETİK: arayüz her değiştiğinde görseller eskiyor. Elle çekilen 20
# ekran, ikinci turda 20 elle iş demek; burada tek komut.
#
# NEDEN DEMO VERİSİ: `-backend firestore` VERİLMİYOR, yani uygulama bellek
# içi senaryoyu kullanıyor. Mağaza görselleri HERKESE AÇIK ve sonsuza kadar
# orada duruyor; gerçek projelerin ciroları ve ALICI ADLARI oraya giremez
# (KVKK). Demo veri bu yüzden tercih değil, zorunluluk.
#
# NEDEN İKİ CİHAZ: ASC küçük boyutları büyükten kendisi ölçekliyor ama
# ölçeklenmiş görsel yumuşak çıkıyor. İki sınıf da DOĞAL çözünürlükte
# çekiliyor: 6,3" (1206x2622) ve 6,9" (1320x2868).
#
# DURUM ÇUBUĞU SABİTLENİYOR: 9:41, tam pil, tam sinyal. Apple'ın kendi
# görsellerindeki saat de bu. Sabitlenmezse her çekimde farklı saat ve pil
# yüzdesi çıkıyor, set tutarsız görünüyor.
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HEDEF="${1:-$HOME/Desktop/InsaatTakip-ASC}"
TURKCE_LC=tr_TR.UTF-8

# Ekran tanımları: dosya-adı|launch argümanları
# Argümanla açılamayan ekran YOK — eksik olanlar (giderler, gider ekleme)
# bu tur için LaunchConfig'e eklendi.
EKRANLAR=$(cat <<'LISTE'
01-pano|-role admin -screen dashboard
02-malzemeler|-role admin -screen project -tab mat
03-giderler|-role admin -screen project -tab exp
04-daireler|-role admin -screen project -tab apt
05-ortaklar|-role admin -screen project -tab ptn
06-belgeler|-role admin -screen project -tab doc
07-daire-detay|-role admin -screen project -sheet apt
08-satis-kaydi|-role admin -screen project -sheet sale
09-malzeme-girisi|-role admin -screen project -sheet log
10-fis-ekle|-role admin -screen project -sheet receipt
11-gider-ekle|-role admin -screen project -sheet expense
12-ilerleme|-role admin -screen project -sheet progress
13-ortak-daveti|-role admin -screen project -sheet invite
14-belge-yukle|-role admin -screen project -sheet upload
15-donem-raporu|-role admin -screen report
16-santiye-fotograflari|-role admin -screen photos
17-hareket-akisi|-role admin -screen activity
18-paketler|-role admin -screen dashboard -sheet plans
19-ortak-gorunumu|-role partner -screen project
20-ortak-karsilamasi|-role admin -screen dashboard -sheet partner
21-tanitim|-screen intro
LISTE
)

BUNDLE=com.sinanalpagut.insaattakip

cek() {
  CIHAZ="$1"; KLASOR="$2"
  echo "──────── $CIHAZ ────────"

  UDID=$(xcrun simctl list devices available | grep "    $CIHAZ (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  [ -z "$UDID" ] && { echo "simülatör bulunamadı: $CIHAZ" >&2; return 1; }

  xcrun simctl boot "$UDID" 2>/dev/null || true
  until xcrun simctl list devices | grep -q "$UDID) (Booted)"; do sleep 2; done

  # Dil ve bölge: uygulama Türkçe, görseller de Türkçe olmalı.
  xcrun simctl spawn "$UDID" defaults write -g AppleLanguages -array tr >/dev/null 2>&1 || true
  xcrun simctl spawn "$UDID" defaults write -g AppleLocale -string "$TURKCE_LC" >/dev/null 2>&1 || true

  xcrun simctl install "$UDID" "$APP" >/dev/null

  # Durum çubuğu sabit — set tutarlı görünsün.
  xcrun simctl status_bar "$UDID" override \
      --time "9:41" --batteryState charged --batteryLevel 100 \
      --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 >/dev/null 2>&1 || true

  mkdir -p "$HEDEF/$KLASOR"

  echo "$EKRANLAR" | while IFS='|' read -r AD ARGS; do
    [ -z "$AD" ] && continue
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
    # shellcheck disable=SC2086
    xcrun simctl launch "$UDID" "$BUNDLE" $ARGS >/dev/null
    # Sheet'ler 0.6 sn gecikmeyle açılıyor (ProjectDetailView) + animasyon.
    sleep 3
    xcrun simctl io "$UDID" screenshot --type=png "$HEDEF/$KLASOR/$AD.png" >/dev/null 2>&1
    BOYUT=$(sips -g pixelWidth -g pixelHeight "$HEDEF/$KLASOR/$AD.png" 2>/dev/null | awk '/pixel/{printf "%s", $2"x"} END{print ""}' | sed 's/x$//')
    echo "  $AD  ($BOYUT)"
  done

  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
}

# ── Derleme ──
DD="$ROOT/.build-magaza"
echo "derleniyor…"
xcodebuild -project "$ROOT/InsaatTakip.xcodeproj" -scheme InsaatTakip \
           -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
           -derivedDataPath "$DD" build > "$DD.log" 2>&1
APP="$DD/Build/Products/Debug-iphonesimulator/InsaatTakip.app"
[ -d "$APP" ] || { echo "derleme düştü, bkz. $DD.log" >&2; exit 1; }

mkdir -p "$HEDEF"
cek "iPhone 17 Pro"     "6.3-inch"
cek "iPhone 17 Pro Max" "6.9-inch"

echo
echo "bitti → $HEDEF"
