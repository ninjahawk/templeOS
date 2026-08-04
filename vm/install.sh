#!/usr/bin/env bash
# Install TempleOS to the virtual disk and load the oracle into it.
#
# TempleOS installs interactively and there is no unattended mode, so this
# answers the prompts by keystroke. Rather than sleeping for fixed durations --
# partitioning and zeroing take minutes under TCG and vary by host -- each step
# waits for the framebuffer to stop changing, which is what "waiting for input"
# looks like from outside.
#
# Safe to re-run: it starts by discarding any existing disk image.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
HOLYC="$HERE/../holyc"

./setup.sh

echo
echo "==> discarding any previous install"
./tos.py stop >/dev/null 2>&1 || true
rm -f templeos.qcow2
qemu-img create -f qcow2 templeos.qcow2 2G >/dev/null

echo "==> booting the CD"
./tos.py start --install >/dev/null
./tos.py waitidle 8

echo "==> install onto hard drive"
./tos.py key y
./tos.py waitidle 8

echo "==> confirming this is a virtual machine"
./tos.py key y
./tos.py waitidle 8

echo "==> partitioning and zeroing (slow)"
./tos.py key ret
./tos.py waitidle 20

echo "==> rebooting into the installed system"
./tos.py key y
sleep 5
./tos.py boot >/dev/null
./tos.py waitidle 8

echo "==> selecting Drive C"
./tos.py key 1
./tos.py waitidle 12

echo "==> dismissing the tour"
./tos.py key n
./tos.py waitidle 6

for f in U Urim BookTest RdTest2; do
  echo "==> installing $f.HC"
  ./tos.py type "Del(\"::/Home/$f.HC\");" ; ./tos.py key ret ; sleep 2
  ./tos.py type "Ed(\"::/Home/$f.HC\");"  ; ./tos.py key ret ; sleep 4
  ./tos.py typefile "$HOLYC/$f.HC"
  ./tos.py key esc
  sleep 3
done

echo
echo "Installed. Verify with ./test.sh, then consult with:"
echo
echo "  ./tos.py type '#include \"::/Home/U\"';    ./tos.py key ret"
echo "  ./tos.py type '#include \"::/Home/Urim\"'; ./tos.py key ret"
echo "  ./qseed.py"
echo "  ./tos.py type 'Urim;'; ./tos.py key ret"
