#!/bin/bash
# Boot the INSTALLED TempleOS from the hard disk (no CD attached).
# Headless: framebuffer on VNC, control via the QEMU HMP monitor socket.
#
# At the "TempleOS Boot Loader" prompt choose 1 (Drive C).
set -euo pipefail
source "$(dirname "$0")/env.sh"

[ -f "$DISK" ] || { echo "no disk at $DISK -- run ./setup.sh && ./install.sh"; exit 1; }
rm -f "$MONITOR"

exec qemu-system-x86_64 \
  -m "$VM_MEM" -smp 1 -cpu qemu64 \
  -drive file="$DISK",format=qcow2,if=ide,index=0,media=disk \
  -boot c \
  -vga std \
  -display none -vnc "$VNC_DISPLAY" \
  -monitor unix:"$MONITOR",server,nowait \
  -audiodev none,id=snd0
