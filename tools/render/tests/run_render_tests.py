#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""clayrender checks (issue #164).

Renders fixture sandboxes and asserts on the produced PNGs and exit codes:
0 = rendered clean, 1 = never loaded, 2 = rendered but the scene complained.

clayrender needs a real graphics session - it renders through the GPU into a
window that is never shown. Where that is unavailable (bare ssh, CI without a
session) the whole run reports SKIP (exit 77) rather than a false failure.
"""

import argparse
import os
import struct
import subprocess
import sys
import tempfile
import zlib

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok, detail))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


def png_size(path):
    """Width/height straight from the IHDR - no image library needed."""
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def png_pixels(path):
    """Decode an 8-bit RGB/RGBA PNG into a list of (r, g, b) rows-major."""
    with open(path, "rb") as f:
        data = f.read()
    pos, idat, width, height, depth, color = 8, b"", 0, 0, 0, 0
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if ctype == b"IHDR":
            width, height, depth, color = struct.unpack(">IIBB", body[:10])
        elif ctype == b"IDAT":
            idat += body
        pos += 12 + length
    if depth != 8 or color not in (2, 6):
        return None, 0, 0
    channels = 3 if color == 2 else 4
    raw = zlib.decompress(idat)
    stride = width * channels
    out, prev = [], bytearray(stride)
    at = 0
    for _ in range(height):
        filt = raw[at]
        line = bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if filt == 1:
                line[i] = (line[i] + a) & 0xFF
            elif filt == 2:
                line[i] = (line[i] + b) & 0xFF
            elif filt == 3:
                line[i] = (line[i] + (a + b) // 2) & 0xFF
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        for x in range(width):
            o = x * channels
            out.append((line[o], line[o + 1], line[o + 2]))
        prev = line
    return out, width, height


def write(path, text):
    with open(path, "w") as f:
        f.write(text)


def run(binary, args, cwd=None):
    proc = subprocess.run([binary] + args, capture_output=True, text=True,
                          cwd=cwd, timeout=120)
    return proc.returncode, proc.stdout, proc.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clayrender", required=True)
    args = ap.parse_args()

    tmp = tempfile.mkdtemp(prefix="clayrender_test_")

    # A sandbox with nothing but a known colour, so a pixel assertion is exact.
    write(os.path.join(tmp, "Flat.qml"), """
import QtQuick
Item {
    property color fill: "#00d9ff"
    Rectangle { anchors.fill: parent; color: parent.fill }
}
""")
    write(os.path.join(tmp, "Broken.qml"), """
import QtQuick
Item { Component.onCompleted: thisFunctionDoesNotExist() }
""")
    write(os.path.join(tmp, "Syntax.qml"), """
import QtQuick
Item { this is not qml }
""")

    out = os.path.join(tmp, "flat.png")
    code, _, err = run(args.clayrender,
                       [os.path.join(tmp, "Flat.qml"), "--out", out,
                        "--size", "120x80"])

    if code == 1 and "graphics session" in err:
        print("SKIP  clayrender cannot reach a GPU here:\n      " + err.strip())
        return 77

    ok = check("flat sandbox renders", code == 0, err.strip()[:120])
    if ok:
        check("size honoured", png_size(out) == (120, 80), str(png_size(out)))
        pixels, w, h = png_pixels(out)
        centre = pixels[(h // 2) * w + w // 2] if pixels else None
        check("pixels are the colour the sandbox asked for",
              centre == (0, 0xD9, 0xFF), str(centre))

    # --set must reach the running scene, not just be accepted.
    out_set = os.path.join(tmp, "set.png")
    code, _, err = run(args.clayrender,
                       [os.path.join(tmp, "Flat.qml"), "--out", out_set,
                        "--size", "120x80", "--set", 'fill="#ff3366"'])
    check("--set applies before capture", code == 0, err.strip()[:120])
    pixels, w, h = png_pixels(out_set)
    centre = pixels[(h // 2) * w + w // 2] if pixels else None
    check("--set changed the pixels", centre == (0xFF, 0x33, 0x66), str(centre))

    # Crop and scale, applied in that order.
    out_crop = os.path.join(tmp, "crop.png")
    code, _, _ = run(args.clayrender,
                     [os.path.join(tmp, "Flat.qml"), "--out", out_crop,
                      "--size", "200x100", "--crop", "50,25,100,50",
                      "--scale", "0.5"])
    check("crop then scale", code == 0 and png_size(out_crop) == (50, 25),
          str(png_size(out_crop)))

    # A crop outside the viewport is an error, not a silently clamped picture
    # of the wrong thing.
    code, _, err = run(args.clayrender,
                       [os.path.join(tmp, "Flat.qml"), "--out",
                        os.path.join(tmp, "nope.png"), "--size", "100x100",
                        "--crop", "500,500,10,10"])
    check("crop outside the viewport fails loudly",
          code != 0 and "outside" in err, err.strip()[:120])

    # The three outcomes must be distinguishable by exit code alone.
    code, _, err = run(args.clayrender,
                       ["/does/not/exist.qml", "--out", os.path.join(tmp, "x.png")])
    check("missing sandbox exits 1", code == 1, f"exit {code}")

    code, _, err = run(args.clayrender,
                       [os.path.join(tmp, "Syntax.qml"), "--out",
                        os.path.join(tmp, "x.png")])
    check("QML that does not parse exits 1 with the error on stderr",
          code == 1 and "Syntax.qml" in err, f"exit {code}")

    out_broken = os.path.join(tmp, "broken.png")
    code, _, err = run(args.clayrender,
                       [os.path.join(tmp, "Broken.qml"), "--out", out_broken])
    check("a scene that throws at runtime exits 2 and still writes the image",
          code == 2 and os.path.exists(out_broken), f"exit {code}")

    # Statelessness is the point: several renders at once must not interfere.
    procs = [subprocess.Popen(
        [args.clayrender, os.path.join(tmp, "Flat.qml"),
         "--out", os.path.join(tmp, f"par{i}.png"), "--size", "80x60"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) for i in range(3)]
    codes = [p.wait() for p in procs]
    check("three renders in parallel all succeed", codes == [0, 0, 0], str(codes))

    failed = [name for name, ok, _ in CHECKS if not ok]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
