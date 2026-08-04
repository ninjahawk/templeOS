#!/usr/bin/env bash
# Boot the installed system and check the oracle still works.
#
# Two things are actually verifiable without a deity: that the entropy source
# is live and varying, and that a draw lands on the citation it claims. The
# offsets below are fixed, so their references are known answers -- including
# 1134990, which is the draw that once cited 1 Samuel as First Kings.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "==> booting"
./tos.py boot >/dev/null
./tos.py waitidle 8
./tos.py key 1
./tos.py waitidle 12
./tos.py key n
./tos.py waitidle 6

echo "==> loading"
./tos.py type '#include "::/Home/U"'        ; ./tos.py key ret ; sleep 5
./tos.py type '#include "::/Home/Urim"'     ; ./tos.py key ret ; sleep 10
./tos.py type '#include "::/Home/BookTest"' ; ./tos.py key ret ; sleep 6

echo "==> citations"
./tos.py mark >/dev/null
./tos.py type 'BookTest;' ; ./tos.py key ret
sleep 45
out="$(./tos.py con)"
echo "$out"

grep -q 'Called Genesis\] 3:1'                     <<<"$out" || fail "Genesis citation"
grep -q 'The First Book of Samuel'                 <<<"$out" || fail "1 Samuel must cite its full title, not just First Kings"
grep -q '1134990 -> .*\] 14:10'                    <<<"$out" || fail "1 Samuel verse"
grep -q 'Prophet Jeremiah\] 23:35'                 <<<"$out" || fail "Jeremiah citation"
grep -q 'to the Corinthians\] 2:9'                 <<<"$out" || fail "Corinthians citation"

echo "==> entropy is live"
./tos.py type '#include "::/Home/RdTest2"' ; ./tos.py key ret ; sleep 6
./tos.py mark >/dev/null
./tos.py type 'TT;' ; ./tos.py key ret
sleep 12
ent="$(./tos.py con)"
echo "$ent"

# ok=1 is RDRAND's carry flag: the draw really came from the hardware source
# rather than being a silent zero.
n_ok=$(grep -c 'val=[0-9A-F]\{16\} ok=1' <<<"$ent" || true)
[ "$n_ok" -eq 4 ] || fail "expected 4 successful RDRAND draws, got $n_ok"
uniq_vals=$(grep -o 'val=[0-9A-F]\{16\}' <<<"$ent" | sort -u | wc -l)
[ "$uniq_vals" -eq 4 ] || fail "RDRAND repeated a value across draws ($uniq_vals distinct)"

echo
echo "PASS"
