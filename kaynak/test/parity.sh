#!/bin/bash
# JS (scene.js) ve C# (win/Engine.cs) motorlarini ayni tohumla calistirip her tick'i karsilastirir.
# Kullanim: kaynak/test/parity.sh [tick]
# Gerekenler: node, mono (mcs). Windows'ta: csc ile derleyip parity_cs.exe'yi calistirabilirsin.
set -e
cd "$(dirname "$0")"
N=${1:-20000}
T=$(mktemp -d)
mcs -langversion:5 -nologo -out:$T/parity_cs.exe ../win/Engine.cs parity_cs.cs
rc=0
for case in "12345 960" "777 1920" "42 1366" "99991 2560" "5 1280" "31337 3840"; do
  set -- $case
  node parity_js.js $1 $2 $N > $T/js.txt
  mono $T/parity_cs.exe $1 $2 $N > $T/cs.txt
  if cmp -s $T/js.txt $T/cs.txt; then
    echo "AYNI   tohum=$1 genislik=$2 satir=$(wc -l < $T/js.txt)"
  else
    echo "FARKLI tohum=$1 genislik=$2"; diff $T/js.txt $T/cs.txt | head -6; rc=1
  fi
done
rm -rf $T
exit $rc
