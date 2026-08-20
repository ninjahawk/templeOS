#!/usr/bin/env python3
"""Type an ASCII string into the VM via QEMU sendkey, one keystroke at a time.

    python3 type.py 'Dir;'
    python3 type.py '"Hello from HolyC!\\n";'

Does not press Enter -- follow with: python3 mon.py "sendkey ret"
"""
import sys
import time

from mon import send

# unshifted non-alphanumeric keys -> QEMU key names
PLAIN = {
    " ": "spc", "\n": "ret", "-": "minus", "=": "equal",
    "[": "bracket_left", "]": "bracket_right", ";": "semicolon",
    "'": "apostrophe", "`": "grave_accent", "\\": "backslash",
    ",": "comma", ".": "dot", "/": "slash",
}

# shifted symbols -> the key you shift
SHIFTED = {
    "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7",
    "*": "8", "(": "9", ")": "0", "_": "minus", "+": "equal",
    "{": "bracket_left", "}": "bracket_right", ":": "semicolon",
    '"': "apostrophe", "~": "grave_accent", "|": "backslash",
    "<": "comma", ">": "dot", "?": "slash",
}


def keystrokes(text):
    out = []
    for ch in text:
        if ch.isupper():
            out.append("sendkey shift-" + ch.lower())
        elif ch in SHIFTED:
            out.append("sendkey shift-" + SHIFTED[ch])
        elif ch in PLAIN:
            out.append("sendkey " + PLAIN[ch])
        elif ch.isalnum():
            out.append("sendkey " + ch)
    return out


if __name__ == "__main__":
    for k in keystrokes(sys.argv[1]):
        send([k], wait=0.08)
        time.sleep(0.04)
