#!/bin/bash
# Shared config for the TempleOS VM scripts.
# Override VM_DIR to keep the disk image / ISO somewhere other than the default.
export VM_DIR="${VM_DIR:-$HOME/templeos-vm}"
export ISO="$VM_DIR/TempleOS.ISO"
export DISK="$VM_DIR/templeos.qcow2"
export MONITOR="$VM_DIR/monitor.sock"
export VNC_DISPLAY="${VNC_DISPLAY:-127.0.0.1:0}"   # -> VNC port 5900
export VM_MEM="${VM_MEM:-512}"
export ISO_URL="https://templeos.org/Downloads/TempleOS.ISO"
