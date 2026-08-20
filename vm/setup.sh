#!/bin/bash
# One-time host setup: install QEMU, fetch the TempleOS ISO, create the disk image.
set -euo pipefail
source "$(dirname "$0")/env.sh"

if ! command -v qemu-system-x86_64 >/dev/null; then
  echo ">> installing qemu + netpbm (screenshot conversion)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq qemu-system-x86 qemu-utils netpbm
fi

mkdir -p "$VM_DIR"

if [ ! -f "$ISO" ]; then
  echo ">> downloading TempleOS ISO (public domain)"
  curl -sSL --max-time 300 -o "$ISO" "$ISO_URL"
fi
file "$ISO" | grep -q "ISO 9660" || { echo "ISO looks wrong"; exit 1; }

if [ ! -f "$DISK" ]; then
  echo ">> creating 2G qcow2 disk"
  qemu-img create -f qcow2 "$DISK" 2G
fi

echo ">> ready. Next: ./install.sh (first time) or ./run.sh (already installed)"
