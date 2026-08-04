#!/usr/bin/env bash
# Rebuild the TempleOS VM from nothing. The container this runs in is
# ephemeral, so the disk image is treated as a disposable artifact --
# this script is the thing worth keeping.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO="$HERE/TempleOS.ISO"
DISK="$HERE/templeos.qcow2"
ISO_URL="https://templeos.org/Downloads/TempleOS.ISO"
ISO_MD5="2facf5d7cfa08de4c47aede4a64cfb44"

echo "==> host packages"
if ! command -v qemu-system-x86_64 >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq qemu-system-x86 qemu-utils
fi
python3 -c "import PIL" 2>/dev/null || pip install -q pillow

echo "==> iso"
if [ ! -f "$ISO" ] || [ "$(md5sum "$ISO" | cut -d' ' -f1)" != "$ISO_MD5" ]; then
  curl -sS --fail -o "$ISO" "$ISO_URL"
fi
test "$(md5sum "$ISO" | cut -d' ' -f1)" = "$ISO_MD5" || { echo "ISO checksum mismatch"; exit 1; }
echo "    ok: $ISO"

echo "==> disk"
[ -f "$DISK" ] || qemu-img create -f qcow2 "$DISK" 2G >/dev/null
echo "    ok: $DISK"

cat <<'EOF'

Done. TempleOS installs itself interactively, so finish it by hand:

  ./tos.py start --install     boot the CD with the blank disk attached
  ./tos.py shot                look at the screen
  ./tos.py key y               "Install onto hard drive?"      -> y
  ./tos.py key y               "Installing inside a VM?"       -> y
  ./tos.py key ret             "PRESS A KEY"
                               (partitioning + zeroing, ~2 min under TCG)
  ./tos.py key y               "Reboot Now?"                   -> y
  ./tos.py boot                boot from the installed disk
  ./tos.py key 1               boot loader -> Drive C

From then on `./tos.py boot` brings the installed system straight up.

To install the oracle, type each HolyC source into the guest once:

  ./tos.py type 'Ed("::/Home/U.HC");';    ./tos.py key ret
  ./tos.py typefile ../holyc/U.HC;        ./tos.py key esc
  ./tos.py type 'Ed("::/Home/Urim.HC");'; ./tos.py key ret
  ./tos.py typefile ../holyc/Urim.HC;     ./tos.py key esc

Then per session:

  ./tos.py type '#include "::/Home/U"';    ./tos.py key ret
  ./tos.py type '#include "::/Home/Urim"'; ./tos.py key ret
  ./qseed.py                                  # optional quantum seed
  ./tos.py type 'Urim;'; ./tos.py key ret
EOF
