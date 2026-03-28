# Clay Crew — AI-Agent Collaboration for Clayground

**A Concept Paper for Closing the Feedback Loop Between AI Agents and Interactive Applications**

---

## 1. The Problem

Clayground's development loop is built for humans: edit QML, the Dojo reloads, you see the result. This works because human eyes close the feedback loop — you see whether the dungeon looks right, whether the enemy moves correctly, whether the torch glow is warm enough.

AI agents cannot see. An agent running in a Docker container (or any headless environment) can write QML, build it, and even run it — but it has no way to verify the result. It cannot tell whether the dungeon rendered correctly, whether the enemy walks through walls, or whether the torch glow exists at all.

This paper proposes a system called **Clay Crew** that closes this feedback loop for two modes of work:

- **Solo mode** — the agent works autonomously, verifying its own output through structured introspection
- **Crew mode** — the agent and a human collaborate, with the human providing spatial feedback directly in the running application

---

## 2. Design Principles

### 2.1 Why Not Use Existing Debuggers?

We evaluated the existing landscape thoroughly before designing a custom solution.

**Qt's QML Debug Protocol** — Qt provides a TCP-based debug server activated via `-qmljsdebugger=port:N`. It supports object tree queries, expression evaluation, and debug message subscription. Clayground already enables it: `QQmlDebuggingEnabler::enableDebugging(true)` is called in the live loader (`tools/loader/main.cpp`). However, the wire protocol uses Qt's binary `QDataStream` serialization with a `QPacketProtocol` framing layer. The protocol is **not publicly documented** — it must be reverse-engineered from Qt's source code. No open-source headless client exists.

