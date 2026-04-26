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
├── response.json     ← the inspector writes this
├── screenshot.png    ← written when requested
└── trace.jsonl       ← written during trace recording
```

The `.clay/` directory is created automatically in the directory where the sandbox QML file lives.

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

While running, the inspector evaluates the watched expressions at the given interval and writes samples to `.clay/inspect/trace.jsonl`:

```
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
