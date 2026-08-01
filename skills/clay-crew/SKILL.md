---
name: clay-crew
description: >
  Collaborate on and verify Clayground QML sandboxes through the Dojo's
  built-in inspector. Use this skill when working on Clayground QML
  applications and needing to verify results, diagnose load failures or
  crashes, read user flag feedback, search for entities, trace behavior,
  or collaborate on visual output. Triggers when the context involves
  .clay/inspect, .clay/crew, flagInfo, ClayInspector, canvas.find, trace,
  or the user mentions verifying sandbox output.
---

# Clay Crew — AI-Agent Collaboration for Clayground

The inspector runs inside the live loader and exposes sandbox state
through a file-based protocol under `.clay/` in the sandbox's directory.
This skill covers attaching to a running instance, the full command set,
the lifecycle/failure artifacts, and the human collaboration channel.

## Prerequisites and attach

Both entrypoints are first-class — pick by situation:

- **Shared session (collaboration mode):** the user already runs
  `claydojo` with the sandbox open. The dojo spawns `clayliveloader` as a
  child; the child serves `.clay/inspect/` in the sandbox dir. Attach to
  it — you and the user look at the same instance.
- **Autonomous (headless mode):** no display or no running instance —
  launch your own loader:

```bash
# Desktop (display available)
./build/bin/clayliveloader --sbx path/to/Sandbox.qml

# Headless / autonomous agent (no display)
QT_QPA_PLATFORM=offscreen ./build/bin/clayliveloader --sbx path/to/Sandbox.qml
```

`.clay/` is created automatically in the sandbox's parent directory and
should be gitignored.

**Attach procedure** (do this before the first request):

1. Read `.clay/inspect/state.json`. Check `phase` is `ready` (or wait —
   see `waitForRoot`) and `protocolVersion >= 3`. If you do not see a
   `status` envelope on responses, the loader is older than these
   instructions: v2 has no envelope and no `errors` action, and against
   anything older still only snapshot/eval/tree/trace/reload/waitForRoot
   exist. Check `pid` refers to a live process if you need certainty the
   loader didn't die.
   When YOU relaunch a loader under a previously used instance name,
   don't trust the first `ready` you read: the file may still be the
   dead run's (the new process clears it at startup, but there is a
   small spawn window). Either clean the instance dir before launching
   or record `runId` (unique per process) and wait for it to change.
2. If `.clay/inspect/dojo.json` exists, a dojo supervisor manages the
   loader; its respawn count reaches you as `status.restarts` on every
   response, so you rarely need to read the file. A response written
   before a respawn belongs to a dead process — watch `restarts` and
   `runId` for that.
3. Put a unique `"id"` into every request. The inspector echoes it back
   as `"requestId"` in the response — ignore any response whose
   `requestId` doesn't match your last request (stale from an earlier
   roundtrip or an earlier process generation).

**Multiple instances** (networked games): each loader started with
`--instance <name>` serves its protocol under `.clay/inspect/i/<name>/`
(`instanceId` in its `state.json`); enumerate instances by listing that
dir and address each one separately. Single-instance runs keep the flat
layout.

The normative contract lives in `docs/docs/manual/inspector.md` of the
Clayground checkout — consult it when semantics matter.

## Request/response basics

Write one JSON object to `.clay/inspect/request.json`; the inspector
watches the file and writes `.clay/inspect/response.json` atomically.
`response.json` is the sync point: wait for it to change and for your
`requestId` to appear.

Every response carries `ts`, `action`, a `status` envelope, and (if you
sent `"id"`) `requestId`. Unknown actions return
`{"error": "Unknown action: ..."}` — with the envelope, like everything
else.

```json
{"id": "req-42", "action": "snapshot"}
```

## The status envelope

The envelope is on every response whatever the action, and it is what you
check before trusting a result:

```json
"status": {
  "alive": true, "rootLoaded": true, "generation": 7, "phase": "ready",
  "reloadCount": 9, "runId": "84b55d33", "supervised": true, "restarts": 3,
  "sandbox": "/path/Sandbox.qml",
  "renderedAt": "2026-08-01T10:21:07.412",
  "lastError": "child exited 0 (normal)", "lastErrorAt": "…"
}
```

- `alive` is not a measurement — it is the fact that the inspector got far
  enough to write this response. It is only meaningful on a response whose
  `requestId` is yours; a stale `response.json` on disk says `alive: true`
  too.
- `rootLoaded` — a root object exists. False plus `phase: load_error` means
  the scene is broken; go read `errors` before anything else.
