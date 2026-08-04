#!/usr/bin/env python3
"""Headless driver for a TempleOS QEMU VM.

Talks to the QEMU human monitor over a unix socket so we can boot, send
keystrokes and grab screenshots without any display attached.

  ./tos.py start [--install]   boot from CD (--install also attaches the disk)
  ./tos.py boot                boot from the installed hard disk
  ./tos.py shot [name]         capture the framebuffer to shots/<name>.png
  ./tos.py key <keys...>       send keys, e.g. ret, a, ctrl-alt-f1
  ./tos.py type "text"         type a literal string
  ./tos.py cmd "<monitor>"     raw monitor command
  ./tos.py stop                kill the VM
"""
import os
import socket
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SOCK = os.path.join(HERE, "monitor.sock")
PID = os.path.join(HERE, "qemu.pid")
ISO = os.path.join(HERE, "TempleOS.ISO")
DISK = os.path.join(HERE, "templeos.qcow2")
SHOTS = os.path.join(HERE, "shots")

# QEMU keynames for characters that aren't just their own literal name.
SHIFTED = {
    "!": "shift-1", "@": "shift-2", "#": "shift-3", "$": "shift-4",
    "%": "shift-5", "^": "shift-6", "&": "shift-7", "*": "shift-8",
    "(": "shift-9", ")": "shift-0", "_": "shift-minus", "+": "shift-equal",
    "{": "shift-bracket_left", "}": "shift-bracket_right",
    "|": "shift-backslash", ":": "shift-semicolon", '"': "shift-apostrophe",
    "<": "shift-comma", ">": "shift-dot", "?": "shift-slash", "~": "shift-grave_accent",
}
PLAIN = {
    " ": "spc", "-": "minus", "=": "equal", "[": "bracket_left",
    "]": "bracket_right", "\\": "backslash", ";": "semicolon",
    "'": "apostrophe", ",": "comma", ".": "dot", "/": "slash",
    "`": "grave_accent", "\n": "ret", "\t": "tab",
}


def monitor(cmd, wait=0.35):
    """Send one command to the QEMU monitor and return whatever it printed."""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(15)
    s.connect(SOCK)
    time.sleep(0.2)
    try:  # drain the banner
        s.recv(65536)
    except socket.timeout:
        pass
    s.sendall((cmd + "\n").encode())
    time.sleep(wait)
    out = b""
    s.settimeout(2)
    try:
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            out += chunk
    except socket.timeout:
        pass
    s.close()
    return out.decode(errors="replace")


def start(from_disk=False, attach_disk=True, memory=512):
    stop(quiet=True)
    for stale in (SOCK, PID):
        if os.path.exists(stale):
            os.remove(stale)
    cmd = [
        "qemu-system-x86_64",
        "-accel", "tcg",                    # no /dev/kvm in this container
        "-m", str(memory),
        "-smp", "1",
        "-cpu", "qemu64",
        "-machine", "pc",
        "-vga", "std",
        "-display", "none",
        "-rtc", "base=localtime",
        "-monitor", f"unix:{SOCK},server,nowait",
        "-pidfile", PID,
    ]
    if attach_disk and os.path.exists(DISK):
        cmd += ["-drive", f"file={DISK},format=qcow2,if=ide,index=0,media=disk"]
    cmd += ["-drive", f"file={ISO},format=raw,if=ide,index=2,media=cdrom"]
    cmd += ["-boot", "order=c" if from_disk else "order=d"]
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(60):
        if os.path.exists(SOCK):
            time.sleep(0.6)
            print("started:", " ".join(cmd))
            return
        time.sleep(0.25)
    sys.exit("qemu monitor socket never appeared")


def shot(name="screen"):
    os.makedirs(SHOTS, exist_ok=True)
    ppm = os.path.join(SHOTS, name + ".ppm")
    png = os.path.join(SHOTS, name + ".png")
    if os.path.exists(ppm):
        os.remove(ppm)
    monitor(f"screendump {ppm}", wait=1.2)
    for _ in range(20):
        if os.path.exists(ppm) and os.path.getsize(ppm) > 0:
            break
        time.sleep(0.3)
    else:
        sys.exit("screendump produced nothing")
    from PIL import Image
    Image.open(ppm).save(png)
    os.remove(ppm)
    print(png)


def send_keys(keys, delay=0.06):
    for k in keys:
        monitor(f"sendkey {k}", wait=delay)


def type_text(text, delay=0.06):
    for ch in text:
        if ch in SHIFTED:
            k = SHIFTED[ch]
        elif ch in PLAIN:
            k = PLAIN[ch]
        elif ch.isupper():
            k = "shift-" + ch.lower()
        else:
            k = ch
        monitor(f"sendkey {k}", wait=delay)


def stop(quiet=False):
    if os.path.exists(SOCK):
        try:
            monitor("quit", wait=0.3)
        except Exception:
            pass
    if os.path.exists(PID):
        try:
            with open(PID) as f:
                os.kill(int(f.read().strip()), 9)
        except Exception:
            pass
        os.remove(PID)
    if os.path.exists(SOCK):
        os.remove(SOCK)
    if not quiet:
        print("stopped")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    verb, args = sys.argv[1], sys.argv[2:]
    if verb == "start":
        start(attach_disk="--install" in args)
    elif verb == "boot":
        start(from_disk=True)
    elif verb == "shot":
        shot(args[0] if args else "screen")
    elif verb == "key":
        send_keys(args)
    elif verb == "type":
        type_text(args[0])
    elif verb == "cmd":
        print(monitor(args[0], wait=1.0))
    elif verb == "stop":
        stop()
    else:
        sys.exit(__doc__)
