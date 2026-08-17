#!/bin/sh
# Verilen komutu çalışan bir Java ile koşturur.
#
# Firestore emülatörü Java istiyor. Bu makinede sistem Java'sı yok ve Homebrew
# de yok; sisteme kurulum yapmak yerine `.tools/` altına yerel bir Temurin JRE
# açıldı (bkz. npm run java:install). Bu betik onu bulup PATH'e ekler.
#
# DİKKAT — macOS tuzağı: `/usr/bin/java` Java kurulu OLMASA DA var. `command -v
# java` bu yüzden yanıltıcı; gerçekten çalıştığını `java -version` ile denemek
# gerekiyor, aksi halde emülatör "exited with code 1" diye düşer.
set -e

if ! java -version >/dev/null 2>&1; then
  LOCAL=$(ls -d "$(dirname "$0")"/../.tools/jdk-*/Contents/Home 2>/dev/null | head -1)
  if [ -z "$LOCAL" ]; then
    echo "Java bulunamadı. Yerel çalışma zamanını kurmak için: npm run java:install" >&2
    exit 1
  fi
  JAVA_HOME=$(cd "$LOCAL" && pwd)
  PATH="$JAVA_HOME/bin:$PATH"
  export JAVA_HOME PATH
fi

exec "$@"
