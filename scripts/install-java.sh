#!/bin/sh
# Firestore emülatörü için YEREL Java çalışma zamanı kurar (.tools/).
#
# Neden yerel: emülatör Java istiyor, bu makinede Java yok ve sisteme kurulum
# yönetici şifresi ister. `.tools/` gitignore'lu, sistemi değiştirmiyor ve
# silmek `rm -rf .tools` kadar. Depoyu klonlayan biri kural testlerini
# koşturmak istediğinde bu betik onu tekrar üretir — indirilen ikili dosya
# repoda tutulmuyor.
#
# Kaynak: Eclipse Adoptium (Temurin) resmi GitHub sürümleri.
# Bütünlük: yayınlanan .sha256.txt ile karşılaştırılır; eşleşmezse kurulum durur.
set -e

VERSION_TAG="jdk-21.0.12+8"
ARCHIVE="OpenJDK21U-jre_aarch64_mac_hotspot_21.0.12_8.tar.gz"
BASE="https://github.com/adoptium/temurin21-binaries/releases/download"
# Etikette '+' var; URL'de yüzde kodlaması gerekiyor.
URL="$BASE/$(printf '%s' "$VERSION_TAG" | sed 's/+/%2B/')/$ARCHIVE"

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOLS="$ROOT/.tools"

if ls -d "$TOOLS"/jdk-*/Contents/Home >/dev/null 2>&1; then
  echo "Yerel Java zaten kurulu: $(ls -d "$TOOLS"/jdk-*/Contents/Home | head -1)"
  exit 0
fi

mkdir -p "$TOOLS"
echo "İndiriliyor: $ARCHIVE (~46 MB)"
curl -fL --progress-bar -o "$TOOLS/jre.tar.gz" "$URL"

echo "Sağlama denetleniyor…"
PUBLISHED=$(curl -fsSL "$URL.sha256.txt" | awk '{print $1}')
ACTUAL=$(shasum -a 256 "$TOOLS/jre.tar.gz" | awk '{print $1}')
if [ "$PUBLISHED" != "$ACTUAL" ]; then
  echo "SHA256 EŞLEŞMEDİ — dosya kullanılmıyor." >&2
  echo "  yayınlanan: $PUBLISHED" >&2
  echo "  indirilen : $ACTUAL" >&2
  rm -f "$TOOLS/jre.tar.gz"
  exit 1
fi

tar -xzf "$TOOLS/jre.tar.gz" -C "$TOOLS"
rm -f "$TOOLS/jre.tar.gz"
echo "Kuruldu: $(ls -d "$TOOLS"/jdk-*/Contents/Home | head -1)"
