# Clay Crew — AI-Agent Collaboration for Clayground

**Closing the feedback loop between AI agents and interactive applications.**

---

## 1. The Problem

Clayground's dev loop is built for humans: edit QML, the Dojo reloads, you see the result. AI agents cannot see. They can write QML but have no way to verify the result — did the dungeon render? does the enemy move? does combat work?

Even for humans, the feedback loop has gaps: you can see the screen but can't easily answer "what's the player's exact health?" or "did the boss AI transition states correctly over the last 10 seconds?"

## 2. The Solution

An **in-app inspector** with a file-based protocol, plus **query functions on the canvas/world** components. The inspector handles generic concerns (protocol, screenshots, tracing). The canvas/world handle domain-aware queries (spatial search in the right coordinate system).

### Why file-based?

1. **Zero dependencies** — no HTTP server, no socket library, no port management
2. **Debuggable** — `cat .clay/inspect/response.json` shows exactly what the agent sees
3. **Composable** — any tool that reads files can consume the output
4. **No port conflicts** — works in Docker without networking configuration
5. **Persistent** — snapshots and traces are saved for post-hoc review

### Why in-app?

An external tool would need to connect to a debug port and speak an undocumented binary protocol. The in-app inspector simply calls `grabToImage()`, reads properties via `QMetaObject`, and evaluates expressions via `QQmlExpression` — everything is already available in-process.

## 3. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Dojo Process                                               │
│                                                             │
│  ┌──────────────┐  ┌────────────────────────────────────┐   │
│  │  Sandbox.qml │  │  ClayInspector (C++)               │   │
│  │  (the app)   │  │                                    │   │
│  │              │  │  • file protocol (request/response) │   │
│  │  flagInfo()  │  │  • snapshot, eval, tree, trace      │   │
│  │  (optional)  │  │  • screenshot capture               │   │
│  │              │  │  • log/warning/error capture         │   │
│  │  ┌────────┐  │  │  • Ctrl+F flag, Ctrl+T trace       │   │
│  │  │Canvas/ │  │  │                                    │   │
│  │  │World2d │  │  └────────────────────────────────────┘   │
│  │  │        │  │                                           │
│  │  │ find() │  │  .clay/inspect/                           │
│  │  │(QML/JS)│  │  ├── request.json   (agent writes)        │
│  │  └────────┘  │  ├── response.json  (inspector writes)    │
│  └──────────────┘  ├── screenshot.png                       │
│                    └── trace.jsonl                           │
│                                                             │
│                    .clay/crew/                               │
│                    ├── flag_<ts>.json  (Ctrl+F)              │
│                    └── flag_<ts>.png                         │
└─────────────────────────────────────────────────────────────┘
```

### What lives where

| Component | Responsibility | Why there |
|-----------|---------------|-----------|
| **ClayInspector** (C++, tools/loader/) | Protocol, eval, tree dump, trace, screenshots, flags | Needs QTimer, file I/O, QMetaObject introspection, message handler access |
| **ClayCanvas.find()** (QML/JS, plugins/clay_canvas/) | Spatial/conditional entity search (2D) | Knows pixelPerUnit, world bounds, Y-axis inversion, content children |
| **ClayWorld2d.find()** (QML/JS, plugins/clay_world/) | Override with physics-aware search | Knows Box2D world, can enrich with velocity/body state |
| **flagInfo()** (user's Sandbox.qml) | Domain-specific state snapshot | Only the developer knows what matters for their app |

## 4. Inspector Actions

### snapshot — Point-in-time state

Returns: `rootProperties` (auto-captured), `flagInfo` (if defined), `eval` results, `logTail`, `warnings`, `errors`, optional screenshot.

### eval — Expression evaluation

Evaluates JS/QML expressions in the sandbox root context. Bridges to `canvas.find()` and any QML function.

### tree — Structural dump with LOD

Two detail levels: **overview** (compact, used in flags) and **full** (adds vector properties, state, childrenRect). Smart property filtering skips Qt framework noise, keeps only app-level state. Truncation summaries surface rare/named items in large child lists.

### find — Spatial/conditional search (via eval → canvas.find)

Defined on ClayCanvas, overridable by World2d/3d. Filter by type, objectName, distance (world units), and arbitrary JS conditions. Distance is unambiguous — the canvas owns the coordinate system.

### trace — Temporal observation

Records watched expressions at configurable intervals to JSONL. Stops on a condition (`stopWhen`), timeout, or manual request. Returns a summary with first/last/min/max/changes per expression. Enables behavioral verification without screenshots.

## 5. Human Interaction

### Ctrl+F — Flag a Moment

Screenshot freeze → type annotation → saves flag JSON (annotation + state + tree) and PNG. Max 5 flags retained. The agent reads flags to understand what the human saw and what needs fixing.

### Ctrl+T — Toggle Trace

Starts/stops the currently configured trace. The agent configures what to watch; the human controls when to record.

### flagInfo() — Developer-Defined State

Optional function on the sandbox root. Returns domain-specific state the framework can't infer. Called at snapshot/flag time.

## 6. The Autonomous Agent Workflow

```
1. Edit QML
   │
2. qmllint ──────── syntax/type errors? ──→ fix
   │
3. snapshot ─────── "No sandbox root"? ──→ engine crash
   │                 (unknown component, missing import,
   │                  circular dependency — linting can't
   │                  catch these)
   │
4. eval + find ──── entities exist? structure correct?
   │                 positions right? state as expected?
   │
5. trace ────────── behavior correct over time?
   │                 stop condition met? (= success)
   │                 or timeout? (= bug)
   │
6. ✓ Verified ──── commit / move on
```

Each layer is more expensive than the previous. The agent stops at the first layer that gives confidence.

## 7. The Collaborative Workflow

```
Human                              Agent
  │                                  │
  │  Ctrl+F: "skeleton stuck here"   │
  │  ──────────────────────────────→ │
  │                                  │ reads flag JSON + tree
  │                                  │ uses find() to locate skeleton
  │                                  │ fixes pathfinding code
  │                                  │
  │                                  │ sets up trace on skeleton.state
  │  Ctrl+T: starts trace            │
  │  plays game, lures skeleton      │
  │  Ctrl+T: stops trace             │
  │  ──────────────────────────────→ │
  │                                  │ reads trace summary
  │                                  │ identifies the stuck transition
  │                                  │ fixes the bug
```

## 8. File Protocol — Synchronization

`response.json` is the **single synchronization point**. The agent writes `request.json` and watches for `response.json` to change.

During a trace, do NOT read `trace.jsonl` — it is being actively written. Wait for the trace to stop (response.json updates with summary). Only then is `trace.jsonl` safe to read.

No race conditions: all inspector logic runs on the Qt main event loop (single-threaded).

---

*Concept based on Clayground's Clay Crew implementation, March 2026.*