- `generation` counts **successful** loads. It is how you know the scene
  you measured is the one you edited: note it, edit, reload, and check it
  advanced. It does *not* move on a reload that failed — a generation that
  stayed put while you waited is a load error, not a slow load.
  (`reloadCount` counts attempts, so the two differing is itself a signal.)
- `renderedAt` is present **only** when this response carries a capture, and
  is the moment the image was grabbed. A `snapshot` with `"screenshot": true`
  that comes back without `renderedAt` produced no new image — read
  `screenshotError` and treat any PNG on disk as somebody else's. Never
  compare two crops without checking their captures were actually taken.
- `supervised` / `restarts` come from the dojo's `dojo.json` (`restarts` is
  respawns, i.e. every child after the first). A climbing `restarts` across
  your requests means the loader you are talking to keeps being replaced.
- `lastError` is the newer of the most recent QML error and how the last
  child died, so a crash loop is visible even when this loader logged
  nothing at all. `supervisorGaveUp: true` means the dojo stopped
  respawning — nothing will get better until the invocation is fixed.

**Never discard an error response unread.** A wrong protocol field or a
one-line QML mistake is in there, and throwing it away to retry costs
whole verification rounds.

## Lifecycle and failure artifacts

The protocol is explicitly designed so broken scenes are diagnosable
without human help. Know these files:

