#!/usr/bin/env python3
"""Talk to the QEMU HMP monitor over its unix socket.

    python3 mon.py "info status"
    python3 mon.py "sendkey ret"
    python3 mon.py "screendump /tmp/shot.ppm"

VM_DIR env var selects the VM directory (default ~/templeos-vm).
"""
import os
import socket
import sys
import time

SOCK = os.path.join(
    os.environ.get("VM_DIR", os.path.expanduser("~/templeos-vm")), "monitor.sock"
)


def send(cmds, wait=0.6):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)
    s.settimeout(3)
    time.sleep(0.3)
    try:
        s.recv(65536)  # drain banner
    except OSError:
        pass
    out = b""
    for c in cmds:
        s.sendall((c + "\n").encode())
        time.sleep(wait)
        try:
            out += s.recv(65536)
        except OSError:
            pass
    s.close()
    return out.decode(errors="replace")


if __name__ == "__main__":
    print(send(sys.argv[1:]))
