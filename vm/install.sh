#!/bin/bash
# Boot the TempleOS live CD, which is also the installer.
#
# The installer is interactive. Drive it with ../vm/mon.py (sendkey) or a VNC
# client. Prompt sequence observed on TempleOS 5.03:
#
#   "Install onto hard drive (y or n)?"                  -> y
#   "Are you installing inside VMware, QEMU, ...?"       -> y
#   (auto-partitions, formats, copies ~44MB to C:)       -- ~2 min under TCG
#   "Reboot Now (y or n)?"                               -> n
#
# Then kill this VM and use ./run.sh, choosing 1 (Drive C) at the boot loader.
# First boot decompresses the dictionary and shows a Tip of the Day.
set -euo pipefail
source "$(dirname "$0")/env.sh"

[ -f "$ISO" ]  || { echo "no ISO at $ISO -- run ./setup.sh"; exit 1; }
[ -f "$DISK" ] || { echo "no disk at $DISK -- run ./setup.sh"; exit 1; }
rm -f "$MONITOR"

exec qemu-system-x86_64 \
  -m "$VM_MEM" -smp 1 -cpu qemu64 \
  -drive file="$DISK",format=qcow2,if=ide,index=0,media=disk \
  -drive file="$ISO",if=ide,index=2,media=cdrom \
  -boot d \
  -vga std \
  -display none -vnc "$VNC_DISPLAY" \
  -monitor unix:"$MONITOR",server,nowait \
  -audiodev none,id=snd0
