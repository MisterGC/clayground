#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Crew Gym run — end-to-end verification of the inspector protocol v3.

Drives the gym sandbox exclusively through the file-based protocol an agent
uses (.clay/inspect/), covering: attach, log stream, scenarios + rearm,
time control (pause/step/scale), synthetic input, trace, and auto-flag.

Default mode copies the gym into a temp dir and spawns clayliveloader
offscreen (CI-safe, source tree stays clean). --attach <sandbox-dir> runs
the same checks against an already-running loader/dojo instance.
"""

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok, detail))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


class Inspect:
    def __init__(self, inspect_dir):
        self.dir = inspect_dir
        self.request_path = os.path.join(inspect_dir, "request.json")
        self.response_path = os.path.join(inspect_dir, "response.json")

    def state(self):
        try:
            with open(os.path.join(self.dir, "state.json")) as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError):
            return {}

    def wait_phase(self, phase, timeout=15.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.state().get("phase") == phase:
                return True
            time.sleep(0.1)
        return False

    def request(self, payload, timeout=10.0):
        rid = str(uuid.uuid4())[:8]
        payload = dict(payload)
        payload["id"] = rid
        with open(self.request_path, "w") as f:
            json.dump(payload, f)
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                with open(self.response_path) as f:
                    resp = json.load(f)
                if resp.get("requestId") == rid:
                    return resp
            except (OSError, json.JSONDecodeError):
                pass
            time.sleep(0.05)
        raise TimeoutError(f"no response for {payload.get('action')} ({rid})")

    def eval(self, exprs, timeout=10.0):
        resp = self.request({"action": "eval", "eval": exprs}, timeout)
        return resp.get("eval", {})

    def eval1(self, expr):
        return self.eval([expr]).get(expr)


def wait_for(cond, timeout=10.0, interval=0.1):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if cond():
            return True
        time.sleep(interval)
    return False


def run(insp, sandbox_dir, attended):
    # -- 1: attach --------------------------------------------------------
    ok = insp.wait_phase("ready", timeout=20)
    st = insp.state()
    check("attach: phase ready", ok, f"phase={st.get('phase')}")
    check("attach: protocolVersion >= 3", st.get("protocolVersion", 0) >= 3,
          f"protocolVersion={st.get('protocolVersion')}")
    check("attach: runId present", bool(st.get("runId")),
          f"runId={st.get('runId')}")

    # -- 2: baseline + log stream ----------------------------------------
    snap = insp.request({"action": "snapshot"})
    check("snapshot: has rootProperties", "rootProperties" in snap)

    # -- 2b: status envelope ---------------------------------------------
    # Every response carries it, whatever the action was — that is what lets
    # an agent tell a live instance from a stale artefact.
    env = snap.get("status")
    check("status: envelope on a response", isinstance(env, dict), str(env))
    if isinstance(env, dict):
        check("status: alive + rootLoaded true on a loaded scene",
              env.get("alive") is True and env.get("rootLoaded") is True,
              f"alive={env.get('alive')} rootLoaded={env.get('rootLoaded')}")
        check("status: generation >= 1 after first load",
              isinstance(env.get("generation"), int) and env["generation"] >= 1,
              f"generation={env.get('generation')}")
        check("status: sandbox path reported",
              str(env.get("sandbox", "")).endswith("Sandbox.qml"),
              f"sandbox={env.get('sandbox')}")
        check("status: no renderedAt without a capture",
              "renderedAt" not in env, f"renderedAt={env.get('renderedAt')}")
    # An unknown action is still a response, so it still carries the envelope.
    bogus = insp.request({"action": "no_such_action"})
    check("status: envelope even on an error response",
          isinstance(bogus.get("status"), dict) and "error" in bogus,
          f"error={bogus.get('error')}")

    # renderedAt is the moment the image was grabbed — the replacement for
    # deleting the PNG first to prove a dead instance did not fake a capture.
    shot = insp.request({"action": "snapshot", "screenshot": True}, timeout=15)
    if "screenshot" in shot:
        check("status: renderedAt stamped on a capture",
              bool(shot.get("status", {}).get("renderedAt")),
              f"renderedAt={shot.get('status', {}).get('renderedAt')}")
    else:
        print("SKIP  status: renderedAt (no capture in this environment: "
              f"{shot.get('screenshotError')})")
    check("snapshot: scenarios listed",
          snap.get("scenarios") == ["start", "near-coin", "error-probe"],
          str(snap.get("scenarios")))
    insp.eval(["console.log('gym-marker')"])
    log_path = os.path.join(insp.dir, "log.jsonl")

    def marker_logged():
        try:
            with open(log_path) as f:
                return any("gym-marker" in ln for ln in f)
        except OSError:
            return False
    check("log.jsonl: eval marker streamed", wait_for(marker_logged, 5))

    # -- 2c: batch --------------------------------------------------------
    # Several steps per round trip. A step is a whole request - it carries its
    # own "action" - so anything that works standalone works as a step.
    b = insp.request({"action": "batch", "steps": [
        {"action": "eval", "eval": ["gym.score = 5"]},
        {"action": "eval", "eval": ["gym.score"]},
        {"action": "time", "paused": True},
        {"action": "time", "paused": False},
    ]})
    bs = b.get("steps", [])
    check("batch: one result per step", len(bs) == 4 and b.get("stepsRun") == 4,
          f"{len(bs)} results, stepsRun={b.get('stepsRun')}")
    check("batch: no failure on a clean run",
          "error" not in b and "failedStep" not in b, f"error={b.get('error')}")
    if len(bs) == 4:
        check("batch: step results are the plain per-action responses",
              bs[1].get("eval", {}).get("gym.score") == 5,
              f"step1={bs[1].get('eval')}")
        check("batch: steps ran in order (pause then resume)",
              bs[2].get("paused") is True and bs[3].get("paused") is False,
              f"{bs[2].get('paused')} -> {bs[3].get('paused')}")
        check("batch: envelope once for the batch, generation per step",
              isinstance(b.get("status"), dict)
              and all(isinstance(s.get("generation"), int) for s in bs)
              and all(s.get("action") for s in bs),
              f"generations={[s.get('generation') for s in bs]}")

    # A batch that silently continued past a failure would be worse than no
    # batch at all: the third step must not have run.
    bf = insp.request({"action": "batch", "steps": [
        {"action": "eval", "eval": ["gym.score = 1"]},
        {"action": "no_such_action"},
        {"action": "eval", "eval": ["gym.score = 99"]},
    ]})
    check("batch: stops at the first failing step",
          bf.get("failedStep") == 1 and len(bf.get("steps", [])) == 2,
          f"failedStep={bf.get('failedStep')} results={len(bf.get('steps', []))}")
    check("batch: failure also surfaces as a plain top-level error",
          "step 1" in bf.get("error", "")
          and "Unknown action" in bf.get("error", ""), f"error={bf.get('error')}")
    check("batch: nothing after the failing step ran",
          insp.eval1("gym.score") == 1, f"gym.score={insp.eval1('gym.score')}")

    bn = insp.request({"action": "batch",
                       "steps": [{"input": {"key": {"key": "V"}}}]})
    check("batch: a step without an action fails instead of silently "
          "snapshotting",
          bn.get("failedStep") == 0
          and "action" in bn.get("steps", [{}])[0].get("error", ""),
          f"error={bn.get('error')}")

    # -- 2d: the canonical batch -----------------------------------------
    # "toggle a mode, capture, toggle back, capture" - five tool calls before,
    # one now. Asserted on the mode the captures actually saw.
    tog = insp.request({"action": "batch", "steps": [
        {"action": "input", "key": {"key": "V"}},
        {"action": "snapshot", "screenshot": True},
        {"action": "input", "key": {"key": "V"}},
        {"action": "snapshot", "screenshot": True},
    ]}, timeout=25)
    ts = tog.get("steps", [])
    on = ts[1].get("rootProperties", {}).get("debugMode") if len(ts) == 4 else None
    off = ts[3].get("rootProperties", {}).get("debugMode") if len(ts) == 4 else None
    check("batch: toggle, capture, toggle back, capture in one round trip",
          len(ts) == 4 and on is True and off is False,
          f"steps={len(ts)} debugMode {on} -> {off} error={tog.get('error')}")

    # The recipe the skill hands out. It puts a blocking step (waitForRoot)
    # and a reload in the middle of a batch - which is exactly where an
    # interleaved second request would show up.
    rb = insp.request({"action": "batch", "steps": [
        {"action": "reload", "scenario": "near-coin"},
        {"action": "waitForRoot", "timeoutMs": 8000},
        {"action": "snapshot", "eval": ["player.xWu"]},
    ]}, timeout=25)
    rs = rb.get("steps", [])
    rpx = rs[2].get("eval", {}).get("player.xWu") if len(rs) == 3 else None
    check("batch: reload + waitForRoot + snapshot in one round trip",
          len(rs) == 3 and rs[1].get("ready") is True
          and rpx is not None and abs(rpx - 10) < 0.6,
          f"steps={len(rs)} player.xWu={rpx} error={rb.get('error')}")
    check("batch: a mid-batch reload shows up in the per-step generations",
          len(rs) == 3 and rs[2]["generation"] > rs[0]["generation"],
          f"generations={[s.get('generation') for s in rs]}")

    # -- 3: scenario via reload + rearm ----------------------------------
    gen_before = insp.request({"action": "eval"}).get("status", {}).get("generation")
    insp.request({"action": "reload", "scenario": "near-coin", "rearm": True})
    insp.request({"action": "waitForRoot", "timeoutMs": 8000}, timeout=12)
    insp.wait_phase("ready", timeout=10)
    px = insp.eval1("player.xWu")
    check("scenario near-coin: player placed", px is not None and abs(px - 10) < 0.6,
          f"player.xWu={px}")

    # A successful reload advances the generation, which is how an agent knows
    # the scene it is measuring is the one it just changed.
    gen_after = insp.request({"action": "eval"}).get("status", {}).get("generation")
    check("status: generation advances across a reload",
          isinstance(gen_before, int) and isinstance(gen_after, int)
          and gen_after == gen_before + 1,
          f"{gen_before} -> {gen_after}")

    # -- 4: time control --------------------------------------------------
    insp.eval(["applyScenario('start')"])
    resp = insp.request({"action": "time", "paused": True})
    check("time: paused", resp.get("paused") is True)
    x1 = insp.eval1("enemy.xWu")
    time.sleep(0.5)
    x2 = insp.eval1("enemy.xWu")
    check("time pause: enemy frozen", x1 == x2, f"{x1} vs {x2}")

    resp = insp.request({"action": "time", "step": 30})
    check("time step: 30 frames acked", resp.get("stepped") == 30,
          f"stepped={resp.get('stepped')}")
    x3 = insp.eval1("enemy.xWu")
    moved = None if (x2 is None or x3 is None) else abs(x3 - x2)
    check("time step: exact distance (30 * 2/60 Wu)",
          moved is not None and abs(moved - 1.0) < 0.01, f"moved={moved}")

    insp.request({"action": "time", "paused": False, "scale": 0.1})
    xa = insp.eval1("enemy.xWu")
    time.sleep(2.0)
    xb = insp.eval1("enemy.xWu")
    slow = None if (xa is None or xb is None) else abs(xb - xa)
    check("time scale 0.1: ~10% speed", slow is not None and 0.2 < slow < 0.7,
          f"moved={slow} (normal would be ~4.0)")
    insp.request({"action": "time", "scale": 1.0})

    # -- 4a2: scene queries — asking the renderer instead of the pixels (#165)
    resp = insp.request({"action": "tree", "select": "Rectangle", "limit": 3})
    items = resp.get("items", [])
    check("tree: a selector returns only matching items",
          len(items) > 0 and all(i.get("type") == "Rectangle" for i in items),
          f"{len(items)} items: {[i.get('type') for i in items]}")

    resp = insp.request({"action": "tree", "select": "NoSuchTypeAnywhere"})
    check("tree: a selector that matches nothing returns an empty list, not the whole tree",
          resp.get("items") == [] and "tree" not in resp, str(resp.get("items")))

    # No type in the gym implements clayInspect(), so the honest answer is an
    # empty list - not an error, and not a fallback to everything.
    resp = insp.request({"action": "inspect", "select": "lines"})
    check("inspect: a scene with no hooks answers empty rather than erroring",
          resp.get("inspect") == [] and not resp.get("error"),
          f"inspect={resp.get('inspect')} error={resp.get('error')}")

    # inspect and tree used to disagree about what exists: an item without a
    # clayInspect() hook was invisible to inspect, so "is my player there"
    # depended on which action you happened to pick (#177).
    resp = insp.request({"action": "inspect", "objectName": "player"})
    found = resp.get("inspect", [])
    check("inspect: an item with no hook still answers when asked for by name",
          len(found) == 1 and found[0].get("via") == "properties",
          str(found)[:140])

    resp = insp.request({"action": "inspect", "select": "RectBoxBody"})
    bodies = resp.get("inspect", [])
    check("inspect: a selector finds every item of a type, hook or not",
          len(bodies) >= 3
          and {b.get("objectName") for b in bodies} >= {"player", "enemy", "coin"},
          f"{len(bodies)}: {[b.get('objectName') for b in bodies]}")

    resp = insp.request({"action": "inspect"})
    everything = resp.get("inspect", [])
    check("inspect: without a selector only hooked objects answer",
          all(e.get("via") == "hook" for e in everything),
          f"{len(everything)} entries, via={[e.get('via') for e in everything][:5]}")

    # pick works without a View3D: the colour question is always answerable.
    geom = insp.eval(["gym.mapFromItem(player, 0, 0).x",
                      "gym.mapFromItem(player, 0, 0).y",
                      "player.width", "player.height"])
    px = geom["gym.mapFromItem(player, 0, 0).x"] + geom["player.width"] / 2
    py = geom["gym.mapFromItem(player, 0, 0).y"] + geom["player.height"] / 2
    resp = insp.request({"action": "pick", "x": px, "y": py}, timeout=15)
    check("pick: reports the colour rendered at that pixel",
          isinstance(resp.get("color"), str) and resp["color"].startswith("#"),
          f"color={resp.get('color')} at {px:.0f},{py:.0f}")

    resp = insp.request({"action": "project", "world": [0, 0, 0]})
    check("project: says plainly that a 2D scene has no View3D",
          "View3D" in (resp.get("error") or ""), str(resp.get("error")))

    # -- 4b: capture — framing, settle, diff (#167, #169) ----------------
    # One request does what used to be five tool calls: settle, grab, crop,
    # scale, write where the caller asked, compare against a baseline.
    insp.eval(["applyScenario('start')"])
    shots = os.path.join(sandbox_dir, "shots")
    insp.request({"action": "time", "paused": True})

    full = insp.request({"action": "snapshot", "screenshot": True}, timeout=15)
    fsize = full.get("screenshotSize", {})
    check("capture: response reports the size actually produced",
          fsize.get("width", 0) > 0 and fsize.get("height", 0) > 0, str(fsize))

    # Device pixels per logical pixel, measured rather than assumed — every
    # expected size below is derived from it, so the checks hold on a retina
    # screen too.
    root_w = insp.eval1("gym.width") or 0
    dpr = fsize.get("width", 0) / root_w if root_w else 1.0

    target = os.path.join(shots, "look.png")
    resp = insp.request({"action": "snapshot",
                         "screenshot": {"path": target}}, timeout=15)
    check("capture: written to the caller's own path",
          resp.get("screenshot") == target and os.path.exists(target),
          f"screenshot={resp.get('screenshot')} err={resp.get('screenshotError')}")

    gen_before = insp.request({"action": "snapshot"}).get("status", {}).get("generation")
    resp = insp.request({"action": "snapshot",
                         "screenshot": {"path": "shots/relative.png"}}, timeout=15)
    check("capture: a relative path resolves under .clay/inspect",
          os.path.exists(os.path.join(sandbox_dir, ".clay", "inspect",
                                      "shots", "relative.png")),
          f"screenshot={resp.get('screenshot')}")

    # The dojo watches the whole sandbox tree and skips only .clay/, so a
    # capture written beside the sandbox reloads the scene - and then every
    # later step measures a different one. Caught for real by a three-step
    # batch whose own first capture reloaded it mid-flight.
    time.sleep(1.5)
    gen_after = insp.request({"action": "snapshot"}).get("status", {}).get("generation")
    check("capture: writing a capture does not reload the scene",
          gen_before == gen_after, f"generation {gen_before} -> {gen_after}")

    resp = insp.request({"action": "snapshot",
                         "screenshot": {"path": os.path.join(shots, "crop.png"),
                                        "crop": [10, 20, 200, 100],
                                        "scale": 0.5}}, timeout=15)
    size = resp.get("screenshotSize", {})
    check("capture: crop before scale gives the exact pixel size",
          size.get("width") == 100 and size.get("height") == 50,
          f"{size} err={resp.get('screenshotError')}")

    # "Show me this thing" is the real intent; a pixel rectangle was only ever
    # how it had to be expressed.
    geom = insp.eval(["gym.mapFromItem(player, 0, 0).x",
                      "gym.mapFromItem(player, 0, 0).y",
                      "player.width", "player.height"])
    exp_x = geom["gym.mapFromItem(player, 0, 0).x"] * dpr
    exp_y = geom["gym.mapFromItem(player, 0, 0).y"] * dpr
    exp_w = geom["player.width"] * dpr
    exp_h = geom["player.height"] * dpr
    resp = insp.request({"action": "snapshot",
                         "screenshot": {"path": os.path.join(shots, "player.png"),
                                        "crop": {"objectName": "player"}}}, timeout=15)
    size = resp.get("screenshotSize", {})
    check("capture: crop by objectName frames that item",
          abs(size.get("width", 0) - exp_w) <= 1
          and abs(size.get("height", 0) - exp_h) <= 1,
          f"{size} expected ~{exp_w:.0f}x{exp_h:.0f} "
          f"err={resp.get('screenshotError')}")

    resp = insp.request({"action": "snapshot",
                         "screenshot": {"crop": {"objectName": "no_such_item"}}},
                        timeout=15)
    check("capture: an unresolvable crop is an error, not a full-frame grab",
          "screenshot" not in resp and "no_such_item" in resp.get("screenshotError", ""),
          f"err={resp.get('screenshotError')}")

    resp = insp.request({"action": "snapshot",
                         "screenshot": {"crop": [99999, 99999, 10, 10]}}, timeout=15)
    check("capture: a crop outside the viewport is an error, not a clamp",
          "screenshot" not in resp and bool(resp.get("screenshotError")),
          f"err={resp.get('screenshotError')}")

    # Settle: the caller must be able to tell "quiet" from "gave up while it
    # was still moving". Time is paused here, so the picture is standing still.
    resp = insp.request({"action": "snapshot", "screenshot": True,
                         "settle": True}, timeout=20)
    s = resp.get("settle", {})
    check("settle: a still scene reports settled with a wait time",
          s.get("settled") is True and isinstance(s.get("waitedMs"), int),
          str(s))

    # Motion has to be *in frame* to be measurable, so drive the player (whose
    # visibility the objectName crop above already proved) rather than the
    # enemy, which patrols off the right edge of the viewport.
    insp.request({"action": "time", "paused": False})
    insp.request({"action": "input",
                  "gamepad": {"axisX": -1.0, "durationMs": 1500}})
    resp = insp.request({"action": "snapshot", "screenshot": True,
                         "settle": {"timeoutMs": 800}}, timeout=20)
    s = resp.get("settle", {})
    check("settle: a scene still in motion says so instead of pretending",
          s.get("settled") is False and s.get("lastDelta", 0) > 0, str(s))
    time.sleep(0.8)
    insp.eval(["applyScenario('start')"])
    insp.request({"action": "time", "paused": True})

    # Diff: visual regression at lab scale.
    baseline = os.path.join(shots, "baseline.png")
    insp.request({"action": "snapshot", "screenshot": {"path": baseline}},
                 timeout=15)
    resp = insp.request({"action": "snapshot", "diff": baseline}, timeout=15)
    d = resp.get("diff", {})
    check("diff: an unchanged scene against its baseline is zero",
          d.get("delta") == 0 and d.get("changedPixels") == 0,
          f"{d} err={resp.get('diffError')}")

    insp.eval(["player.color = '#ffd93d'"])
    resp = insp.request({"action": "snapshot", "diff": baseline}, timeout=15)
    d = resp.get("diff", {})
    b = d.get("changedBounds", {})
    check("diff: a changed scene reports a non-zero delta",
          d.get("delta", 0) > 0 and d.get("changedPixels", 0) > 0, str(d))
    check("diff: changed bounds land on the item that changed",
          abs(b.get("x", -999) - exp_x) <= 2 and abs(b.get("y", -999) - exp_y) <= 2
          and abs(b.get("width", 0) - exp_w) <= 2
          and abs(b.get("height", 0) - exp_h) <= 2,
          f"{b} expected ~{exp_x:.0f},{exp_y:.0f} {exp_w:.0f}x{exp_h:.0f}")
    insp.eval(["player.color = '#00d9ff'"])

    resp = insp.request({"action": "snapshot",
                         "diff": os.path.join(shots, "no_such_baseline.png")},
                        timeout=15)
    check("diff: a missing baseline is an error, not a silent skip",
          "diff" not in resp and bool(resp.get("diffError")),
          f"err={resp.get('diffError')}")

    insp.request({"action": "time", "paused": False})

    # -- 5: synthetic input + trace --------------------------------------
    # Movement check drives AWAY from the coin: the vendored qml-box2d does
    # not re-fire begin-contact for a fixture pair that already met once, so
    # the scoring run below must be the coin's first player crossing.
    insp.eval(["applyScenario('start')"])
    px1 = insp.eval1("player.xWu")
    insp.request({"action": "input",
                  "gamepad": {"axisX": -1.0, "durationMs": 600}})
    time.sleep(0.9)
    px2 = insp.eval1("player.xWu")
    check("input: player moved (gamepad axis)", px1 is not None
          and px2 is not None and px2 < px1 - 0.5, f"{px1} -> {px2}")

    insp.eval(["applyScenario('near-coin')"])
    tstart = insp.request({"action": "trace", "start": True,
                           "watch": ["player.xWu", "gym.score"],
                           "interval": 100, "stopWhen": "score > 0",
                           "timeout": 10000})
    check("trace: start reports wall-clock epoch",
          tstart.get("epochMs", 0) > 0, f"epochMs={tstart.get('epochMs')}")
    insp.request({"action": "input",
                  "gamepad": {"axisX": 1.0, "durationMs": 2500}})

    def trace_done():
        try:
            with open(insp.response_path) as f:
                resp = json.load(f)
            return resp.get("action") == "trace" and "stoppedBy" in resp
        except (OSError, json.JSONDecodeError):
            return False
    check("trace: completed", wait_for(trace_done, 15))
    with open(insp.response_path) as f:
        tresp = json.load(f)
    check("trace: stopped by condition (coin collected)",
          tresp.get("stoppedBy") == "condition",
          f"stoppedBy={tresp.get('stoppedBy')}")
    try:
        with open(os.path.join(insp.dir, "trace.jsonl")) as f:
            meta = json.loads(f.readline())
    except (OSError, json.JSONDecodeError):
        meta = {}
    check("trace: jsonl meta line carries matching epoch",
          meta.get("meta") == "trace_start"
          and meta.get("epochMs") == tstart.get("epochMs"),
          f"meta={meta.get('meta')} epochMs={meta.get('epochMs')}")
    score = insp.eval1("gym.score")
    check("input: coin collected via gameplay", score == 1, f"score={score}")

    # -- 5b: view state survives a reload --------------------------------
    # Move the user's camera/zoom, then force a reload. The outgoing root's
    # viewState() is captured and re-applied (after the rearmed scenario) once
    # the new root is ready, so the user keeps their place across agent fixes.
    insp.eval(["camX = 123", "camY = 456", "zoom = 2.5"])
    insp.request({"action": "reload"})
    insp.request({"action": "waitForRoot", "timeoutMs": 8000}, timeout=12)
    insp.wait_phase("ready", timeout=10)
    snap = insp.request({"action": "snapshot"})
    vs = snap.get("viewState")
    check("view_state_restore: snapshot carries viewState key",
          isinstance(vs, dict) and "camX" in vs, f"viewState={vs}")
    check("view_state_restore: camera restored after reload",
          isinstance(vs, dict) and vs.get("camX") == 123
          and vs.get("camY") == 456 and vs.get("zoom") == 2.5,
          f"viewState={vs}")

    # -- 6: rearm across a real file-watch reload ------------------------
    if attended:
        print("SKIP  rearm-on-edit (attended mode leaves your files alone)")
    else:
        sbx = os.path.join(sandbox_dir, "Sandbox.qml")
        with open(sbx, "a") as f:
            f.write("\n// gym-touch\n")
        ok = wait_for(lambda: insp.state().get("phase") == "reloading", 10) \
            or insp.state().get("phase") == "ready"
        insp.request({"action": "waitForRoot", "timeoutMs": 8000}, timeout=12)
        insp.wait_phase("ready", timeout=10)
        px = insp.eval1("player.xWu")
        score = insp.eval1("gym.score")
        check("rearm: scenario reapplied after edit",
              px is not None and abs(px - 10) < 0.6 and score == 0,
              f"player.xWu={px} score={score}")

    # -- 6b: a broken save must not take the scene down (#170) -----------
    # The exact situation from the issue: a file is saved mid-edit while an
    # import is still missing. That is an ordinary two-second window, and it
    # used to end the session. It must now be a no-op with an error report.
    if attended:
        print("SKIP  reload-survives-error (attended mode leaves your files alone)")
    else:
        def try_request(payload, timeout=8.0):
            try:
                return insp.request(payload, timeout)
            except TimeoutError:
                return None

        sbx = os.path.join(sandbox_dir, "Sandbox.qml")
        with open(sbx) as f:
            good = f.read()

        # Mark the live root. A runtime-set value cannot survive a real
        # reload, so reading it back later proves it is the *same* root.
        insp.eval(["gym.score = 77"])
        marker = insp.eval1("gym.score")
        check("reload_survives_error: marker set on live root", marker == 77,
              f"gym.score={marker}")

        with open(sbx, "w") as f:
            f.write(good.replace("import Clayground.World",
                                 "import Clayground.World\n"
                                 "import Clayground.NotAModuleYet", 1))
        ok = insp.wait_phase("load_error", timeout=15)
        check("reload_survives_error: phase load_error", ok,
              f"phase={insp.state().get('phase')}")

        # (a) still alive, and the *previous* root is still the one on screen
        resp = try_request({"action": "eval", "eval": ["gym.score"]})
        check("reload_survives_error: loader still answering", resp is not None)
        still = (resp or {}).get("eval", {}).get("gym.score")
        check("reload_survives_error: previous root still live",
              still == 77, f"gym.score={still} (expected 77)")

        # (b) the failure is reported, not swallowed
        snap = try_request({"action": "snapshot"}) or {}
        errs = " ".join(snap.get("errors", []))
        check("reload_survives_error: error reported",
              "NotAModuleYet" in errs,
              f"errors={snap.get('errors', [])[-2:]}")

        # (c) the next save recovers - no relaunch, no re-navigation
        with open(sbx, "w") as f:
            f.write(good)
        ok = insp.wait_phase("ready", timeout=20)
        after = insp.eval1("gym.score") if ok else None
        check("reload_survives_error: next save recovers the scene",
              ok and after == 0,
              f"phase={insp.state().get('phase')} gym.score={after}")

    # -- 7: auto-flag on runtime error -----------------------------------
    for f in glob.glob(os.path.join(insp.dir, "autoflag_*")):
        os.remove(f)
    insp.request({"action": "reload", "scenario": "error-probe"})
    insp.request({"action": "waitForRoot", "timeoutMs": 8000}, timeout=12)

    def autoflag_written():
        return len(glob.glob(os.path.join(insp.dir, "autoflag_*.json"))) > 0
    ok = check("auto-flag: artifact after runtime error",
               wait_for(autoflag_written, 8))
    if ok:
        with open(sorted(glob.glob(os.path.join(insp.dir, "autoflag_*.json")))[-1]) as f:
            flag = json.load(f)
        check("auto-flag: carries trigger + diagnostics",
              "trigger" in flag and "logTail" in flag and "tree" in flag)

    # -- 8: errors action -------------------------------------------------
    # The error-probe scenario above raised a genuine QML TypeError; asking
    # for it must return something real, with the file and line it came from.
    errs = insp.request({"action": "errors"})
    diags = errs.get("errors", []) + errs.get("warnings", [])
    probe = [d for d in diags
             if "_thisFunctionDoesNotExist" in d.get("text", "")]
    check("errors: reports the deliberate QML error", len(probe) > 0,
          f"{len(diags)} diagnostics, none matching" if not probe else "")
    if probe:
        d = probe[0]
        check("errors: carries file and line",
              d.get("file", "").endswith("Sandbox.qml") and d.get("line", 0) > 0,
              f"file={d.get('file')} line={d.get('line')}")
        check("errors: tagged with a generation",
              isinstance(d.get("generation"), int), f"gen={d.get('generation')}")

    gen_now = errs.get("status", {}).get("generation", 0)
    future = insp.request({"action": "errors", "sinceGeneration": gen_now + 5})
    check("errors: sinceGeneration filters",
          future.get("errorCount") == 0 and future.get("warningCount") == 0,
          f"errors={future.get('errorCount')} warnings={future.get('warningCount')}")

    failed = [c for c in CHECKS if not c[1]]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed")
    return len(failed) == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--loader", help="path to clayliveloader binary")
    ap.add_argument("--attach", metavar="SANDBOX_DIR",
                    help="attach to a running instance serving this sandbox dir")
    ap.add_argument("--keep", action="store_true",
                    help="keep the temp workdir for inspection")
    args = ap.parse_args()

    if args.attach:
        sandbox_dir = os.path.abspath(args.attach)
        insp = Inspect(os.path.join(sandbox_dir, ".clay", "inspect"))
        ok = run(insp, sandbox_dir, attended=True)
        sys.exit(0 if ok else 1)

    if not args.loader:
        ap.error("--loader is required unless --attach is used")

    src = os.path.dirname(os.path.abspath(__file__))
    workdir = tempfile.mkdtemp(prefix="crew-gym-")
    sandbox_dir = os.path.join(workdir, "gym")
    shutil.copytree(src, sandbox_dir,
                    ignore=shutil.ignore_patterns(".clay", "__pycache__"))

    env = dict(os.environ)
    env.setdefault("QT_QPA_PLATFORM", "offscreen")
    # The loader resolves Clayground plugins via a cwd-relative "qml" import
    # path, so run it from the binary's directory (build/bin).
    loader_bin = os.path.abspath(args.loader)
    loader_dir = os.path.dirname(loader_bin)
    env.setdefault("QML2_IMPORT_PATH", os.path.join(loader_dir, "qml"))
    proc = subprocess.Popen(
        [loader_bin, "--sbx", os.path.join(sandbox_dir, "Sandbox.qml")],
        env=env, cwd=loader_dir,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        insp = Inspect(os.path.join(sandbox_dir, ".clay", "inspect"))
        ok = run(insp, sandbox_dir, attended=False)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        if args.keep:
            print(f"workdir kept: {workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
