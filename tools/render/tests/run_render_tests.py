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
import json
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
    # A named panel in a known place, so "crop to this thing" can be asserted
    # against a size nobody typed as a pixel rectangle.
    write(os.path.join(tmp, "Named.qml"), """
import QtQuick
Item {
    Rectangle { anchors.fill: parent; color: "#101010" }
    Rectangle {
        objectName: "panel"
        x: 20; y: 10; width: 60; height: 40
        color: "#ff3366"
    }
    Item { objectName: "sizeless" }
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

    # Reaching a state that is not the sandbox's default (issue #174):
    # --set can only assign, so calls need --eval/--script, and a state that
    # builds over time needs --wait-for.
    write(os.path.join(tmp, "State.qml"), """
import QtQuick
Item {
    id: root
    property color fill: "#101820"
    property int spawned: 0
    property bool ready: spawned >= 3
    function applyScenario(name) { fill = (name === "hot") ? "#ff3366" : "#00d9ff" }
    Timer { interval: 60; repeat: true; running: true; onTriggered: root.spawned++ }
    Rectangle { anchors.fill: parent; color: root.fill }
}
""")
    write(os.path.join(tmp, "setup.js"), 'applyScenario("hot");\nspawned = 1;\n')
    state = os.path.join(tmp, "State.qml")

    def centre_of(path):
        pixels, w, h = png_pixels(path)
        return pixels[(h // 2) * w + w // 2] if pixels else None

    out_eval = os.path.join(tmp, "eval.png")
    code, _, err = run(args.clayrender,
                       [state, "--out", out_eval, "--size", "60x40",
                        "--eval", 'applyScenario("hot")'])
    check("--eval calls into the scene", code == 0 and centre_of(out_eval) == (0xFF, 0x33, 0x66),
          f"exit {code} {centre_of(out_eval)}")

    out_script = os.path.join(tmp, "script.png")
    code, _, err = run(args.clayrender,
                       [state, "--out", out_script, "--size", "60x40",
                        "--script", os.path.join(tmp, "setup.js")])
    check("--script runs a file in the same context",
          code == 0 and centre_of(out_script) == (0xFF, 0x33, 0x66),
          f"exit {code} {centre_of(out_script)}")

    # --result: the value of each fragment, not just "it did not throw" (#207).
    def results_of(argv):
        code, out, err = run(args.clayrender, argv + ["--result", "-"])
        # The JSON array is written before the "shot.png (WxH)" line, so it is
        # everything up to and including the closing bracket.
        end = out.rfind("]")
        try:
            return code, json.loads(out[:end + 1]), err
        except ValueError:
            return code, None, out + err

    code, got, err = results_of([state, "--out", os.path.join(tmp, "res.png"),
                                 "--size", "60x40", "--eval", "spawned"])
    check("--result gives an expression its value, not null",
          code == 0 and got == [{"source": "spawned", "value": 0}], str(got)[:160])

    code, got, _ = results_of([state, "--out", os.path.join(tmp, "res.png"),
                               "--size", "60x40",
                               "--eval", 'applyScenario("hot")',
                               "--eval", "({ fill: String(fill), n: [1, 2] })"])
    check("--result keeps one entry per fragment, in command-line order",
          code == 0 and len(got) == 2 and got[0]["value"] is None
          and got[1]["value"]["n"] == [1, 2], str(got)[:200])

    # Several statements are not an expression, so the value is what the
    # fragment RETURNS - and a fragment that returns nothing answers null.
    code, got, _ = results_of([state, "--out", os.path.join(tmp, "res.png"),
                               "--size", "60x40",
                               "--eval", "var x = 2; return x * 3"])
    check("a multi-statement fragment answers with what it returns",
          code == 0 and got[0]["value"] == 6, str(got)[:160])

    code, got, _ = results_of([state, "--out", os.path.join(tmp, "res.png"),
                               "--size", "60x40", "--eval", "root"])
    check("a value JSON cannot carry comes back as a readable string",
          code == 0 and isinstance(got[0]["value"], str)
          and got[0]["value"] != "", str(got)[:160])

    # --result takes a different route into the scene, so the failure has to
    # be checked on that route too: a throw is exit 1 with the message, never
    # a null value quietly written into the array.
    code, out, err = run(args.clayrender,
                         [state, "--out", os.path.join(tmp, "res.png"),
                          "--size", "60x40", "--result", "-",
                          "--eval", "noSuchFunction()"])
    check("a broken --eval under --result still fails loudly",
          code == 1 and "noSuchFunction" in err and "value" not in out,
          f"exit {code} {err.strip()[:80]}")

    res_file = os.path.join(tmp, "result.json")
    code, _, err = run(args.clayrender,
                       [state, "--out", os.path.join(tmp, "res.png"),
                        "--size", "60x40", "--eval", "spawned",
                        "--result", res_file])
    check("--result <file> writes the same array to disk",
          code == 0 and json.load(open(res_file))[0]["value"] == 0,
          f"exit {code} {err.strip()[:80]}")

    # A sandbox with a sim clock, so --paused can be checked on the thing it
    # exists for: sim time that has already moved by the first --eval.
    write(os.path.join(tmp, "Clocked.qml"), """
import QtQuick
import Clayground.Lab
Item {
    SimClock { id: clock; sampleInterval: 0.1 }
    Rectangle { anchors.fill: parent; color: "#101820" }
}
""")
    clocked = os.path.join(tmp, "Clocked.qml")
    code, got, err = results_of([clocked, "--out", os.path.join(tmp, "clk.png"),
                                 "--size", "60x40", "--eval", "clock.time"])
    ticked = got[0]["value"] if got else None
    check("without --paused the frame ticker has already moved sim time",
          code == 0 and isinstance(ticked, (int, float)) and ticked > 0,
          f"exit {code} {ticked} {err.strip()[:80]}")

    code, got, err = results_of([clocked, "--out", os.path.join(tmp, "clk.png"),
                                 "--size", "60x40", "--paused",
                                 "--eval", "clock.time"])
    check("--paused means the first --eval sees clock.time === 0",
          code == 0 and got and got[0]["value"] == 0,
          f"exit {code} {str(got)[:120]} {err.strip()[:80]}")

    # Lab.runFlow through clayrender: the whole point of the three flags
    # together is that a lesson can be walked and asked what broke (#207).
    write(os.path.join(tmp, "Flowed.qml"), """
import QtQuick
import Clayground.Lab
Item {
    id: root
    property int taps: 0
    function flowActions() { return { "tap": () => { root.taps += 1; return root.taps } } }
    function flows() { return [demoFlow.flowId] }
    function startFlow(id) {
        if (id === demoFlow.flowId) { demoFlow.start(); return true }
        return false
    }
    function viewState() { return { taps: root.taps } }
    function applyViewState(s) { root.taps = s.taps }
    SimClock { id: clock; sampleInterval: 0.1 }
    Flow {
        id: demoFlow
        lab: root
        flowId: "demo"
        FlowStep { key: "tap"; dwell: 0.3; demo: [["tap"]] }
        FlowStep {
            key: "again"
            task: ({ "until": () => root.taps === 2, "solve": [["tap"]] })
        }
        FlowStep { key: "check"; dwell: 0.3; expect: () => root.taps === 2 }
    }
    Rectangle { anchors.fill: parent; color: "#101820" }
}
""")
    code, got, err = results_of([os.path.join(tmp, "Flowed.qml"), "--out",
                                 os.path.join(tmp, "flow.png"), "--size",
                                 "60x40", "--paused",
                                 "--eval", 'Lab.runFlow("demo")'])
    ran = got[0]["value"] if got else None
    check("Lab.runFlow walks a flow headless and reports a clean run",
          code == 0 and ran and ran["finished"] is True
          and ran["failedExpects"] == [] and ran["failedTasks"] == []
          and ran["unresolvedVerbs"] == [],
          f"exit {code} {str(ran)[:160]} {err.strip()[:80]}")

    # The order on the command line is the order of application - the parser
    # groups values per option, so this is the check that keeps it honest.
    out_a = os.path.join(tmp, "order_a.png")
    run(args.clayrender, [state, "--out", out_a, "--size", "60x40",
                          "--set", 'fill="#00ff00"',
                          "--eval", 'applyScenario("hot")'])
    out_b = os.path.join(tmp, "order_b.png")
    run(args.clayrender, [state, "--out", out_b, "--size", "60x40",
                          "--eval", 'applyScenario("hot")',
                          "--set", 'fill="#00ff00"'])
    check("--set and --eval apply in command-line order",
          centre_of(out_a) == (0xFF, 0x33, 0x66) and centre_of(out_b) == (0, 0xFF, 0),
          f"{centre_of(out_a)} then {centre_of(out_b)}")

    code, _, err = run(args.clayrender,
                       [state, "--out", os.path.join(tmp, "wait.png"),
                        "--size", "60x40", "--wait-for", "ready"])
    check("--wait-for waits for a state that builds over time", code == 0,
          f"exit {code} {err.strip()[:80]}")

    out_never = os.path.join(tmp, "never.png")
    code, _, err = run(args.clayrender,
                       [state, "--out", out_never, "--size", "60x40",
                        "--wait-for", "spawned > 100000",
                        "--wait-timeout", "400"])
    check("a state that never arrives exits 3 and writes no image",
          code == 3 and not os.path.exists(out_never), f"exit {code}")

    code, _, err = run(args.clayrender,
                       [state, "--out", os.path.join(tmp, "bad.png"),
                        "--size", "60x40", "--eval", "noSuchFunction()"])
    check("a broken --eval fails with the QML message, not a picture",
          code == 1 and "noSuchFunction" in err, f"exit {code} {err.strip()[:80]}")

    code, _, err = run(args.clayrender,
                       [state, "--out", os.path.join(tmp, "bad2.png"),
                        "--size", "60x40", "--wait-for", "noSuchThing.x",
                        "--wait-timeout", "400"])
    check("a broken --wait-for is an error, not a timeout",
          code == 1 and "noSuchThing" in err, f"exit {code} {err.strip()[:80]}")

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

    # --crop by name. The whole point is that nobody measured 20,10,60x40 by
    # hand: the panel says where it is, so the figure survives a resize.
    named = os.path.join(tmp, "Named.qml")
    out_named = os.path.join(tmp, "named.png")
    code, _, err = run(args.clayrender,
                       [named, "--out", out_named, "--size", "200x100",
                        "--crop", "panel"])
    check("crop to a named item", code == 0 and png_size(out_named) == (60, 40),
          f"exit {code} {png_size(out_named)} {err.strip()[:80]}")

    out_pad = os.path.join(tmp, "named-pad.png")
    code, _, _ = run(args.clayrender,
                     [named, "--out", out_pad, "--size", "200x100",
                      "--crop", "panel", "--crop-pad", "5"])
    check("crop-pad grows it on every side", png_size(out_pad) == (70, 50),
          str(png_size(out_pad)))

    # Padding off the edge is clipped rather than refused - the panel sits at
    # x=20,y=10, so 40 px of padding runs past two edges.
    out_clip = os.path.join(tmp, "named-clip.png")
    code, _, _ = run(args.clayrender,
                     [named, "--out", out_clip, "--size", "200x100",
                      "--crop", "panel", "--crop-pad", "40"])
    check("crop-pad clips at the viewport", png_size(out_clip) == (120, 90),
          str(png_size(out_clip)))

    # A name that matches nothing must not quietly become the whole frame: a
    # figure showing the wrong thing is worse than one that failed to render.
    code, _, err = run(args.clayrender,
                       [named, "--out", os.path.join(tmp, "unnamed.png"),
                        "--size", "200x100", "--crop", "noSuchPanel"])
    check("an unknown crop name fails loudly",
          code != 0 and "noSuchPanel" in err
          and not os.path.exists(os.path.join(tmp, "unnamed.png")),
          f"exit {code} {err.strip()[:100]}")

    code, _, err = run(args.clayrender,
                       [named, "--out", os.path.join(tmp, "sizeless.png"),
                        "--size", "200x100", "--crop", "sizeless"])
    check("a zero-sized item is refused, not cropped to nothing",
          code != 0 and "no size" in err, f"exit {code} {err.strip()[:100]}")

    code, _, err = run(args.clayrender,
                       [named, "--out", os.path.join(tmp, "padonly.png"),
                        "--size", "200x100", "--crop-pad", "5"])
    check("crop-pad without crop is refused",
          code != 0 and "nothing to grow" in err, err.strip()[:100])

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

    # Scene queries: the numeric answers that used to be pixel-squinting.
    write(os.path.join(tmp, "Scene3D.qml"), """
import QtQuick
import QtQuick3D
Item {
    width: 400; height: 300
    View3D {
        anchors.fill: parent
        camera: cam
        environment: SceneEnvironment { clearColor: "#101820"; backgroundMode: SceneEnvironment.Color }
        PerspectiveCamera { id: cam; position: Qt.vector3d(0, 0, 400) }
        DirectionalLight {}
        Model {
            objectName: "theCube"
            source: "#Cube"; pickable: true
            materials: PrincipledMaterial { baseColor: "#ffd93d" }
        }
    }
}
""")
    code, out, err = run(args.clayrender,
                         [os.path.join(tmp, "Scene3D.qml"), "--out",
                          os.path.join(tmp, "scene.png"), "--size", "400x300",
                          "--project", "0,0,0"])
    projected = json.loads(out.strip().splitlines()[0]) if out.strip() else {}
    check("--project puts the world origin at the viewport centre",
          projected.get("x") == 200 and projected.get("y") == 150, str(projected))

    code, out, _ = run(args.clayrender,
                       [os.path.join(tmp, "Scene3D.qml"), "--out",
                        os.path.join(tmp, "scene.png"), "--size", "400x300",
                        "--project", "0,0,900"])
    behind = json.loads(out.strip().splitlines()[0]) if out.strip() else {}
    check("a point behind the camera is not reported as inside the viewport",
          behind.get("behindCamera") is True
          and behind.get("insideViewport") is False, str(behind))

    code, out, _ = run(args.clayrender,
                       [os.path.join(tmp, "Scene3D.qml"), "--out",
                        os.path.join(tmp, "scene.png"), "--size", "400x300",
                        "--pick", "200,150"])
    picked = json.loads(out.strip().splitlines()[0]) if out.strip() else {}
    check("--pick names the object under the pixel and its colour",
          picked.get("hit") == "theCube" and "color" in picked, str(picked))

    # A selector answers for anything in the scene, hook or no hook (#177).
    write(os.path.join(tmp, "Mixed.qml"), """
import QtQuick
import QtQuick3D
Item {
    width: 400; height: 300
    Rectangle {
        objectName: "hud"; x: 10; y: 20; width: 120; height: 40
        color: "#ffd93d"
        property int score: 7
    }
    View3D {
        anchors.fill: parent
        environment: SceneEnvironment { clearColor: "#101820"; backgroundMode: SceneEnvironment.Color }
        PerspectiveCamera { position: Qt.vector3d(0, 0, 400) }
        DirectionalLight {}
        Model { objectName: "hero"; source: "#Cube"
                materials: PrincipledMaterial { baseColor: "#ff3366" } }
    }
}
""")
    mixed = os.path.join(tmp, "Mixed.qml")
    hud_json = os.path.join(tmp, "hud.json")
    model_json = os.path.join(tmp, "model.json")
    run(args.clayrender, [mixed, "--out", os.path.join(tmp, "mixed.png"),
                          "--size", "400x300",
                          "--dump", f"Rectangle={hud_json}",
                          "--dump", f"Model={model_json}"])
    hud = json.load(open(hud_json))
    # An inline property declaration gives the item a synthesised subclass
    # (QQuickRectangle_QML_42); selecting "Rectangle" has to see through that.
    check("a 2D item with no hook still answers a selector",
          len(hud) == 1 and hud[0]["via"] == "properties"
          and hud[0]["data"]["properties"]["score"] == 7,
          json.dumps(hud)[:120])
    model = json.load(open(model_json))
    check("a 3D object with no hook answers the same way",
          len(model) == 1 and model[0]["objectName"] == "hero",
          json.dumps(model)[:120])

    # A render-control window is never exposed, so its contentItem has to be
    # sized explicitly - otherwise every sandbox whose root anchors to its
    # parent collapses to 0x0 and renders black. That is most 2D examples.
    write(os.path.join(tmp, "Anchored.qml"), """
import QtQuick
Item {
    anchors.fill: parent
    Rectangle { anchors.fill: parent; color: "#00d9ff" }
}
""")
    out_anch = os.path.join(tmp, "anchored.png")
    run(args.clayrender, [os.path.join(tmp, "Anchored.qml"), "--out", out_anch,
                          "--size", "120x80"])
    check("a root anchored to its parent fills the viewport",
          centre_of(out_anch) == (0, 0xD9, 0xFF), str(centre_of(out_anch)))

    # A QML `function clayInspect()` is a metamethod whose metacall yields
    # nothing usable, and a bare-name lookup would let every child of the same
    # file answer for it. Both failure modes are silent, hence this check.
    write(os.path.join(tmp, "Hooked.qml"), """
import QtQuick
Item {
    objectName: "owner"
    function clayInspect() { return { who: "owner", score: 42 } }
    Rectangle { objectName: "kid"; width: 10; height: 10; color: "#ffd93d" }
}
""")
    hooked_json = os.path.join(tmp, "hooked.json")
    run(args.clayrender, [os.path.join(tmp, "Hooked.qml"), "--out",
                          os.path.join(tmp, "hooked.png"), "--size", "60x40",
                          "--dump", f"Item={hooked_json}"])
    hooked = json.load(open(hooked_json))
    owner = [e for e in hooked if e.get("objectName") == "owner"]
    check("a QML-declared clayInspect() answers for its own object",
          len(owner) == 1 and owner[0]["via"] == "hook"
          and owner[0]["data"]["score"] == 42, json.dumps(hooked)[:160])

    kid_json = os.path.join(tmp, "kid.json")
    run(args.clayrender, [os.path.join(tmp, "Hooked.qml"), "--out",
                          os.path.join(tmp, "hooked.png"), "--size", "60x40",
                          "--dump", f"Rectangle={kid_json}"])
    kid = json.load(open(kid_json))
    check("a child does not answer with its parent's hook",
          len(kid) == 1 and kid[0]["via"] == "properties",
          json.dumps(kid)[:160])

    # The sandbox can be named the way the dojo names it, and only once (#200).
    out_sbx = os.path.join(tmp, "sbx.png")
    code, _, err = run(args.clayrender,
                       ["--sbx", os.path.join(tmp, "Flat.qml"), "--out", out_sbx,
                        "--size", "120x80"])
    check("--sbx renders the same as the positional argument",
          code == 0 and centre_of(out_sbx) == (0, 0xD9, 0xFF),
          f"exit {code} {err.strip()[:80]}")

    code, _, err = run(args.clayrender,
                       [os.path.join(tmp, "Flat.qml"),
                        "--sbx", os.path.join(tmp, "Flat.qml"),
                        "--out", os.path.join(tmp, "twice.png")])
    check("naming the sandbox twice is an error, not a guess",
          code == 1 and "twice" in err, f"exit {code} {err.strip()[:80]}")

    # Prefs isolation (#200): what a render persists must not outlive it, or a
    # scripted theme flip leaves the next dojo session dark.
    write(os.path.join(tmp, "Prefs.qml"), """
import QtQuick
import QtQuick.LocalStorage
Item {
    id: root
    property string seen: "<none>"
    property var handle: null
    function db() {
        if (!handle) {
            handle = LocalStorage.openDatabaseSync("clayrender-prefs-check", "0.1", "check", 10000)
            handle.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS kv(key TEXT UNIQUE, value TEXT)') })
        }
        return handle
    }
    function remember(v) {
        db().transaction(function(tx) {
            tx.executeSql('INSERT OR REPLACE INTO kv VALUES (?,?)', ['theme', String(v)]) })
    }
    function clayInspect() { return { seen: root.seen } }
    Component.onCompleted: db().transaction(function(tx) {
        var rs = tx.executeSql('SELECT value FROM kv WHERE key=?', ['theme'])
        if (rs.rows.length === 1) root.seen = rs.rows.item(0).value
    })
}
""")
    probe = os.path.join(tmp, "Prefs.qml")
    shot = os.path.join(tmp, "prefs.png")

    def seen_by(extra):
        report = os.path.join(tmp, "prefs.json")
        if os.path.exists(report):
            os.remove(report)
        run(args.clayrender, [probe, "--out", shot, "--size", "60x40",
                              "--dump", f"Item={report}"] + extra)
        found = json.load(open(report))
        return found[0]["data"]["seen"] if found else None

    seen_by(["--eval", 'remember("dark")'])
    check("an isolated render forgets what it stored", seen_by([]) == "<none>",
          str(seen_by([])))

    store = os.path.join(tmp, "kept-prefs")
    seen_by(["--prefs", store, "--eval", 'remember("dark")'])
    check("--prefs <dir> keeps a store across runs",
          seen_by(["--prefs", store]) == "dark",
          str(seen_by(["--prefs", store])))
    check("the opt-in store is the only one that got written",
          os.path.isdir(os.path.join(store, "Databases")), store)

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
