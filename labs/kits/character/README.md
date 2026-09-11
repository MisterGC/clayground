# Character kit — one scene per aspect of a procedural character

The scenes `labs/character-101` loads, one per aspect: the builds, the walk
cycle, the gestures, the whole-body actions, a loadable move set, the hands,
the six faces, the head's detail tiers, the lip-sync tiers, a listener and a
crowd. Every scene is a `Node` that answers the same contract, so a lab can
drop any of them into its `View3D`, drive it from its clock and read it back
the same way. The plugin (`Clayground.Character3D`) owns the characters and
their animation models; this kit owns how an aspect is *looked at and
measured*: what stands where, what is frozen and what runs, what a phase is
called, and which numbers a claim about the aspect comes down to.

Used by `labs/character-101/Sandbox.qml`. Nothing here is lab-specific.

## Why a kit

The plugin used to be looked at through ten separate bench sandboxes and a
demo, each with its own camera, light rig, key map and readout. Ported into
one contract, the same scenes share one camera, one theme, one clock and one
record format, and a scene that answers `report()` is a scene an agent can
measure headless through `Lab.runFlow()` - which no sandbox could offer.

## The scene contract

A scene is a `Node`. The lab loads it with a `Loader3D` into its `View3D`,
and on arrival sets `view`, binds `time` to its `SimClock` and `silhouette`
to its toggle, applies any verbs that were asked for before the scene
existed, sets the rig's `minDistance` to `nearest`, and frames `bounds()`
from the default shot. Everything below is what a scene declares.

```qml
Node {
    id: scene
    // --- identity, and what the lab drives ---
    readonly property string aspect: "gait"   // the scenario name that selects it
    property real time: 0          // sim seconds, bound to the lab clock on load
    property var view: null        // the View3D, for LOD and screen measurements
    property bool silhouette: false // one ink, no lights: the outline test
    property bool live: false      // optional: true while the lab clock runs on its own
    signal reframe()               // optional: the subject moved, frame again (the lab connects it)

    // --- knobs: numbers as kernel Parameters, alive only while loaded ---
    Parameter { name: "frames"; value: 8; from: 2; to: 16; stepSize: 1 }

    // --- choices: strings, as verbs and as chips on the lab's card ---
    property string preset: ""
    function verbs() { return { "preset": (n) => { scene.preset = n } } }
    readonly property var choices: [
        { verb: "preset", key: "choice.preset", current: scene.preset,
          options: [{ value: "", key: "preset." }, { value: "elderly", key: "preset.elderly" }] }
    ]
    function choiceState() { return { preset: preset } }     // viewState carries it
    function loadChoices(s) { if (s && s.preset !== undefined) preset = s.preset }

    // --- readings: kernel Probes, alive only while loaded, PURE of wall-clock ---
    Probe { name: "gait.cycle"; unit: "s"; expr: () => scene.cycleS }

    // --- framing ---
    function bounds() { return [Qt.vector3d(-30, 0, -4), Qt.vector3d(30, 11, 4)] }
    readonly property var shots: ({ "side": { yaw: 0, pitch: 3 }, "top": { yaw: 0, pitch: 84 } })
    readonly property string defaultShot: "side"
    readonly property real nearest: 6      // the rig's minDistance for this scene
    readonly property real plotWindow: 3   // seconds the plot shows

    // --- readiness and measurement ---
    readonly property bool ready: true     // every figure holds the pose it is labelled with
    function report() { return { cycleS: 1.11 } }               // language-neutral numbers
    function readout() { return [{ key: "read.cycle", value: LabLang.qty(1.11, "s", 2) },
                                 { key: "read.factors", value: "tempo 0.72  lean 8", wrap: true }] }
    readonly property var labels: [{ at: Qt.vector3d(0, 0, 0), text: "t = 0", above: false }]
}
```

Rules that make the contract hold:

- **Probes never read wall-clock state.** A `Probe` is sampled by the lab's
  stepped clock and lands in a run record that two runs of one seed must
  reproduce byte for byte. A frozen sheet reads the *pure pose model*
  (`gaitPoseAt`, `actionPoseAt`, `movePoseAt`) at the phase the clock stands
  in; a scene that runs is *posed from `time`* every step. Anything driven
  by the plugin's own animators - a gesture solver settling, a blink, a
  recording playing - may be reported by `report()` and `readout()`, never
  by a probe, and a scene cold-opens with nothing of that kind running.
- **`live` gates what the plugin's animators may start.** A scene that
  declares `live` gets it bound to "the lab's clock runs on its own"; a
  dialogue, a recording, a demo loop may start only while it is true, so a
  stepped run (a record, the gate, `--paused`) stays a run of nothing
  moving. Verbs still work either way.
- **Choices are verbs.** Every string-valued state has a verb in `verbs()`
  and a row in `choices`; the lab's card, a flow and an agent all change it
  through the verb. Verb names are shared across scenes on purpose (`base`,
  `preset`, `emotion`, `gesture`, `action`, `move`, `pose`, `arm`,
  `expression`, `subject`, `activity`, `detail`, `recording`, `speaker`,
  `listening`, `build`, `play`, `say`, `stop`, `fingers`, `gloves`, `props`,
  `solo`, `gaze`) so a flow step reads the same whichever scene it is in.