| File | Writer | Content |
|---|---|---|
| `state.json` | loader | `protocolVersion`, `runId` (unique per process), `pid`, `sandbox`, `phase`, `generation` (successful loads), `reloadCount` (attempts), `rearmedScenario`, `instanceId`, timestamps |
| `events.jsonl` (+ `events.rotated.jsonl`) | loader | append-only stream: `session_start`, `phase_change` (with `errorsTail` on load errors), `trace_start`, `trace_stop`, `flag`, `auto_flag`, `scenario_applied`; rotates at 5 MB |
| `log.jsonl` (+ rotation) | loader | every console/Qt message as `{ts, level, category, text}` — tail this instead of relying on snapshot's 50-line `logTail` |
| `autoflag_<ts>.json` (+ best-effort PNG) | loader | evidence bundle (trigger, tree, rootProperties, flagInfo, diagnostics) written automatically on the first runtime error per reload generation; last 3 kept |
| `dojo.json` | dojo parent | `role`, `pid`, `generation`, `phase` (`starting_child`, `child_running`, `child_exited`, `child_crashed`, `start_failed`, `gave_up`, `stopped`), `rapidCrashCount`, `everRanStably`, `reason` (terminal phases), `backingOff`/`backoffMs`, `lastExitCode`, `lastExitStatus` |
| `crash.json` | dojo parent | after ≥3 rapid crashes: `exitCode`, `exitStatus`, `generation`, `stderrTail` (last 200 lines of the child's **stdout and stderr** — a rejected command line prints its usage to stdout) |

Note `dojo.json` always lives at `<sandbox-dir>/.clay/inspect/dojo.json`,
even when the loader runs under `--instance` and serves its own protocol
from the `i/<name>/` subdir — one supervisor, one file.

Loader phases: `starting` → `ready`, `reloading` on every file-watch or
requested reload, `load_error` when the QML failed to load, `stopped` on
shutdown.

A failed reload is a no-op. The new QML is loaded into a candidate engine
and only swapped in once it instantiates without errors; a candidate that
fails is dropped, the previous scene keeps running and rendering, the error
is reported, and the generation stays where it was. So edit and look as
tightly as you like — saving a file mid-thought, with an import still
missing, costs you an error message and nothing else, and the next save
recovers without a relaunch. What you must not do is *measure* while the
phase is `load_error`: everything you read is the previous scene, not your
edit.

**Diagnosis recipes:**

- `phase: load_error` → your edit did not take effect; the scene you can
  still query is the one from before it. `errors` is the direct question;
  `snapshot` also works (even with no root item its response carries
  `errors`, `warnings` and `logTail`), and the last `phase_change` event
  carries `errorsTail`. Fix the file and save again — that is the whole
  recovery.
- Change seems to have had no effect → check that `status.generation`
  moved. If it did not, you are measuring the pre-edit scene.
- Loader gone / no response → check `dojo.json`: `child_crashed` with
  `backingOff` means the dojo is respawning with backoff; `gave_up` means
  it stopped and `reason` says why (typically a command line that never
  worked). `crash.json` has the child's output tail after a crash loop.
  C++ library changes also intentionally quit the loader so the dojo
  respawns it with fresh plugins — that is not a crash.
- Response looks unrelated → compare `requestId`; if it isn't yours,
  the response is stale.

## Verification workflow

After editing QML files, verify in layers; stop at the first layer that
gives you confidence. Read `status` on every response you get along the
way — a layer that "passed" against a dead or pre-edit scene is worse
than no verification at all.

1. **Static analysis (always):** `qmllint <file> -I build/qml`.
2. **Load check:** `{"id": "...", "action": "waitForRoot", "timeoutMs": 5000}`
   — blocks until the next load resolves (or returns immediately if the
   phase is already terminal); the response carries `phase`, and `status`
   tells you whether `generation` advanced. On `load_error`, fix the
   errors (`errors` action) before anything else — the running scene is
   still the pre-edit one, so any check you run now measures the wrong
   thing.
3. **State verification:** `snapshot` — check `errors`, `warnings`, then
   verify your change via `eval` / `rootProperties` / `flagInfo`.
4. **Entity search:** `eval` with `canvas.find()` (below).
5. **Behavior verification:** `trace` with a `stopWhen` condition.
6. **Live patching:** `eval` imperative changes on the running scene to
   confirm a fix hypothesis before editing source (changes are lost on
   reload; you cannot create new bindings or signal handlers this way).
7. **Visual verification (last resort):** `snapshot` with
   `"screenshot": true`, then Read the PNG.

## Actions reference

### snapshot — point-in-time state (default action)

```json
{"id": "s1", "action": "snapshot", "screenshot": true, "eval": ["player.health"]}
```

Returns `rootProperties` (custom primitive properties of the root),
`flagInfo` (if the root defines that function), `viewState` (if the root
implements it), `eval` results, `logTail` (last 50), `warnings`, `errors`
(plain strings here — the `errors` action is where file/line live),
optional `screenshot` path. With no
root item it returns `"error": "No sandbox root item available"` — but
still attaches `logTail`/`warnings`/`errors`.

Screenshots are **best-effort**: `grabToImage()` can fail or come out
blank on some platforms (notably offscreen with View3D content). A grab
that failed returns `screenshotError` and no `status.renderedAt`; the
`screenshot.png` on disk is then whatever an earlier request left there.
Trust `status.renderedAt`, not the file. Never make a screenshot the only
evidence.

### errors — QML errors and warnings since load

```json
{"id": "x1", "action": "errors"}
{"id": "x2", "action": "errors", "sinceGeneration": 8}
```

Returns `errors` and `warnings` as objects — `{generation, ts, text, file,
line}`, with `file`/`line` present when the message carried them — plus
`errorCount`, `warningCount` and `truncated` (the buffers hold 200 each).
Note that unhandled QML/JS exceptions (`TypeError`, `ReferenceError`, …)
arrive as *warnings*, so read both lists.

Buffers are cleared before every reload, so a bare `errors` is "what has
gone wrong with the current scene". `sinceGeneration: N` drops anything
older than generation N. Diagnostics raised *during* a load are tagged
with the generation being attempted, so a reload that failed leaves its
errors at `status.generation + 1` — visible even though the generation
itself never advanced.

### eval — expression evaluation

```json
{"id": "e1", "action": "eval", "eval": ["player.health", "JSON.stringify(canvas.find({type: 'Enemy*'}))"]}
```

Evaluates in the sandbox root context — the bridge to `canvas.find()`
and any QML function. Side-effecting expressions are allowed (that is
what live patching uses).

### tree — structural dump

```json
{"id": "t1", "action": "tree", "maxDepth": 4}
{"id": "t2", "action": "tree", "maxDepth": 6, "detail": "full"}
```

Overview (default): type, objectName, source file, custom properties,
visible/enabled. `full` adds vectors, z-order, opacity, clip, state.
More than 20 children truncate to 5 plus a type-count/named-item summary.

### trace — temporal observation

```json
{
  "id": "tr1",
  "action": "trace", "start": true,
  "watch": ["player.xWu", "boss.health", "boss.state"],
  "interval": 200,
  "stopWhen": "boss.health <= 0",
  "timeout": 30000
}
```

Stop manually with `{"action": "trace", "stop": true}`. Defaults:
`interval` 200 ms, `timeout` 30 s. The completion response (async, still
correlated via `requestId`) reports `traceStatus: "stopped"`, `stoppedBy`
(`"condition"` / `"timeout"` / `"manual"`), `samples`, `duration`, and a
per-expression summary (numeric: first/last/min/max/changes; string: values/changes).
Full samples land in `.clay/inspect/trace.jsonl` — do NOT read it while
the trace runs; wait for the completion response. A red REC indicator is
shown in the window while tracing; the user can stop a trace with Ctrl+T.

**Timing-sensitive measurements go through trace, never eval polling.**
A request/response roundtrip over the file protocol costs ~200-500 ms,
so polling with eval undersamples anything faster than ~1 Hz (a 20 Hz
state stream will look like 1-2 updates/s and mislead the diagnosis).
`trace` samples in-process down to ~25 ms intervals. For cadence, lag,
or jitter measurements: start a trace, drive the system, read the
samples afterwards.

**Cross-instance correlation:** `trace.jsonl` starts with a meta line
`{"meta":"trace_start","epochMs":...}` and each sample's `t` is relative
to it — absolute wall-clock time of a sample is `epochMs + t`. Start one
trace per instance and align the series via their epochs (e.g. sender's
`player.xWu` vs receiver's rendered position to measure replication
lag).

### reload — request a sandbox reload (optionally into a scenario)

```json
{"id": "r1", "action": "reload"}
{"id": "r2", "action": "reload", "scenario": "boss-fight", "rearm": true}
```

Same path as a file-watch reload: a fresh engine, so no scene state
survives a *successful* reload — and no scene is lost to a failed one.
The response acknowledges with `reloadStatus: "requested"` — the reload
has not happened yet. Follow with `waitForRoot`, then confirm
`status.generation` advanced. With `scenario`, the root's
`applyScenario(name)` runs once the new root is ready; `rearm: true`
re-applies it after every subsequent reload (including the user's file
edits) until a reload passes `rearm: false` — this is how you keep the
app in the situation under test across iterative editing.

### time — pause, single-step, timescale

```json
{"id": "t1", "action": "time", "paused": true}
{"id": "t2", "action": "time", "step": 30}
{"id": "t3", "action": "time", "scale": 0.1}
```

Freezes/slows the simulation via `Clayground.paused`/`timeScale`;
`ClayWorld2d` binds automatically. `step` implies pause and advances
exactly N fixed 1/60 s physics steps — deterministic, so expected
distances are computable (`frames * speed / 60`). The response's
`stepped` is 0 with a clean error when the sandbox has no world.
Combine with snapshots/eval to inspect frozen moments frame by frame.

### input — play the game

```json
{"id": "i1", "action": "input", "gamepad": {"axisX": 1.0, "durationMs": 600}}
{"id": "i2", "action": "input", "key": {"key": "Right"}}
{"id": "i3", "action": "input", "click": {"xWu": 12, "yWu": 10}}
{"id": "i4", "action": "input", "click": {"objectName": "startButton"}}
```

`gamepad` drives every GameController through a synthetic source
(imperative like keyboard input — human and agent input coexist);
`durationMs` auto-neutralizes, giving you "hold right for 600 ms".
`key` synthesizes window key events; `click` addresses window pixels
(`x`/`y`), world units (`xWu`/`yWu`, canvas apps only), or an item by
`objectName`. Combine with `trace` (`stopWhen`) for closed-loop
gameplay verification: start the trace, drive the game, assert
`stoppedBy: "condition"`.

### waitForRoot — block until load resolves

```json
{"id": "w1", "action": "waitForRoot", "timeoutMs": 5000}
```

Default `timeoutMs` 3000. Use it instead of sleep/poll loops after any
reload or when attaching during startup.

### canvas.find() — spatial/conditional search (via eval)

Filter object (all optional, AND-combined):

| Filter | Example | Description |
|--------|---------|-------------|
| `type` | `"Enemy*"` | Class name pattern (* wildcard) |
| `objectName` | `"enemy"` | ObjectName pattern |
| `near` | `{objectName: "player", radius: 10}` | Distance in world units |
| `where` | `"health < 50"` | JS expression per candidate |
| `props` | `["health", "state"]` | Properties to include in results |
| `limit` | `20` | Max results (default 50) |

`near` also accepts explicit coordinates: `{x: 30, y: 40, radius: 15}`.
Distances are world units — the canvas owns the coordinate system.

## Human collaboration channel (`.clay/crew/`)

The user presses **Ctrl+F** in the loader window to flag a moment: a
screenshot freezes, they type an annotation, and a
`flag_<timestamp>.json` (+ PNG) lands in `.clay/crew/`. Each flag
carries `annotation`, `screenshot` path, `rootProperties`, `flagInfo`,
a depth-4 `tree`, `logTail`, `warnings`, `errors`. Max 5 flags are
retained. A `flag` event also appears in `events.jsonl` — watch it to
notice new flags without polling the crew dir.

Address the annotation using the captured state; `.clay/crew/` is the
human's channel — don't write into it.

## The scenarios() convention

Sibling of `flagInfo()`: the root may define `scenarios()` (name list,
surfaced in snapshots) and `applyScenario(name)` (imperative setup of a
named situation). Recommend adding these to any sandbox you iterate on —
combined with `reload` + `rearm` they eliminate replay-from-the-start.
Assign entity positions imperatively inside `applyScenario`: initial QML
property values do not fire change handlers, so `PhysicsItem`
coordinates only sync on post-creation writes.

## The flagInfo() convention

Optional function on the sandbox root for domain-specific state,
called at snapshot and flag time:

```qml
function flagInfo() {
    return {
        player: { x: player.xWu, y: player.yWu, hp: player.health },
        enemyCount: enemies.length,
        bossPhase: boss.currentPhase
    }
}
```

Recommended for any sandbox you work on repeatedly — it turns every
snapshot and flag into a domain-level status report.

## The viewState() convention

Sibling of `flagInfo()` / `scenarios()`: the root may define `viewState()`
(returns a JSON-serializable object — the user's place: camera, tuning
params, sim time) and `applyViewState(state)` (assigns it back). Both
optional. When present, the loader captures `viewState()` from the outgoing
root right before *every* reload — your agent-requested reloads and the
user's file edits alike — and re-applies it to the new root once it is ready,
after any rearmed scenario (so a scenario + sim-time encoding gets the last
word). A null/failed capture keeps the previous one, so a fix after a load
error still restores. Snapshots and flags carry a `viewState` key when the
root implements it, and `view_state_captured` / `view_state_restored`
(`{ok}`) land in `events.jsonl`. Add these to any sandbox you iterate on with
a user watching — it keeps their camera and place fixed while you edit.

## The labInfo() convention (labs)

Sandboxes built with `Clayground.Lab` (everything under `labs/`) expose
`labInfo()` on the root — typically just `return Lab.labInfo()`:
parameters (name/value/range/unit), probe summaries
(first/last/min/max/count), and the active scenario, all
language-neutral (ids and types, never localized labels). Operate a lab
entirely through `eval`:

```json
{"id": "l1", "action": "eval", "eval": [
  "JSON.stringify(labInfo())",
  "Lab.set('gpsSigma', 5)",
  "JSON.stringify(Lab.probeSummary())",
  "startFlow('led-basics')"
]}
```

Probes are the right `trace` targets (`Lab.p('gain')`, probe
expressions), and labs honor the `time` pause/step actions by contract —
same seed + same stepped frames must reproduce identical probe series,
which is the determinism check every lab change should re-run. For
*composing* labs (blocks, conventions, flows, design language), use the
sibling skill `skills/clay-lab/`.

## Fix loop discipline

Live `eval` patches are preview only — a way to confirm a fix hypothesis on
the running scene, never the fix itself. Every fix lands in the source files
and is confirmed through a state-preserving reload (`viewState` restores the
user's place), so the running scene never diverges from git.

## Choosing eval expressions

Pick expressions that verify the **effect** of your change:

| Change | Expressions |
|--------|------------|
| Added enemies | `canvas.find({type: 'Enemy*'}).length` |
| Changed movement | `player.xWu` (snapshot, wait, snapshot) |
| Fixed pathfinding | `pathfinder.findPath(start, end).length > 0` |
| Nearby entities | `canvas.find({near: {objectName: 'player', radius: 15}})` |

## File layout

```
<sandbox-dir>/.clay/
  inspect/                     <- agent <-> inspector
    request.json               <- you write (include a unique "id")
    response.json              <- inspector writes atomically (sync point)
    state.json                 <- lifecycle (protocolVersion, phase, pid, ...)
    events.jsonl               <- append-only event stream (5 MB rotation)
    log.jsonl                  <- full structured log stream (tailable)
    dojo.json                  <- dojo supervisor state (generation, crashes)
    crash.json                 <- after crash loops: exit info + stderr tail
    autoflag_<ts>.json/.png    <- auto evidence bundle on runtime errors
    screenshot.png             <- when requested (trust status.renderedAt)
    trace.jsonl                <- during/after trace
    i/<instance>/...           <- per-instance scope when --instance is used
  crew/                        <- human -> agent (Ctrl+F flags)
    flag_<timestamp>.json
    flag_<timestamp>.png
```
