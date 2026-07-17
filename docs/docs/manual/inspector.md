---
layout: docs
title: Inspector
permalink: /docs/manual/inspector/
---

The Dojo includes an inspector that exposes structured snapshots of the running sandbox via a simple file-based protocol. It was designed so that AI agents, scripts, or any external tool can verify what the application is doing — without needing a GUI debugger or an undocumented binary protocol.

## How It Works

The inspector lives inside the Dojo process. It watches a request file, and when that file changes it reads the sandbox state and writes a response file:

```
<sandbox-dir>/.clay/inspect/
├── request.json      ← you (or your tool) write this
├── response.json     ← the inspector writes this (atomically)
├── state.json        ← lifecycle: phase, pid, protocolVersion, reloadCount
├── events.jsonl      ← append-only event stream (5 MB one-level rotation)
├── log.jsonl         ← every console/Qt message: ts, level, category, text
├── dojo.json         ← dojo supervisor state (generation, crash info)
├── crash.json        ← after crash loops: exit info + stderr tail
├── autoflag_*.json   ← auto-captured evidence bundle on runtime errors
├── screenshot.png    ← written when requested
└── trace.jsonl       ← written during trace recording
```

The `.clay/` directory is created automatically in the directory where the sandbox QML file lives.

**Correlation:** put a unique `"id"` into every request — the response echoes it as `"requestId"` so stale responses (from earlier roundtrips or a previous process generation) can be rejected. `state.json` carries `protocolVersion` (currently 2) so tools can check capabilities before relying on them, and `runId` — unique per loader process. On startup a loader removes a previous run's `state.json`/`response.json`; drivers relaunching an instance should still either clean the instance dir first or wait for `runId` to change, since a just-spawned process needs a moment before its first write.

**Multiple instances:** networked games run several instances of the same sandbox. Start each loader with `--instance <name>` and it serves its protocol under `.clay/inspect/i/<name>/` instead (with `instanceId` stamped into its `state.json`); the flat layout remains the single-instance default.

## Actions

### snapshot — Point-in-time state

```json
{
  "action": "snapshot",
  "screenshot": true,
  "eval": ["player.health", "world.room.children.length"]
}
```

Returns: `rootProperties` (auto-captured primitive properties on the sandbox root), `flagInfo` (if the root defines a `flagInfo()` function), `eval` results, `logTail` (last 50 log entries), `warnings`, `errors`, and optionally a `screenshot` path.

### eval — Expression evaluation

```json
{
  "action": "eval",
  "eval": ["player.health", "JSON.stringify(canvas.find({type: 'Enemy*'}))"]
}
```

Evaluates JavaScript/QML expressions in the sandbox root context. This is the bridge to `canvas.find()` and any other QML function.

### tree — Structural dump

```json
{"action": "tree", "maxDepth": 4}
{"action": "tree", "maxDepth": 6, "detail": "full"}
```

Returns a JSON tree of the QML item hierarchy. **Overview** mode (default) includes type, objectName, source file, custom properties, complex property names, and visible/enabled state. **Full** mode adds vector properties, z-order, opacity, clip, state, and childrenRect.

When a child list exceeds 20 items, the tree truncates to the first 5 items plus a summary of all children — type counts and mini-dumps of rare or named items. This surfaces interesting entities (player, enemies) among hundreds of walls.

### trace — Temporal observation

Start recording:

```json
{
  "action": "trace",
  "start": true,
  "watch": ["player.xWu", "boss.health", "boss.state"],
  "interval": 200,
  "stopWhen": "boss.health <= 0",
  "timeout": 30000
}
```

Stop manually:

```json
{"action": "trace", "stop": true}
```

While running, the inspector evaluates the watched expressions at the given interval and writes samples to `.clay/inspect/trace.jsonl`. The first line is a meta record carrying the wall-clock start (`epochMs`, also present in the start response); each sample's `t` is milliseconds relative to it, so the absolute time of a sample is `epochMs + t` — this is what makes traces from multiple instances correlatable:

```
{"meta":"trace_start","epochMs":1789450123456,"interval":200,"watch":["player.xWu","boss.health","boss.state"]}
{"t":0,"player.xWu":44.8,"boss.health":500,"boss.state":"idle"}
{"t":200,"player.xWu":45.1,"boss.health":500,"boss.state":"aggro"}
{"t":400,"player.xWu":45.5,"boss.health":480,"boss.state":"attacking"}
```

The trace stops when:
- The `stopWhen` condition evaluates to true
- The `timeout` is exceeded
- A manual stop request is sent

The response includes a summary — often sufficient without reading the full trace:

```json
{
  "stoppedBy": "condition",
  "samples": 42,
  "duration": 8400,
  "file": ".clay/inspect/trace.jsonl",
  "summary": {
    "boss.health": {"first": 500, "last": 0, "min": 0, "max": 500, "changes": 15},
    "boss.state": {"values": ["idle", "aggro", "attacking"], "changes": 8}
  }
}
```

### reload — reload the sandbox, optionally into a scenario

```json
{"action": "reload"}
{"action": "reload", "scenario": "boss-fight", "rearm": true}
```

Runs the same path as a file-watch reload (full engine recreation — no scene
state survives). With `scenario`, the named checkpoint is applied via the
root's `applyScenario()` once the new root is ready. With `rearm: true`, the
scenario is re-applied after *every* subsequent reload (including file-watch
reloads while you edit) until a reload request passes `rearm: false`. The
active rearm is visible as `rearmedScenario` in `state.json`; each apply is
recorded as a `scenario_applied` event in `events.jsonl`.

