#!/bin/bash
# JS ve PowerShell motorlarini ayni tohumla calistirip her tick'i karsilastirir.
# Kullanim: kaynak/test/parity.sh [tick]   (pwsh gerekli)
cd "$(dirname "$0")"
N=${1:-6000}
rc=0
for case in "12345 960" "777 1920" "42 1366" "99991 2560"; do
  set -- $case
  node parity_js.js $1 $2 $N > /tmp/parity_js_$1.txt
  pwsh -NoProfile -File parity_ps.ps1 $1 $2 $N
  if cmp -s /tmp/parity_js_$1.txt /tmp/parity_ps_$1.txt; then
    echo "AYNI   tohum=$1 genislik=$2 satir=$(wc -l < /tmp/parity_js_$1.txt)"
  else
    echo "FARKLI tohum=$1 genislik=$2"; diff /tmp/parity_js_$1.txt /tmp/parity_ps_$1.txt | head -6; rc=1
  fi
done
exit $rc
