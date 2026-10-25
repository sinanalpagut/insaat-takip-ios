#!/bin/sh
# Build numarasını git commit sayısına eşitler (madde 30).
#
# NEDEN DERLEME İÇİ BETİK DEĞİL: proje `ENABLE_USER_SCRIPT_SANDBOXING = YES`
# ile derleniyor ve kum havuzu, derleme betiğinin `.git` dizinini okumasını
# engelliyor. Bir Run Script fazı denendi: `git rev-list` sessizce BOŞ döndü,
# yani numara hep 1 kaldı ve hiçbir uyarı çıkmadı. Kum havuzunu kapatmak
# Apple'ın önerdiği bir güvenlik ayarını zayıflatmak olurdu; onun yerine
# numara derlemenin DIŞINDA üretiliyor.
#
# `GENERATE_INFOPLIST_FILE = YES` olduğu için `CFBundleVersion` doğrudan
# `CURRENT_PROJECT_VERSION` ayarından geliyor — Info.plist'e dokunmak gerekmiyor.
#
# NEDEN COMMIT SAYISI: monoton artıyor, dallar arasında tekrar üretilebiliyor
# ve elle takip gerektirmiyor. App Store aynı build numarasını iki kez kabul
# etmiyor; unutulan bir artırım gönderim gününde fark ediliyor.
#
# ŞEMANIN ARCHIVE ÖN-EYLEMİ BU BETİĞİ ÇALIŞTIRIYOR (madde 74) AMA AYNI
# ARŞİVE YETİŞMİYOR. Ön-eylem kum havuzunun dışında koşup `.git`i
# okuyabiliyor; ancak Xcode derleme ayarlarını ön-eylemden ÖNCE okuyor.
# 25 Eki 2026'da ölçüldü: ön-eylem proje dosyasına "233 → 250" yazdı, arşivin
# Info.plist'i 233 çıktı. Yani yeni commit'lerden sonraki İLK arşiv bayat
# numarayı taşıyor, numara ancak bir sonraki arşive geçiyor.
#
# DOĞRU SIRA: arşivden ÖNCE `npm run build:number` (ya da bu betik), sonra
# Archive. Ön-eylem yerinde kalıyor çünkü zararsız ve unutulan bir çalıştırmayı
# en azından bir sonraki arşivde düzeltiyor. Yüklemeden önce Organizer'daki
# numarayı `git rev-list --count HEAD` ile karşılaştır.
#
# DERLEME FAZI DENENDİ VE OLMADI; iki engel de ölçülerek görüldü:
#   1. `git -C "$SRCROOT" rev-list --count HEAD` kum havuzunda
#      "fatal: not a git repository" veriyor — `.git` gizli.
#   2. `plutil -replace CFBundleVersion` ile ÜRETİLEN plist'e yazmak da
#      engelleniyor ve betik hata verip DERLEMEYİ DÜŞÜRÜYOR. Üstelik
#      `ProcessInfoPlistFile` betik fazlarından SONRA koştuğu için, yazma
#      başarılı olsa bile üzerine yazılıyordu.
# Yani numara derlemenin içinde üretilemez; ön-eylem tek doğru yer.
#
# Elle de çalıştırılabilir:
#   sh scripts/set-build-number.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PBXPROJ="$ROOT/InsaatTakip.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
  echo "project.pbxproj bulunamadı: $PBXPROJ" >&2
  exit 1
fi

BUILD=$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || true)
if [ -z "$BUILD" ]; then
  echo "git commit sayısı okunamadı — depo yok ya da git erişilemiyor." >&2
  exit 1
fi

CURRENT=$(grep -m1 "CURRENT_PROJECT_VERSION" "$PBXPROJ" | sed 's/[^0-9]//g')

# Sürüm GERİ GİTMEZ: App Store daha küçük bir build numarasını reddediyor ve
# sebebi gönderim anında anlaşılıyor. Sığ klonda commit sayısı düşük çıkabilir.
if [ -n "$CURRENT" ] && [ "$BUILD" -lt "$CURRENT" ]; then
  echo "UYARI: hesaplanan numara ($BUILD) mevcut olandan ($CURRENT) küçük — değiştirilmedi." >&2
  echo "Sığ klon (shallow clone) kullanıyorsan 'git fetch --unshallow' gerekir." >&2
  exit 1
fi

sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PBXPROJ"
echo "Build numarası: $CURRENT → $BUILD (git commit sayısı)"
