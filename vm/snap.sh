#!/bin/bash
# Grab the VM framebuffer as a PNG.  usage: ./snap.sh <name>  -> $VM_DIR/<name>.png
set -euo pipefail
source "$(dirname "$0")/env.sh"
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:-shot}"

python3 "$HERE/mon.py" "screendump $VM_DIR/$NAME.ppm" >/dev/null
sleep 1
pnmtopng "$VM_DIR/$NAME.ppm" > "$VM_DIR/$NAME.png"
rm -f "$VM_DIR/$NAME.ppm"
echo "$VM_DIR/$NAME.png"