### waitForRoot — block until a load resolves

```json
{"action": "waitForRoot", "timeoutMs": 5000}
```

Blocks (default 3000 ms) until the pending load succeeds or fails; returns
immediately when the phase is already terminal. The response carries `phase`,
`ready`, `waited`, and diagnostics. Use this instead of sleep/poll loops
after any reload.

### time — pause, single-step, timescale

```json
{"action": "time", "paused": true}
{"action": "time", "step": 30}
{"action": "time", "scale": 0.1}
```

Drives `Clayground.paused` / `Clayground.timeScale`. `ClayWorld2d` binds them
automatically: pause halts the physics world (restoring the user's `running`
value when lifted), `scale` slows or speeds the simulation, and `step`
advances a paused world by exactly N fixed 1/60 s physics steps (deterministic
— `step` implies pause). Worlds acknowledge steps; the response's `stepped`
count is 0 with a clean error when no world consumed the request (plain QML
app). Non-world apps can opt in by binding their own timers/animations to the
two Clayground properties.

### input — synthesized player input

```json
{"action": "input", "gamepad": {"axisX": 1.0, "buttonA": true, "durationMs": 600}}
{"action": "input", "key": {"key": "Right"}}
{"action": "input", "click": {"xWu": 12, "yWu": 10}}
{"action": "input", "click": {"objectName": "startButton"}}
{"action": "input", "click": {"x": 240, "y": 130, "button": "right"}}
```

Three channels, combinable in one request:

- **gamepad** — feeds a synthetic source in every `GameController`
  (imperative writes, exactly like keyboard input, so human and agent input
  coexist). `durationMs` auto-resets to neutral — the "hold right for 600 ms"
  primitive.
- **key** — synthesizes a key press/release on the window
  (`press`/`release` booleans, default both).
- **click** — addressed by window pixels (`x`/`y`, works in any QML app),
  world units (`xWu`/`yWu`, canvas apps — resolved via
  `canvas.worldToScene()`, clean error otherwise), or `objectName`
  (resolves the item's center; nicest for Controls-style UIs).

## Scenario Checkpoints

The sandbox root may define named checkpoints so reloads land directly in the
situation under test instead of at the title screen:

```qml
function scenarios() { return ["start", "boss-fight"] }

function applyScenario(name) {
    if (name === "boss-fight") {
        player.health = 100;
        placeEntities(bossRoomLayout);
    }
}
```

`snapshot` responses list `scenarios` when defined; `reload` applies and
optionally rearms them (see above). Assign entity positions imperatively in
`applyScenario` — initial QML property values do not fire change handlers, so
`PhysicsItem` coordinates only sync on post-creation writes.

## canvas.find() — Entity Search

The 2D canvas provides a `find()` function for spatial and conditional entity search. Call it via `eval`:

```json
{
  "action": "eval",
  "eval": ["JSON.stringify(canvas.find({type: 'Enemy*', near: {objectName: 'player', radius: 10}, props: ['health', 'state']}))"]
}
```

Filters (all optional, combined with AND):

| Filter | Description |
|--------|-------------|
| `type` | Class name pattern (`*` wildcard) |
| `objectName` | ObjectName pattern |
| `near` | Spatial filter: `{objectName: "player", radius: 10}` or `{x: 30, y: 40, radius: 15}` |
| `where` | JS expression evaluated per candidate, e.g. `"health < 50"` |
| `props` | Array of property names to include in results |
| `limit` | Max results (default 50) |

Distance is always in world units — the canvas owns the coordinate system.

## The `flagInfo()` Convention

The sandbox root item may optionally define a `flagInfo()` function that returns domain-specific state:

```qml
function flagInfo() {
    return {
        player: { x: player.xWu, y: player.yWu, hp: player.health },
        enemyCount: enemyRepeater.count,
        currentRoom: roomManager.activeRoom
    }
}
```

If present, the inspector calls it at snapshot and flag time. If absent, snapshots are still complete — just without the custom context.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+F` | Flag a moment — captures screenshot, lets you type an annotation, saves to `.clay/crew/` |
| `Ctrl+T` | Toggle trace recording — starts or stops the currently configured trace |

### Ctrl+F — Flag a Moment

Press Ctrl+F to capture the current moment:

1. A screenshot is taken and displayed as a frozen overlay
2. Type an annotation describing what you see (Shift+Return for newlines)
3. Return confirms, Escape cancels

The flag JSON contains the annotation, screenshot path, root properties, flagInfo, an overview tree dump (depth 4), log tail, warnings, and errors. Max 5 flags are retained.

### Ctrl+T — Toggle Trace

Starts or stops the currently configured trace. The agent configures what to watch via the file protocol; the human controls when to record.

## Offscreen Mode

When no display is available (Docker, CI), the Dojo runs headlessly:

```bash
QT_QPA_PLATFORM=offscreen ./build/bin/claydojo --sbx Sandbox.qml
```

The inspector works identically in offscreen mode. Screenshots still capture the rendered scene via Qt's offscreen framebuffer.

## Next Steps

- Learn about the [Logging Overlay]({{ site.baseurl }}/docs/manual/logging/)
- See [Dojo]({{ site.baseurl }}/docs/manual/dojo/) for other Dojo features
