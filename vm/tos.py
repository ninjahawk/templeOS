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
CONSOLE = os.path.join(HERE, "console.log")

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


def start(from_disk=False, attach_disk=True, memory=1024):
    stop(quiet=True)
    for stale in (SOCK, PID):
        if os.path.exists(stale):
            os.remove(stale)
    cmd = [
        "qemu-system-x86_64",
        "-accel", "tcg",                    # no /dev/kvm in this container
        "-m", str(memory),
        "-smp", "1",
        # 'max' exposes RDRAND/RDSEED, which TCG backs with the host entropy
        # pool. Terry only ever had a PRNG; the oracle needs a real one.
        "-cpu", "max",
        "-machine", "pc",
        "-vga", "std",
        "-display", "none",
        "-rtc", "base=localtime",
        "-monitor", f"unix:{SOCK},server,nowait",
        "-pidfile", PID,
        # Bytes written to port 0xE9 land in this file. TempleOS has no serial
        # driver, but it does have OutU8, so this is a usable text channel out
        # of the guest -- the only one, given it can't write ext4 and Linux
        # can't read RedSea.
        "-debugcon", f"file:{CONSOLE}",
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


HOLD_MS = 1  # sendkey's default 100ms hold made typing a file take minutes


def _blast(cmds, delay=0.02):
    """Push many monitor commands down one connection without reading back.

    Reopening a socket and waiting on a read timeout per keystroke made typing
    a source file take minutes; this keeps it to roughly `delay` per key.
    """
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(15)
    s.connect(SOCK)
    time.sleep(0.2)
    for c in cmds:
        s.sendall((c + "\n").encode())
        time.sleep(delay)
    time.sleep(0.3)
    s.close()


def keyname(ch):
    if ch in SHIFTED:
        return SHIFTED[ch]
    if ch in PLAIN:
        return PLAIN[ch]
    if ch.isupper():
        return "shift-" + ch.lower()
    return ch


def send_keys(keys, delay=0.06):
    _blast([f"sendkey {k} {HOLD_MS}" for k in keys], delay)


def type_text(text, delay=0.02):
    _blast([f"sendkey {keyname(c)} {HOLD_MS}" for c in text], delay)


def type_file(path, delay=0.02):
    """Type a whole file into the editor over a single monitor connection."""
    with open(path) as f:
        body = f.read()
    cmds = []
    for line in body.split("\n"):
        cmds += [f"sendkey {keyname(c)} {HOLD_MS}" for c in line]
        cmds.append(f"sendkey ret {HOLD_MS}")
    t0 = time.time()
    _blast(cmds, delay)
    print(f"  typed {len(body.splitlines())} lines in {time.time()-t0:.0f}s")


def _frame(ignore_top=16):
    """Grab the framebuffer below the title bar as raw pixels."""
    from PIL import Image
    os.makedirs(SHOTS, exist_ok=True)
    ppm = os.path.join(SHOTS, ".idle.ppm")
    if os.path.exists(ppm):
        os.remove(ppm)
    monitor(f"screendump {ppm}", wait=1.0)
    for _ in range(25):
        if os.path.exists(ppm) and os.path.getsize(ppm) > 0:
            break
        time.sleep(0.3)
    else:
        return None
    im = Image.open(ppm).convert("L")
    im = im.crop((0, ignore_top, im.width, im.height))
    data = im.tobytes()
    os.remove(ppm)
    return data


def wait_idle(stable_for=8, timeout=900, tol=0.002):
    """Block until the screen stops changing, i.e. TempleOS wants input.

    Installing TempleOS means answering prompts separated by unpredictable
    stretches of work -- partitioning and zeroing take minutes under TCG and
    vary by host. Fixed sleeps either race or waste time, so watch the
    framebuffer instead. The title bar carries a clock and an FPS counter so it
    is cropped off, and the tolerance is wide enough to ignore a blinking
    cursor but not a progress bar.
    """
    prev = None
    steady = None
    deadline = time.time() + timeout
    while time.time() < deadline:
        cur = _frame()
        if cur is None:
            time.sleep(2)
            continue
        if prev is not None and len(prev) == len(cur):
            diff = sum(1 for a, b in zip(prev, cur) if a != b)
            if diff / len(cur) <= tol:
                steady = steady or time.time()
                if time.time() - steady >= stable_for:
                    return True
            else:
                steady = None
        prev = cur
        time.sleep(2)
    return False


def con_mark():
    """Remember how long console.log is now.

    Never truncate it: QEMU keeps its own write offset on that fd, so emptying
    the file just leaves a sparse hole and the next output appears after a wall
    of NULs. Marking an offset and reading forward is the safe equivalent.
    """
    n = os.path.getsize(CONSOLE) if os.path.exists(CONSOLE) else 0
    with open(CONSOLE + ".off", "w") as f:
        f.write(str(n))
    return n


def con_read():
    off = 0
    if os.path.exists(CONSOLE + ".off"):
        off = int(open(CONSOLE + ".off").read().strip() or 0)
    if not os.path.exists(CONSOLE):
        return ""
    with open(CONSOLE, "rb") as f:
        f.seek(off)
        return f.read().decode(errors="replace")


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
    elif verb == "typefile":
        type_file(args[0])
    elif verb == "waitidle":
        secs = float(args[0]) if args else 8
        if not wait_idle(stable_for=secs):
            sys.exit("timed out waiting for the screen to settle")
    elif verb == "mark":
        print(con_mark())
    elif verb == "con":
        sys.stdout.write(con_read())
    elif verb == "cmd":
        print(monitor(args[0], wait=1.0))
    elif verb == "stop":
        stop()
    else:
        sys.exit(__doc__)
