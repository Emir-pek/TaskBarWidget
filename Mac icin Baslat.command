#!/bin/bash
# ============================================================
#   Taskbar Kedileri - macOS / Linux baslatici
#   Bu dosyaya cift tikla. Ilk calistirmada Electron indirilir.
# ============================================================
cd "$(dirname "$0")/masaustu" || exit 1

if ! command -v node >/dev/null 2>&1; then
  echo "HATA: Node.js bulunamadi."
  echo "https://nodejs.org adresinden LTS surumunu kurup tekrar dene."
  command -v open >/dev/null 2>&1 && open "https://nodejs.org/"
  echo; read -n 1 -s -r -p "Kapatmak icin bir tusa bas..."
  exit 1
fi

# Bagimliliklar degisince (or. v1.1'de koffi eklendi) isaret dosyasi da degisir
# ve npm install bir kez daha calisir.
MARK="node_modules/.kurulum-v1.1"
if [ ! -d node_modules/electron ] || [ ! -f "$MARK" ]; then
  echo "Kurulum: Electron ve yardimcilar indiriliyor (ilk seferde ~150 MB)."
  echo "Birkac dakika surebilir, pencereyi kapatma..."
  echo
  if ! npm install --no-audit --no-fund; then
    echo; echo "npm install basarisiz oldu. Internet baglantini kontrol et."
    read -n 1 -s -r -p "Kapatmak icin bir tusa bas..."
    exit 1
  fi
  touch "$MARK"
fi

echo "Kediler baslatiliyor... (menu cubugundaki kedi ikonundan kapatabilirsin)"
npm start