- **`report()` is language-neutral** - ids, numbers and booleans. `readout()`
  and `labels` are translated at call time through `LabLang` and depend on
  `LabLang.lang` so a language switch re-renders them.
- **`ready` is honest.** A figure counts once it *holds* the pose it is
  labelled with: a frozen pose the moment it is written, an aimed gesture
  when its solver says it has arrived. The lab shows a banner while a scene
  is not ready and a render waits for it.
- **The first pose waits out IdleAnim.** Every idle character zeroes its
  joints over its first 200 ms; a pose written inside that window is
  animated away. Sheets pose 300 ms after creation (a timer) and re-pose
  *synchronously* on every later change, so a `--set` landing after `ready`
  is already true still shows the new pose under the capture.
- **Design tokens only.** Colours a scene needs for chrome come from
  `LabTheme`; silhouette mode paints every part `LabTheme.ink`. A character's
  own skin and clothing are the character's, not the theme's.
- **Shots are angles, not poses.** A shot is `{ yaw, pitch }` for the lab's
  orbit rig; the lab frames `bounds()` from it. Names come from a shared
  vocabulary the lab translates (`shot.<name>`): `front`, `quarter`, `side`,
  `back`, `top`, `face`, `profile`, `work`, `far`, `hand`, `palm`, `arm`,
  `hands`, `close`, `over`.
- **Figures face +X on a sheet and +Z when they face the reader**; the lab's
  camera yaw 0 looks from +Z. A row is laid out with `Sheet.layout(n,
  spacing)`, centred on the origin, so the lab frames it about its home.

## Scenes

| scene | aspect | frozen or running | what it records |
|---|---|---|---|
| `Lineup` | `lineup` | posed from the clock | a cycle length and a hip curve per build |
| `GaitSheet` | `gait` | frozen | cycle length, speed, stride; hip, knee, arm, lift over the cycle |
| `GestureSheet` | `gestures` | frozen | the set's count, and the guard and work elbows |
| `ActionStage` | `action` | posed from the clock | fist height, reach and chin distance over the cycle |
| `MoveSheet` | `moves` | frozen | the lowest foot and the highest foot of the move on show |
| `HandBench` | `hands` | frozen | palm-to-arm ratio; figure and finger size on screen in `report()` |
| `FaceSheet` | `faces` | frozen | the closest pair of the six, in uniform space |
| `HeadRow` | `heads` | frozen (blink and talk are the plugin's) | no probe - head and eye size on screen live in `report()`, and depend on the camera |
| `SpeechRow` | `speech` | the plugin's playback | mouth open per tier, from the engine - zeros in a stepped run, the curves while a recording plays |
| `ConversationStage` | `conversation` | the plugin's animators | the listener's gaze, brow and nod, from the head |
| `CrowdField` | `crowd` | the plugin's walk | draw calls, vertices, draws per character; frame time when live |

`sheet.js` is the pure-JS layer under them: phase names, row layout, the
gesture columns, the six expressions and their distance, the lineup builds,
and the boxes-per-character claim. `node labs/kits/character/sheet.test.js`
checks it; ctest runs it as `node_kit_character`.

## Model card

### What it models

Nothing of its own: the characters, their gait, action and move models, the
face shader, the lip-sync engine and the listener are the plugin's
(`plugins/clay_character3d/README.md`). What the kit adds is *measurement*:
where a claim about an aspect lands as a number.

| claim | number | scene |
|---|---|---|
| one gait, every body | cycle length per build, derived from the build | `lineup.cycle.<build>` |
| a gait is a cycle | cycle length, speed and stride; the joint curves | `gait.*` |
| a guard keeps the fists up | fist height over the shoulder, in head heights | `action.*` |
| a kick clears the hip, nothing sinks | highest and lowest foot, in leg heights | `moves.*` |
| six faces are six faces | the closest pair in uniform space | `faces.distinct` |
| a crowd costs draw calls | draws per character against the boxes it is made of | `crowd.*` |

### What it deliberately does not

- It does not time the plugin's own animators. A gesture settling, a blink,
  a nod, a recording - all wall-clock - are reported live and never recorded.
- It does not judge a picture. A silhouette that reads, a face that reads
  at ninety pixels, a fist that looks like a fist are a human's call; the
  kit puts the picture at the size and angle the call is made at.
- Frame time is this machine's. The shape of the crowd result (draw-call
  bound, vertex cheap) carries; the milliseconds do not.

## Checking it

```bash
node labs/kits/character/sheet.test.js
tools/lab-check/lab-check labs/character-101
./build/bin/clayrender labs/character-101/Sandbox.qml --out /tmp/x.png --paused \
    --eval 'applyScenario("gait"); act("preset", ["elderly"])' \
    --wait-for 'sceneReady' --result - --eval 'JSON.stringify(scene.report())'
```
