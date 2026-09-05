---
layout: docs
title: clayrender
permalink: /docs/manual/clayrender/
---

`clayrender` renders one sandbox to a PNG and exits. No Dojo, no session, no
protocol:

```bash
clayrender Sandbox.qml --out shot.png --size 1600x1000
```

That is the whole loop for "put it in this state and show me". Because there is
no long-lived process, several variants render in parallel, nothing can hand
back a stale or dead instance's picture, and a full 3D sandbox takes well under
a second.

Use the [Dojo]({{ site.baseurl }}/docs/manual/dojo/) instead when you need
interaction, hot reload, or anything genuinely stateful.

## Reaching the state you want to look at

`--set` assigns properties after the sandbox loads and before it is captured,
so you go straight to the state under test instead of clicking your way there.
Assignments are evaluated in the root's own QML context, which means QML `id`s
and dotted paths both work:

```bash
clayrender labs/electronics-101/Sandbox.qml --out board.png \
    --set 'root.showLabels=false' \
    --set 'demoLoader.currentDemo="LineBatchDemo.qml"'
```

A value that parses as JSON keeps its type (`true`, `42`, `[1,2]`, `"text"`);
anything else is treated as a string, so `--set title=hello` does what it looks
like. Quoting explicitly always wins.

`--set` **assigns**; it cannot call. When the state comes from a function, or
takes a few statements, use `--eval` — or `--script` for a whole file:

```bash
clayrender labs/electronics-101/Sandbox.qml --out board.png \
    --eval 'applyScenario("parallel")' \
    --script setup.js
```

Both run in the same context `--set` uses, and `--set`, `--eval` and `--script`
apply **in the order they appear on the command line** — so
`--set paused=true --eval 'step()'` and the reverse do different things, as they
should.

Some states are not reached the moment you ask for them: a spawn takes a few
frames, a level loads, an animation has to finish. `--wait-for` holds the
capture until the scene says it is there:

```bash
clayrender Sandbox.qml --out shot.png \
    --eval 'spawnWave()' --wait-for 'enemies.length === 12'
```

If the expression never becomes truthy within `--wait-timeout` (3 s by
default), `clayrender` exits **3 and writes no image** — a picture of a state
that was never reached is worse than no picture. A *broken* expression is a
different thing: that is exit 1 with the QML error, so a typo never reads as
"the state never happened".

## Getting an answer back

`--eval` and `--script` change the scene; `--result` says what they came out
to. It writes a JSON array with one entry per fragment, in the order they ran:

```bash
clayrender labs/electronics-101/Sandbox.qml --out board.png --paused \
    --result - --eval 'Lab.scenario' --eval 'toggleSwitch(2); return simOf(4).i'
```

```json
[
    { "source": "Lab.scenario", "value": "led-basic" },
    { "source": "toggleSwitch(2); return simOf(4).i", "value": 0.005149224103621227 }
]
```

`-` means stdout; anything else is a file. `source` is the fragment as the
command line spelled it — for `--script`, the path.

A fragment that parses as an *expression* answers with what it evaluates to,
so `clock.time` is a number rather than `null`. A fragment of several
statements answers with what it `return`s, and with `null` when it returns
nothing. A value JSON cannot carry — a QML object, a function, `NaN` — comes
back as its `String()`, because an unreadable answer is worse than an
approximate one.

Values are captured **where the fragment runs**, which is before `--wait-for`,
before `--settle` and before the capture. An `--eval` written after
`--wait-for` on the command line still runs first, so it reports the state
*before* the wait; put the assertion in the `--wait-for` expression instead and
read the exit code.

## Watching it move

`--result` answers at one moment; `--trace` answers at every frame. It
evaluates an expression in the root's context once per rendered frame — from
the first `--set`/`--eval`/`--script` through `--frames`, `--wait-for` and
`--settle`, up to and including the frame the picture shows — and writes the
samples to `--trace-out`. That is how a question about *motion* gets answered
without a Dojo session: did the professor stay in frame for the whole flight,
how did the camera's goal pose change while a step ran.

