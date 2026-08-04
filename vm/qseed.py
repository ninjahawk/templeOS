#!/usr/bin/env python3
"""Load a quantum seed into the running TempleOS VM.

TempleOS 5.03 has no network stack, so the seed is fetched here and typed in
through the QEMU monitor as a UrimSeed() call.

ANU's generator measures vacuum fluctuation of the electromagnetic field --
outcomes that standard quantum mechanics holds are not determined by any prior
state. That is a stronger claim than RDRAND can make: RDRAND is a deterministic
generator reseeded from thermal noise, and under emulation it is really the
host kernel's entropy pool. Both are unpredictable; only one is indeterminate.

random.org (atmospheric radio noise) is the fallback. It is classical, so it is
labelled honestly as such and the journal will say which was used.

  ./qseed.py            fetch and load a seed
  ./qseed.py --print    fetch and print, load nothing
"""
import json
import subprocess
import sys
import urllib.request

import tos

TIMEOUT = 25


def _get(url):
    with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
        return r.read().decode()


def from_anu():
    """Quantum: vacuum fluctuation measured at the Australian National Univ."""
    d = json.loads(_get("https://qrng.anu.edu.au/API/jsonI.php?length=4&type=uint16"))
    if not d.get("success"):
        raise RuntimeError("anu reported failure")
    v = 0
    for x in d["data"]:
        v = (v << 16) | (int(x) & 0xFFFF)
    return v, "anu-qrng(quantum-vacuum)"


def from_random_org():
    """Classical fallback: atmospheric radio noise."""
    txt = _get("https://www.random.org/integers/?num=4&min=0&max=65535"
               "&col=1&base=10&format=plain&rnd=new")
    v = 0
    for line in txt.split():
        v = (v << 16) | (int(line) & 0xFFFF)
    return v, "random.org(atmospheric)"


def fetch():
    errors = []
    for src in (from_anu, from_random_org):
        try:
            return src()
        except Exception as e:          # network, rate limit, malformed reply
            errors.append(f"{src.__name__}: {e}")
    sys.exit("no external entropy source reachable:\n  " + "\n  ".join(errors))


if __name__ == "__main__":
    value, label = fetch()
    print(f"{label} -> {value:#018x}")
    if "--print" in sys.argv:
        sys.exit(0)
    tos.type_text(f'UrimSeed(0x{value:016X},"{label}");')
    tos.send_keys(["ret"])
    print("loaded into the VM")
