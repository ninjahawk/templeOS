#!/usr/bin/env python3
"""Copy a file out of the running TempleOS VM onto the host.

TempleOS can't write ext4 and Linux can't mount RedSea, so the file is read
inside the guest and pushed a byte at a time to the QEMU debug console, which
QEMU appends to console.log here. U.HC must already be included in the guest
session -- this drives its UDump.

  ./export.py ::/Home/Urim.Journal.TXT ../journal/Urim.Journal.TXT
"""
import sys
import time

import tos

BEGIN = "<<<BEGIN>>>\n"
END = "<<<END>>>"


def export(guest_path, host_path, settle=15):
    tos.con_mark()
    tos.type_text(f'UDump("{guest_path}");')
    tos.send_keys(["ret"])

    # The guest writes one OUT instruction per byte, so a large file takes a
    # while; wait for the end marker rather than guessing a duration.
    deadline = time.time() + 300
    out = ""
    while time.time() < deadline:
        time.sleep(3)
        out = tos.con_read()
        if END in out:
            break
    else:
        sys.exit("timed out waiting for the guest to finish dumping")

    if "<<<NOFILE>>>" in out:
        sys.exit(f"guest reports no such file: {guest_path}")
    if BEGIN not in out:
        sys.exit("no begin marker -- is U.HC included in the guest session?")

    body = out.split(BEGIN, 1)[1].rsplit(END, 1)[0]
    with open(host_path, "w") as f:
        f.write(body)
    print(f"{guest_path} -> {host_path} ({len(body)} bytes)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    export(sys.argv[1], sys.argv[2])