```bash
clayrender labs/kits/professor/Sandbox.qml --out x.png \
    --eval 'prof.appear()' --eval 'prof.travelTo(Qt.vector3d(6,0,4))' \
    --trace 'view3d.mapFrom3DScene(prof.headAnchor).x' \
    --trace 'prof.travelling' --trace-out flight.jsonl \
    --wait-for '!prof.travelling' --wait-timeout 8000
```

```
{"epochMs":1788600672519,"meta":"trace_start","sampling":"frame","watch":["view3d.mapFrom3DScene(prof.headAnchor).x","prof.travelling"]}
{"frame":0,"t":0,"values":{"prof.travelling":true,"view3d.mapFrom3DScene(prof.headAnchor).x":640}}
{"frame":1,"t":19,"values":{"prof.travelling":true,"view3d.mapFrom3DScene(prof.headAnchor).x":640}}
...
{"frame":49,"t":2847,"values":{"prof.travelling":true,"view3d.mapFrom3DScene(prof.headAnchor).x":2533.457275390625}}
{"frame":50,"t":2906,"values":{"prof.travelling":false,"view3d.mapFrom3DScene(prof.headAnchor).x":2531.55224609375}}
```

Fifty-two frames later the professor has landed — and at 2533 px on a
1280-wide viewport, its head left the picture on the way. That is a fact
about the sandbox's default camera, and the single frame `--out` wrote could
never have told you.

The file is JSONL in the shape of the Dojo inspector's `trace.jsonl`: a meta
line naming what was watched, then one object per rendered frame with the
`frame` index, `t` in milliseconds since the first sample and `values` keyed by
the expression as the command line spelled it. `-` writes it to stdout. The
one difference from the inspector's trace is the clock — the inspector samples
on a timer, `clayrender` samples the frames it draws, so a sample is never a
moment between two frames.

Values follow the `--result` rules: numbers, strings and booleans as they are,
objects and arrays as JSON (a `vector3d` comes back as `{x, y, z}`), and
anything JSON cannot carry as its `String()`. An expression that throws yields
`{"error": "..."}` for that frame and nothing else; a trace is an observer,
and one that aborted the run would turn *what happened* into *nothing
happened*. Exit codes are unaffected by tracing, and the file is written a line
at a time — so a `--wait-for` that exits 3 leaves the trace of how the state
was *not* reached, which is usually the evidence you wanted.

`--trace` needs `--trace-out`, and the other way round: both together or it is
a usage error.

## Starting paused

`--paused` sets `Clayground.paused` before the sandbox root is created, so no
frame ticker ever starts:

```bash
clayrender labs/sensor-fusion-101/Sandbox.qml --out shot.png \
    --paused --result - --eval 'clock.time'      # 0, not "some wall clock"
```

Without it, the frames rendered at load have already moved sim time by the
first `--eval` — which is why recipes used to open with
`clock._frameTicker.running = false`, and why one that forgot produced a
different number on every machine. A stepped run advances the clock itself
(`Lab.runFlow()`, `clock._advance(1 / 60)`), and `--paused` is what stops
anything else from advancing it underneath.

## Running a lab's flow

`Lab.runFlow(flowId)` walks a lab's guided flow with nobody watching and
reports what broke — the headless half of *every flow is also a test*:

```bash
clayrender labs/electronics-101/Sandbox.qml --out /tmp/x.png \
    --paused --result - --eval 'Lab.runFlow("led-basics")'
```

```json
{ "flowId": "led-basics", "steps": 5292, "finished": true,
  "unresolvedVerbs": [], "failedTasks": [], "failedExpects": [] }
```

It forces `pacing: "auto"`, advances the clock in 1/60 s steps and performs
every learner task itself, so a whole lesson runs in a second or two. A verb
the lab does not have lands in `unresolvedVerbs` (a missing verb otherwise
fails silently), a `FlowStep.expect` that does not hold lands in
`failedExpects` with its step key, and `finished: false` means the step bound
was hit rather than the end — never a hang. While it runs, `Lab.headless` is
set: the narrator hides, the professor stays put and no narration audio is
decoded.

## Getting a usable image

