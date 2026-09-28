#!/usr/bin/env python3
"""Talk to the test VM's QMP socket: screenshots, keys, mouse.

The VNC/noVNC path is for looking at and clicking the desktop by hand; this is
for scripted checks that do not need a browser in the loop (and for a reliable
way to see what the guest is doing when the desktop is a black screen).

Usage:
  vm-shot.sh out.png                 screenshot the guest display
  vm-shot.sh --key ctrl-alt-f2       send a key chord
  vm-shot.sh --type 'hello'          type a string
  vm-shot.sh --click 640,360         click at x,y (needs --release for the
                                      matching button release)
"""

import json
import os
import socket
import sys
import time

QMP = os.environ.get("GUEST_BOX_QMP", "/tmp/guest-box-qmp.sock")


class Qmp:
    def __init__(self, path):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect(path)
        self.file = self.sock.makefile("rwb")
        self.greeting = self._read()
        self.cmd("qmp_capabilities")

    def _read(self):
        while True:
            line = self.file.readline()
            if not line:
                raise RuntimeError("QMP closed the connection")
            msg = json.loads(line)
            if "event" in msg:
                continue
            return msg

    def cmd(self, name, **args):
        self.file.write(
            (json.dumps({"execute": name, "arguments": args}) + "\n").encode()
        )
        self.file.flush()
        reply = self._read()
        if "error" in reply:
            raise SystemExit(f"QMP {name} failed: {reply['error']}")
        return reply.get("return")


def screenshot(path, qmp):
    # ppm is the only format QEMU writes without extra tooling.
    tmp = path + ".ppm"
    if os.path.exists(tmp):
        os.unlink(tmp)
    qmp.cmd("screendump", filename=tmp)
    for _ in range(50):
        if os.path.exists(tmp) and os.path.getsize(tmp) > 0:
            break
        time.sleep(0.1)
    else:
        raise SystemExit("screendump produced nothing")

    # Convert PPM to PNG without a dependency: QEMU's screendump is P6, and
    # PNG needs zlib, which is in the stdlib too.
    import struct
    import zlib

    with open(tmp, "rb") as f:
        data = f.read()
    if not data.startswith(b"P6"):
        raise SystemExit("unexpected screendump format")
    # header: P6 <w> <h> <maxval> then a single whitespace byte
    fields, pos = [], 2
    while len(fields) < 3:
        while data[pos : pos + 1].isspace():
            pos += 1
        if data[pos : pos + 1] == b"#":
            while data[pos : pos + 1] != b"\n":
                pos += 1
            continue
        start = pos
        while not data[pos : pos + 1].isspace():
            pos += 1
        fields.append(int(data[start:pos]))
    pos += 1
    width, height, _ = fields
    pixels = data[pos : pos + width * height * 3]

    raw = b"".join(b"\x00" + pixels[y * width * 3 : (y + 1) * width * 3] for y in range(height))

    def chunk(kind, payload):
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 6))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png)
    os.unlink(tmp)
    print(f"{path} {width}x{height}")


KEYMAP = {
    " ": "spc", "-": "minus", "=": "equal", "[": "bracket_left",
    "]": "bracket_right", ";": "semicolon", "'": "apostrophe",
    "`": "grave_accent", "\\": "backslash", ",": "comma", ".": "dot",
    "/": "slash", "\n": "ret", "\t": "tab", "ctrl": "ctrl", "alt": "alt",
    "shift": "shift", "esc": "esc",
}


def key_name(ch):
    if ch in KEYMAP:
        return KEYMAP[ch]
    if ch.isalpha():
        return ch
    if ch.isdigit():
        return ch
    raise SystemExit(f"no key name for {ch!r}")


def key_event(name):
    # QEMU 11's send-key takes key *objects*; the bare-string form is gone.
    return {"type": "qcode", "data": name}


def main():
    args = sys.argv[1:]
    qmp = Qmp(QMP)

    if args and args[0] == "--key":
        chord = args[1]
        keys = [key_event(key_name(c)) for c in chord.split("-")]
        qmp.cmd("send-key", keys=keys)
        print("sent", args[1])
        return

    if args and args[0] == "--type":
        text = args[1]
        shifted = [c for c in text if c.isupper()]
        for ch in text:
            name = key_name(ch.lower())
            keys = [key_event("shift"), key_event(name)] if ch.isupper() else [key_event(name)]
            qmp.cmd("send-key", keys=keys)
            # 20ms is not enough for the emulated keyboard to see separate
            # presses; the guest ends up reading them as one chord.
            time.sleep(0.12)
        print("typed", len(text), "keys", "with", len(shifted), "shifted")
        return

    if args and args[0] == "--click":
        x, y = (int(v) for v in args[1].split(","))
        # The VM has a USB tablet, so absolute coordinates are what it wants.
        qmp.cmd(
            "input-send-event",
            events=[
                {
                    "type": "abs",
                    "data": {
                        "axis": "x",
                        "value": x * 0x7FFF // 1920,
                    },
                },
                {
                    "type": "abs",
                    "data": {
                        "axis": "y",
                        "value": y * 0x7FFF // 1080,
                    },
                },
                {"type": "btn", "data": {"button": "left", "state": "down"}},
                {"type": "btn", "data": {"button": "left", "state": "up"}},
            ],
        )
        print("clicked", x, y)
        return

    screenshot(args[0] if args else "screenshot.png", qmp)


if __name__ == "__main__":
    main()