**GammaRay (KDAB)** — GammaRay is the most powerful Qt introspection tool available. Its probe, when injected via `--inject-only`, exposes the full QObject tree, property values, signal connections, scene graph, and even live screenshots with diagnostic overlays. However, the probe's data is only consumable by GammaRay's own GUI client. The client-server protocol is undocumented, model-based, and tightly coupled to the UI. A [GitHub issue requesting headless/scriptable access](https://github.com/KDAB/GammaRay/issues/216) has been open since 2016 with no resolution.

**Squish (froglogic/Qt Group)** — Squish is a commercial testing tool that provides exactly what we need: `saveObjectSnapshot()` dumps the entire object tree to XML, `grabScreenshot()` captures the scene, both runnable headlessly from scripts. It proves the concept works. But it requires a commercial license and is not suitable for an open-source framework.

**qml-debug (VS Code extension)** — A TypeScript implementation of the Qt debug protocol by a solo developer. It demonstrates that the protocol can be implemented outside Qt Creator, but it is tightly coupled to VS Code's Debug Adapter Protocol and is self-described as "unstable."

**Conclusion:** The infrastructure for introspection exists inside every Qt application, but there is no open-source, headless way to access it from outside. Rather than reimplementing an undocumented binary protocol, we chose to put the inspector **inside the application** where it has native access to everything, and expose a simple file-based protocol that any agent (or script, or tool) can consume.

### 2.2 Why File-Based, Not TCP?

The inspector could expose its data via HTTP, WebSocket, or the Qt debug protocol. We chose file-based communication for these reasons:

1. **Zero dependencies** — no HTTP server, no socket library, no port management. The app writes files. The agent reads files. Works in any environment.
2. **Debuggable** — a human can `cat .clay/inspect/response.json` to see exactly what the agent sees. No wireshark, no protocol decoding.
3. **Composable** — any tool that reads files can consume the output: shell scripts, Python, Node.js, AI agents, CI pipelines.
4. **No port conflicts** — Docker networking, firewall rules, and port forwarding are common sources of friction. Files bypass all of this.
5. **Persistent** — snapshots are saved, not transient. You can review what the agent saw after the fact. Good for debugging the debugging.

The tradeoff is latency: file watching adds 50-300ms compared to a direct socket call. For our use case (verification between edit cycles, not real-time streaming), this is acceptable.

### 2.3 Why an In-App Component, Not an External Tool?

An external tool (the original `clayverify` concept) would need to:
- Launch the application
- Connect to its debug port
- Speak the binary debug protocol
- Manage the application lifecycle

An in-app component (`ClayInspector`) simply:
- Calls `dumpItemTree()` — it's a method on every `QQuickItem` since Qt 6.3
- Calls `grabToImage()` — native screenshot capture
- Evaluates expressions via `QQmlExpression` — in-process, no protocol
- Reads the root item's `flagInfo()` — direct function call
- Accesses the message handler's log buffer — already captured in the loader

Everything the inspector needs is already available in-process. Wrapping it in a QML component means it benefits from Dojo's live-reloading — you can iterate on the inspector itself without restarting.

---

## 3. Architecture

### 3.1 Components

```
┌──────────────────────────────────────────────────────┐
│  Running Clayground App (Dojo or standalone)         │
│                                                      │
│  ┌──────────────┐  ┌──────────────────────────────┐  │
│  │  Sandbox.qml │  │  ClayInspector               │  │
│  │  (the game)  │  │                              │  │
│  │              │  │  • watches request file       │  │
│  │  flagInfo()  │  │  • dumpItemTree() → JSON     │  │
│  │  (optional)  │  │  • grabToImage() → PNG       │  │
│  │              │  │  • eval(expr) → result        │  │
│  └──────────────┘  │  • reads flagInfo()          │  │
│                    │  • collects log tail          │  │
│                    │  • writes response file       │  │
│                    └──────────┬───────────────────┘  │
│                               │                      │
│                    .clay/inspect/                     │
│                    ├── request.json  (agent writes)   │
│                    ├── response.json (inspector writes)│
│                    └── screenshot.png                 │
│                                                      │
│                    .clay/crew/                        │
│                    ├── flag_<ts>.json  (Ctrl+F writes)│
│                    ├── flag_<ts>.png                  │
│                    └── markers.jsonl  (agent writes)  │
└──────────────────────────────────────────────────────┘
```

### 3.2 ClayInspector — The In-App Component

A QML component loaded alongside the sandbox. It has two trigger mechanisms:

**File-based trigger (solo mode):** Watches `.clay/inspect/request.json` for changes. When the agent writes a request, the inspector executes it and writes the response. This is the programmatic interface.

**Hotkey trigger (crew mode):** Ctrl+F freezes the current frame as a screenshot overlay, lets the user draw annotations on it, and writes the flag file. This is the human interface.

Both triggers produce the same structured output — the difference is only in how the snapshot is initiated and whether it includes user annotations.

### 3.3 The Verification Stack

The `clay-crew` skill teaches the agent to use these layers in order, stopping when confident:

```
Layer 1: Static Analysis
│  qmllint --json - <file>
│  → catches syntax errors, type mismatches, unresolved imports
│  → instant, no app running needed
│  → always run after editing QML
│
Layer 2: Runtime Log Analysis
│  Read response.logTail and response.warnings
│  → catches QML loading errors, binding loops, runtime warnings
│  → requires app running (offscreen OK)
│
Layer 3: Introspection
│  Read response.eval results and response.rootProperties
│  → verify game state: "does the player exist?", "are there 5 enemies?"
│  → evaluate expressions: "pathfinder.findPath(0,0,49,49).length > 0"
│  → requires app running, most questions answered here
│
Layer 4: Visual (rare)
│  Read response screenshot via the Read tool
│  → layout verification, visual glitches, "does it look right?"
│  → only when layers 1-3 are inconclusive
```

**Why this ordering matters:** Each layer is more expensive and less precise than the last. `qmllint` runs in milliseconds and gives exact error locations. Log analysis takes seconds but gives structured error messages. Introspection takes seconds and gives exact property values. Screenshots take seconds but require visual interpretation, which is the agent's weakest verification mode. By exhausting cheaper layers first, the agent resolves most issues without ever needing to "look" at the result.

### 3.4 The Request/Response Protocol

**Request format** (agent writes to `.clay/inspect/request.json`):

```json
{
  "action": "snapshot",
  "screenshot": true,
  "eval": ["player.health", "world.room.children.length", "tileGrid.columns"]
}
```

Supported actions:
- `"snapshot"` — full state dump (log tail, root properties, flagInfo, optional screenshot, optional eval)
- `"eval"` — evaluate expressions only (lightweight, fast)
- `"tree"` — dump the full item tree (verbose, for debugging structure)

**Response format** (inspector writes to `.clay/inspect/response.json`):

```json
{
  "ts": "2026-03-28T14:32:15.123",
  "action": "snapshot",
  "screenshot": ".clay/inspect/screenshot.png",
  "rootProperties": {
    "score": 42,
    "currentLevel": "dungeon_3",
    "combatActive": true,
    "difficulty": 0.7
  },
  "flagInfo": {
    "player": {"x": 23.5, "y": 12.1, "hp": 65},
    "enemyCount": 3,
    "currentRoom": "corridor_2"
  },
  "eval": {
    "player.health": 65,
    "world.room.children.length": 43,
    "tileGrid.columns": 50
  },
  "logTail": [
    "MoveTo: skeleton_1 arrived at (15, 8)",
    "CollisionTracker: player entered torch_glow_zone"
  ],
  "warnings": [
    "binding loop detected on Torch.opacity"
  ],
  "errors": []
}
```

**Design decision — root properties auto-capture:** The inspector automatically serializes all custom properties of primitive types (int, real, string, bool, color) on the sandbox root item. This requires zero configuration from the developer — whatever state you exposed at the root level, the agent can see it. This follows Clayground's pattern of convention over configuration.

**Design decision — `flagInfo()` is opt-in:** The root item may define a `function flagInfo()` that returns a structured object with domain-specific context. The inspector calls it if present and includes the result. If absent, the snapshot is still complete — just without the custom context. This keeps the framework generic while allowing game-specific enrichment.

---

## 4. Crew Mode — Collaborative Workflow

### 4.1 The Ctrl+F Flag Moment

When the human presses Ctrl+F during gameplay:

1. **Freeze** — the current frame is captured as a screenshot and displayed as a static overlay. The game continues running underneath but the overlay is frozen, giving the user a stable surface to annotate.
2. **Annotate** — the user clicks on the frozen image and types short notes. Each annotation records its pixel position on the screenshot.
3. **Share or discard** — Enter saves the flag (screenshot + annotations + game state snapshot) to `.clay/crew/flag_<timestamp>.json`. Escape discards. In both cases, the overlay disappears and the user returns to the running game.
4. **One at a time** — only one flag can be in progress. This keeps the interaction simple and prevents accumulation of unprocessed feedback.

**Why Ctrl+F over Ctrl+A (spatial click-to-annotate):**

We initially explored a mode where the user could click directly on running game elements and annotate them in real-time (Ctrl+A). This has two problems:

1. **Input routing conflict** — the game uses the mouse for character movement, camera, and interaction. A click-to-annotate mode must intercept input, but determining when the user wants to annotate vs. play requires mode-switching that disrupts flow.
2. **Dynamic elements** — in a running game, enemies move, particles spawn and die, and the player changes position. Annotating a moving skeleton is like trying to put a sticky note on a passing car.

Ctrl+F solves both: the frozen screenshot is a stable canvas with no input conflict (the game is visually paused), and annotations are anchored to a specific moment in time rather than moving objects. The user can flag a moment mid-combat, annotate it at leisure, and return to playing.

### 4.2 Flag File Format

```json
{
  "ts": "2026-03-28T14:32:15",
  "screenshot": ".clay/crew/flag_143215.png",
  "annotations": [
    {"x": 340, "y": 200, "text": "skeleton gets stuck here"},
    {"x": 120, "y": 80, "text": "torch flicker too fast"}
  ],
  "rootProperties": {
    "score": 42,
    "currentLevel": "dungeon_3"
  },
  "flagInfo": {
    "player": {"x": 23.5, "y": 12.1, "hp": 65},
    "enemyCount": 3
  },
  "logTail": [
    "MoveTo: skeleton_1 arrived at (15, 8)",
    "WARNING: binding loop detected on Torch.opacity"
  ]
}
```

The flag file uses the same structure as the inspector response. The only addition is the `annotations` array with pixel-positioned user notes. This means the agent uses the same code to interpret both self-triggered snapshots and human-triggered flags.

### 4.3 Agent Markers

After the agent addresses a flag, it can write status markers to `.clay/crew/markers.jsonl`:

```json
{"ts":"2026-03-28T14:33:00","topic":"skeleton pathfinding","status":"done","note":"now uses GridPathfinder"}
{"ts":"2026-03-28T14:33:00","topic":"torch flicker","status":"working","note":"adjusting animation speed"}
```

The Dojo renders markers as an unobtrusive overlay — a small status panel showing recent agent activity. Markers are ephemeral status updates, not permanent annotations. They use topic-based grouping rather than spatial anchoring, because the agent's changes often affect types/behaviors rather than specific screen positions.

**Design decision — markers are not spatially anchored:** The user's annotations are spatial (click on a frozen screenshot). The agent's markers are topical ("skeleton pathfinding: done"). This asymmetry is intentional. When the user says "this skeleton gets stuck here," they point at a specific screen location. When the agent fixes it, the fix applies to all skeletons (a code change to the pathfinding behavior), not a single screen coordinate. Topic-based markers correctly reflect the scope of the agent's work.

### 4.4 The Setup

**Desktop Dojo on Mac (recommended):**
The Docker workspace is a volume mount from the Mac. The agent edits files in Docker, the Dojo on the Mac watches the same directory. File changes propagate instantly through the mount. The user sees results in the Dojo window. Ctrl+F writes flag files to the shared volume. The agent reads them from Docker.

**WebDojo via clay-dev-server (alternative):**
The agent runs `clay-dev-server` in Docker, exposing port 8090. The user opens the WebDojo in a browser pointing to the Docker host. The dev-server already pushes SSE reload events on file changes. Flag moments would need a `POST /feedback` endpoint on the dev-server to write flag files, since the browser cannot write to the filesystem directly.

---

## 5. The `clay-crew` Skill

### 5.1 Why a Skill?

Claude Code has three persistence mechanisms:

| Mechanism | Purpose | Loaded |
|-----------|---------|--------|
| **CLAUDE.md** | Project conventions: build commands, architecture, code style | Always |
| **Memory** | User preferences, project context, relationship knowledge | When relevant |
| **Skill** | Operational workflows with decision logic and step-by-step procedures | On demand, when task matches |

The verification workflow is a multi-step decision process: "run qmllint, then check logs, then introspect if needed, then screenshot as last resort." This is too procedural for CLAUDE.md (which describes the project, not workflows) and too complex for memory (which stores facts and preferences, not procedures). A skill encodes the **how** — the sequence of actions, the decision points, the interpretation logic.

### 5.2 Skill Outline

```
Name: clay-crew
Trigger: When working on Clayground QML applications and needing to
         verify results, read user feedback, or collaborate on visual output.

## Solo Verification

After editing QML files, verify your changes using these layers in order.
Stop at the first layer that gives you confidence.

### Layer 1: Static Analysis (always run)
Run qmllint on every edited QML file:
  qmllint --json - <file> -I build/qml
Parse the JSON output. Fix all errors before proceeding.

### Layer 2: Request Snapshot
Write to .clay/inspect/request.json:
  {"action": "snapshot", "eval": [<expressions relevant to your change>]}
Read .clay/inspect/response.json when it appears.
Check in this order:
  1. "errors" — any QML loading errors? Fix immediately.
  2. "warnings" — binding loops, deprecation warnings? Fix if related.
  3. "eval" — do expression results match expectations?
  4. "rootProperties" / "flagInfo" — is the game state correct?
If all checks pass, your change is verified. Move on.

### Layer 3: Visual Verification (only if layers 1-2 inconclusive)
Write: {"action": "snapshot", "screenshot": true}
Read .clay/inspect/screenshot.png using the Read tool.
Look for: layout correctness, missing elements, visual anomalies.

## Choosing Eval Expressions

Pick expressions that verify the EFFECT of your change:
- Added enemies? → "world.room.children.length", "enemyModel.count"
- Changed movement? → "player.xWu" (snapshot, wait, snapshot — did it change?)
- Fixed pathfinding? → "pathfinder.findPath(start, end).length > 0"
- Dungeon generation? → "tileGrid.columns > 0", "rooms.length >= minRooms"

## Reading Crew Flags (collaborative mode)

Check .clay/crew/ for flag_*.json files after the user says they flagged something.
Each flag contains:
  - screenshot with pixel-positioned annotations (the user clicked on specific things)
  - game state at the moment of the flag
  - recent log output

Address each annotation. After making changes, write a marker:
  echo '{"topic":"<what>","status":"done","note":"<what you did>"}' >> .clay/crew/markers.jsonl

## Common Verification Patterns

[Pattern-specific examples for dungeon gen, NPC behavior,
 combat, UI, etc. — expanded during use as the skill matures]
```

### 5.3 Skill Evolution

The skill should start minimal and grow with use. As the agent encounters new verification patterns (how to check particle effects, how to verify audio, how to test physics), these get added to the "Common Verification Patterns" section. The user can also refine the skill based on what works and what doesn't — "don't screenshot every time, I already told you the layout is fine" becomes a skill adjustment.

---

## 6. The `flagInfo()` Convention

### 6.1 How It Works

The sandbox root item may optionally define a function that returns domain-specific state:

```qml
// In Sandbox.qml — entirely optional
function flagInfo() {
    return {
        player: { x: player.xWu, y: player.yWu, hp: player.health },
        enemyCount: enemyRepeater.count,
        currentRoom: roomManager.activeRoom,
        dungeonSeed: generator.seed
    }
}
```

The inspector checks at snapshot time: does the root have a `flagInfo` function? If yes, call it and include the result. If no, the snapshot still contains root properties, log tail, and screenshot — it is not diminished, just less domain-specific.

### 6.2 Why a Function, Not a Property?

A property (`property var flagInfo: ({...})`) would use QML bindings and be continuously evaluated. A function is called only at snapshot time, which:
- Avoids unnecessary computation between snapshots
- Captures a consistent point-in-time state (no partially-updated bindings)
- Can include computed values (like `pathfinder.findPath(...)`) that would be expensive as live bindings

### 6.3 Why on the Root Item?

In QML, the root item of a file is its public API. Properties and functions on the root are how a component communicates with its environment. Placing `flagInfo()` on the sandbox root follows this convention and keeps the contract simple: the inspector knows where to look (the root), the developer knows where to put it (the root).

### 6.4 Scope: Generic, Not Game-Specific

The `flagInfo()` return value is entirely developer-defined. The framework does not impose a schema. A logistics app might return `{activeRoutes: 5, pendingDeliveries: 12}`. A music tool might return `{bpm: 120, scale: "dorian"}`. A game returns whatever game state matters. The framework captures it as opaque JSON — interpretation is the agent's responsibility, guided by the skill.

---

## 7. Integration with Existing Clayground Infrastructure

### 7.1 Dojo Integration

The Dojo already provides overlay toggles:
- **Ctrl+L** — Logging overlay (console output + property watching)
- **Ctrl+G** — Guide overlay (keyboard shortcuts and help)

Clay Crew adds:
- **Ctrl+F** — Flag moment (screenshot freeze → annotate → share)

The ClayInspector component is loaded by the Dojo alongside the sandbox, similar to how the logging overlay (`MessageView.qml`) is loaded. It shares the same message handler for log capture.

### 7.2 File System Layout

```
.clay/
├── inspect/                  ← Solo mode (agent ↔ inspector)
│   ├── request.json          ← Agent writes
│   ├── response.json         ← Inspector writes
│   └── screenshot.png        ← Inspector writes (when requested)
│
└── crew/                     ← Crew mode (human ↔ agent)
    ├── flag_<timestamp>.json ← Ctrl+F writes (human)
    ├── flag_<timestamp>.png  ← Screenshot for flag
    └── markers.jsonl         ← Agent writes (status updates)
```

The `.clay/` directory is gitignored. Snapshots, flags, and markers are ephemeral session data, not version-controlled artifacts.

### 7.3 Offscreen Mode for Solo Work

When no human is watching (pure solo mode in Docker), the app runs with:

```bash
QT_QPA_PLATFORM=offscreen ./build/bin/claydojo --sbx Sandbox.qml
```

Qt's offscreen platform renders the scene graph without a display server. Screenshots via `grabToImage()` still work — they capture the offscreen framebuffer. The ClayInspector operates identically in both display and offscreen modes.

### 7.4 Plugin Placement

ClayInspector is not a Clayground plugin in the `clay_*` sense. It is a **tool component** that lives in the Dojo infrastructure (`tools/dojo/` or `tools/common/`), loaded by the Dojo process alongside the sandbox. It has no dependencies beyond Qt Quick and does not need to be imported by sandbox code — it operates on the sandbox from the outside (parent-child QML tree traversal).

The `flagInfo()` convention is the only point of contact between the inspector and the sandbox, and it is optional.

---

## 8. Open Questions

### 8.1 Item Tree Format

`QQuickItem::dumpItemTree()` outputs a human-readable text dump to stderr. For agent consumption, a structured JSON format would be better. Options:

- **Parse the text output** — fragile, depends on Qt's formatting which may change
- **Build a custom JSON tree walker** — iterate `childItems()` recursively, serialize type, objectName, position, size, visibility, and custom properties
- **Use the debug protocol's `FETCH_OBJECT`** — richer data but requires the binary protocol client we chose to avoid

**Recommendation:** Build a custom JSON tree walker. It is ~50 lines of C++ (or JavaScript via `QQmlExpression`) and produces exactly the format we want. We control the schema and can evolve it.

### 8.2 Expression Evaluation Scope

When the agent writes `"eval": ["player.health"]`, what is the evaluation context? Options:

- **Root item context** — expressions are evaluated with the sandbox root as `this`. The agent must use property names or IDs to reach nested objects. Simple and predictable.
- **Find by objectName** — support `"eval": {"skeleton_1": "health"}` to evaluate in a specific object's context. More powerful but requires a lookup mechanism.

**Recommendation:** Start with root context only. The agent can navigate via property chains: `"player.health"`, `"world.room.children.length"`. If objectName-based scoping proves necessary, add it later.

### 8.3 Screenshot Timing

When should the screenshot be captured after the app loads or after a change?

- After QML loading completes (`Component.onCompleted` has fired)
- After N frames have rendered (allowing animations to settle)
- After a specific signal (developer-defined "ready" signal)

**Recommendation:** Wait for 2 rendered frames after the last QML warning/error clears. This handles both the initial load case and the hot-reload case. The frame count is a pragmatic default — most layout settles within 2 frames.

### 8.4 Concurrent Access

Can the agent and the human both trigger snapshots simultaneously?

**Recommendation:** No. The `.clay/inspect/` channel is for the agent (file-based requests). The `.clay/crew/` channel is for the human (Ctrl+F). They write to different directories and do not conflict. The inspector processes one request at a time; if both trigger simultaneously, the inspector queues them.

### 8.5 WebDojo Support for Crew Mode

In the WebDojo (WASM in browser), the application cannot write to the local filesystem. Flag files need an alternative transport:

- **POST to clay-dev-server** — the browser sends flag data to the dev server, which writes it to `.clay/crew/`. This requires a small endpoint addition to the dev-server.
- **Download as file** — the browser offers the flag JSON as a download. The user saves it manually. Too much friction.
- **WebSocket push** — the browser sends flag data over a WebSocket to the dev-server. The dev-server already has WebSocket support for PeerJS signaling.

**Recommendation:** POST endpoint on clay-dev-server. It is ~20 lines of Python added to the existing server. The browser's Ctrl+F handler sends the flag data via `fetch()` instead of writing a file.

### 8.6 How Much of the Item Tree to Capture?

A complex scene can have hundreds or thousands of items. Dumping the full tree on every snapshot may be excessive.

- **Full tree** — complete but potentially large (10KB+ for complex scenes)
- **Top N levels** — configurable depth limit (e.g., 3 levels deep)
- **On demand only** — tree dump is a separate action, not included in default snapshots

**Recommendation:** On demand only. Default snapshots include root properties, flagInfo, eval results, and log tail — not the full tree. The agent requests `{"action": "tree"}` explicitly when it needs structural information. This keeps default snapshots fast and small.

---

## 9. Implementation Roadmap

### Phase 1 — Minimum Viable Inspector

Build the ClayInspector component with:
- File watching on `.clay/inspect/request.json`
- Snapshot action: root properties + log tail + warnings/errors
- Eval action: expression evaluation in root context
- Screenshot action: `grabToImage()` to PNG file
- Response written to `.clay/inspect/response.json`

Write the initial `clay-crew` skill with the verification layer workflow.

**Validates:** Can the agent verify a QML change without human eyes?

### Phase 2 — Ctrl+F Flag Moments

Add to the Dojo:
- Ctrl+F hotkey captures screenshot overlay
- Annotation UI (click + type on frozen screenshot)
- Enter saves flag to `.clay/crew/flag_<ts>.json`
- Escape discards
- Inspector provides game state context for the flag

**Validates:** Can a human provide spatial, contextual feedback that the agent can act on?

### Phase 3 — Agent Markers

Add marker support:
- Agent writes to `.clay/crew/markers.jsonl`
- Dojo renders markers as an overlay panel (topic + status + note)
- Markers clear after acknowledgment or timeout

**Validates:** Can the agent communicate progress back to the human in-app?

### Phase 4 — WebDojo Support

Extend clay-dev-server with:
- `POST /crew/flag` endpoint for flag file creation from browser
- `GET /crew/markers` SSE stream for marker updates
- WebDojo JS integration for Ctrl+F in browser context

**Validates:** Does the full workflow work over the network, not just local filesystem?

---

## 10. Summary

Clay Crew is three things:

1. **ClayInspector** — a QML component inside the running app that provides structured snapshots (properties, expressions, logs, screenshots) via a simple file-based protocol. It replaces the need for external debug protocol clients.

2. **Ctrl+F Flag Moments** — a Dojo feature that lets a human freeze the current frame, annotate it spatially, and share it with the agent as a structured file containing both visual and state context.

3. **`clay-crew` skill** — a Claude Code skill that teaches the agent the verification workflow (qmllint → logs → introspection → visual) and the collaborative protocol (reading flags, writing markers).

The system is designed around two asymmetries:
- **Trigger asymmetry:** The agent triggers snapshots via files. The human triggers via hotkey. Same output format, different input mechanisms — each suited to its user.
- **Feedback asymmetry:** The human gives spatial feedback (click on a frozen screenshot). The agent gives topical feedback (status markers grouped by topic). Each reflects how that party naturally communicates about changes.

Together, these components close the feedback loop for AI-agent-assisted development on Clayground — enabling both autonomous work (the agent verifies its own output) and collaborative work (the human and agent iterate together on the running application).

---

*Concept based on analysis of Clayground commit 16301bd, Qt 6.10 debug infrastructure, GammaRay 3.x, and the Clay Crew design discussion of March 2026.*
