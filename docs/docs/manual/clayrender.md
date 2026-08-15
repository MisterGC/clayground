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