| Option | Effect |
|---|---|
| `--size WxH` | viewport size (default 1280x800) |
| `--crop x,y,w,h` | cut out a region, applied **before** scaling |
| `--crop <objectName>` | cut out *that item*, wherever it currently is |
| `--crop-pad px` | grow the crop on every side, clipped to the viewport |
| `--scale f` / `--width px` | scale the result to something readable |
| `--frames n` | render n frames before capturing |
| `--settle` | capture once the picture stops changing |

`--settle` compares successive frames rather than asking the animation system,
so it covers QML animations, physics and shader-driven motion alike. A scene
with continuous motion never settles: `clayrender` says so on stderr, captures
anyway, and leaves the judgement to you.

**Crop to a name, not to a rectangle.** What a caller means is *show me this
thing*; a pixel rectangle is only how that had to be said before, and one
measured by hand goes wrong the moment a panel moves, the window resizes or
the UI scale changes — silently, into a picture of the wrong corner.

```bash
clayrender labs/electronics-101/Sandbox.qml --out palette.png \
    --crop palette --crop-pad 8
```

Four comma-separated numbers are read as a rectangle; anything else is an
`objectName`. Give the items a figure might ever want a name — that is what
makes the picture survive the next layout change.

Both forms fail loudly rather than approximating: a crop that falls outside
the viewport, a name that matches nothing, and a named item with no size are
all errors with no image written. Padding is the one thing that clips instead,
since running off the edge only means a smaller margin on that side.

## Asking the renderer instead of the pixels

If the question is numeric — *is that arrowhead full size? did the second line
get drawn at all? where does this world point land?* — query the scene rather
than squinting at an image.

```bash
clayrender Sandbox.qml --out shot.png \
    --dump lines=lines.json \
    --project 0,0,0 \
    --pick 200,150
```

- `--dump <type>=<file>` writes what the renderer actually received for every
  object of that type: for `lines` (shorthand for `LineBatch3D`) that is the
  resolved world-space points, widths, colours, style ids and bounds of every
  line in every batch. Types with a `clayInspect()` hook answer in their own
  terms (`"via": "hook"`); everything else answers from its properties —
  geometry, app-level state — as `"via": "properties"`. So `--dump
  Rectangle=hud.json` works on a type nobody wrote a hook for.
- `--project x,y,z` maps a world point to screen pixels through the live
  camera, and tells you whether it is inside the viewport or behind the camera
  (which are different failures).
- `--pick x,y` reports what is under that pixel — object, distance, world
  position, normal — plus the colour actually rendered there. Note that
  *instanced* geometry (a `LineBatch3D`) is not pickable in Qt Quick 3D; use
  `--dump` for those.
- `--anchor x,y,w,h` answers what a framed *region* is about, which is the
  question behind an annotation: the item or 3D node at its centre, with
  `objectName`, `type`, `source` file and world position. It walks up from an
  anonymous internal item to the nearest thing declared in a QML file on disk,
  and it says `"resolved": false` with a reason rather than guessing when
  nothing meaningful is there. Same machinery the dojo's annotation surface
  uses, so this is how you check an anchor without a session. A resolved
  anchor also carries `now` — where it projects *back* to on screen. An anchor
  that lands somewhere other than where you framed is a bad anchor, and this
  is the only place that is visible without a running instance.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | rendered, no complaints |
| 1 | never loaded (missing file, QML that does not parse) — nothing written |
| 2 | rendered, but the scene logged warnings or errors — image still written |
| 3 | `--wait-for` never came true — no image, but a `--trace` is still written |

Exit 2 exists because a runtime `ReferenceError` does not stop a component from
instantiating: a broken scene can produce a perfectly plausible picture. The
image is written so you can look at it, and the exit code stops a script from
treating it as success.

## What it needs

Rendering goes through the real GPU into a window that is never shown, so it
does not steal focus — but it does need a graphics session. It will **not**
work under `QT_QPA_PLATFORM=offscreen` or over a bare ssh connection: Qt Quick
3D content comes out blank there. On a machine without a session, the
`clayrender` test suite reports SKIP rather than failing.
