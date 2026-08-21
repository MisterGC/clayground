# Character3D Plugin

The Character3D plugin provides a framework for creating animated 3D characters
in Clayground applications. It features a modular body part system, procedural
animation capabilities, and integrates with the Canvas3D toon shading system
for stylized cartoon characters.

## Getting Started

To use Character3D components, import the module in your QML file:

```qml
import Clayground.Character3D
```

## Core Components

- **Character** - Base component managing body parts and animations with extensive dimension properties
- **ParametricCharacter** - High-level parameters (bodyHeight, realism, maturity, femininity, mass) that auto-calculate dimensions
- **RatioBasedCharacter** - Dimension ratios for fine-tuned proportion control
- **CharacterEditor** - Visual editor overlay for character customization with persistence
- **Speech** - Voice output (text-to-speech or wav/mp3) with approximate lip-sync
- **ThoughtBubble** - Simple text bubble for speech/thought display

## Usage Examples

### Basic Character

```qml
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D

View3D {
    anchors.fill: parent

    PerspectiveCamera {
        position: Qt.vector3d(0, 200, 400)
        eulerRotation.x: -20
    }

    DirectionalLight {
        eulerRotation.x: -35
        castsShadow: true
        shadowFactor: 78
        shadowMapQuality: Light.ShadowMapQualityVeryHigh
    }

    Character {
        y: 0
        activity: Character.Activity.Idle
    }
}
```

### Parametric Character Creation

```qml
ParametricCharacter {
    name: "hero"
    bodyHeight: 10.0

    // Body shape
    realism: 0.3       // Cartoon-like
    maturity: 0.7      // Adult
    femininity: 0.3    // Masculine
    mass: 0.5          // Average
    muscle: 0.7        // Athletic

    // Face
    faceShape: 0.5
    eyes: 1.2
    hair: 0.8

    // Colors
    skin: "#d38d5f"
    hairTone: "#734120"
    topClothing: "#4169e1"
    bottomClothing: "#708090"
}
```

### Character with Movement

```qml
ParametricCharacter {
    id: player
    name: "player"

    // Activity controls animation
    activity: isMoving ? Character.Activity.Running : Character.Activity.Idle

    // Movement derived from animation geometry
    property bool isMoving: controller.axisX !== 0 || controller.axisY !== 0

    // Move based on currentSpeed (auto-calculated from animation)
    x: x + controller.axisX * currentSpeed * dt
    z: z - controller.axisY * currentSpeed * dt
}
```

### Character Editor Integration

```qml
import Clayground.Character3D
import Clayground.GameController

Item {
    View3D {
        id: view3d
        anchors.fill: parent

        ParametricCharacter {
            id: character1
            name: "char1"
        }

        ParametricCharacter {
            id: character2
            name: "char2"
            x: 20
        }
    }

    GameController {
        id: gameController
        Component.onCompleted: selectKeyboard(
            Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D,
            Qt.Key_Shift, Qt.Key_Space
        )
    }

    CharacterEditor {
        anchors.fill: parent
        characters: [character1, character2]
        view3d: view3d
        gameController: gameController
        enabled: true
    }
}
```

### Facial Expressions

```qml
Character {
    id: character

    // Set facial expression
    faceActivity: Head.Activity.ShowJoy

    // Animate expressions
    SequentialAnimation on faceActivity {
        loops: Animation.Infinite
        PropertyAnimation { to: Head.Activity.ShowJoy; duration: 2000 }
        PropertyAnimation { to: Head.Activity.Idle; duration: 1000 }
        PropertyAnimation { to: Head.Activity.Talk; duration: 2000 }
        PropertyAnimation { to: Head.Activity.Idle; duration: 1000 }
    }
}
```

### Speech with Lip-Sync

Characters can speak text (via text-to-speech when available) or play
recorded audio (wav/mp3) - the mouth movement approximates the speech
in both cases:

```qml
Character {
    id: npc

    Component.onCompleted: {
        // Text: spoken aloud when a TTS engine is available,
        // otherwise the mouth animates silently at an estimated pace
        npc.say("Hello! Welcome to Clayground.")
    }
}

// Recorded dialog line - mouth follows the audio's loudness envelope
npc.say("dialog/intro.wav")

// Emotional conversation: colors face, voice (TTS pitch/rate) and -
// while the character is idle - body language gestures
npc.say("I lost my favorite shovel...", "sad")
npc.say("We found the treasure!", "happy")
npc.say("Give it back right now!", "angry")

// Inline annotations switch the emotion mid-speech
npc.say("*angry* Get off my ground immediately! " +
        "*happy* Just a joke - come in and have a cup of tea with me.")

// Body language is optional: disable it (or just keep the character
// walking/fighting) and only face and voice carry the emotion
npc.speechBodyLanguage = false

// Advanced configuration
npc.speech.rate = 0.2     // a bit faster
npc.speech.volume = 0.8
npc.speech.finished.connect(() => console.log("done talking"))
```

The mouth is driven by continuous shape parameters on `Head`
(`mouthOpen`, `mouthWide`, `mouthRound` - readonly outputs - plus the
writable `mouthCornerLift`). Emotions keep control of the mouth corners
while speaking, so characters can smile and talk at the same time.
For fully manual mouth control, assign any object with `speaking`,
`mouthOpen`, `mouthWide` and `mouthRound` properties to
`head.speechSource`.

### Gestures

Walk, run, idle and fight are cycles. A gesture is the other kind of
animation: a pose that eases in, is **held** for as long as it is wanted,
and eases back. Both are driven from `Character`:

```qml
Character {
    id: prof
    view: view3d                 // so Auto can see how big it lands on screen

    Component.onCompleted: {
        prof.turnTo(board.scenePosition)     // whole body, shortest way round
        prof.pointAt(stone.scenePosition)    // held until told otherwise
        prof.setEmotion("happy")             // face, until changed again
    }
}

// once the arm has arrived, talk about it facing the reader
if (prof.gestureSettled) {
    prof.lookAt(camera.scenePosition)
    prof.gesticulate()
    prof.say("This is the stone I meant.")
}

prof.stopGesture()               // eases everything back to rest
```

| verb | what it does |
|---|---|
| `pointAt(worldPos, which)` | Holds a point at a scene position. `which` is `"auto"` (default), `"left"` or `"right"`. |
| `thumbsUp(which)` | Holds a thumbs up; `"right"` by default. |
| `gesticulate()` | Two-handed talking gesture, looping until stopped. |
| `stopGesture()` | Eases every held joint - and the head - back to rest. |
| `lookAt(worldPos)` | Aims the head only; outranks the gesture's own head aim. `null` releases it. |
| `turnTo(worldPos)` | Turns the whole body on the spot; changes the resting orientation. |
| `setEmotion(name)` | A lasting face: `"happy"`, `"sad"`, `"angry"`, `"neutral"`/`""`. |

What to assert on, rather than watching:

| property | meaning |
|---|---|
| `gesture` | `"point"`, `"thumbsUp"`, `"talk"` or `""`. Set the moment a gesture is asked for. |
| `gestureSettled` | The pose has arrived. Measuring joint angles before this reports the pose being left. |
| `gestureHand` | `"left"`, `"right"`, or `""` while released or talking. |
| `emotion` | The lasting face, as distinct from `speechEmotion`, which belongs to one line. |

Two rules the layer depends on:

- **Idle only.** Gestures run only while `activity === Character.Activity.Idle`,
  and every verb above is ignored otherwise. Setting any other activity drops
  the gesture immediately and hands the joints to that activity's animation.
  This is what keeps two animators off one joint; `IdleAnim` and the speech
  body language stay switched off for as long as a gesture is held.
- **`safeSilhouette`, on by default.** A straight arm raised forward reads as a
  fascist salute, so a point that aims high forces the elbow to bend and lets
  the forearm do the reaching. The aim is unaffected - the bend is given back
  through the shoulder and the wrist. Turn it off for a character whose job is
  that shape (a salute, a hand-raise, a throw).

One trap when reacting to the layer: `gesture` and `gestureSettled` are
properties, and a handler on their change notification runs while that
notification is still being delivered. Calling a mutating verb
(`stopGesture()`, another `pointAt()`, an activity switch) synchronously
from such a handler therefore logs a QML binding loop - harmless but noisy.
Defer the reaction with `Qt.callLater(...)`, or react from a `Timer`, as
the professor kit's `FlowGuide` does.

### Hands, and how much of one to draw

`handPose` says what the hands are doing - `relax`, `open`, `point`,
`thumbsUp`, `fist` - and a gesture overrides it for as long as it holds them.
Both levels of detail answer it.

`detail` says how much hand to spend on that:

| `Character.Detail` | what is drawn |
|---|---|
| `Low` | one box per hand, reshaped per pose - a fist is a stubby block, an open hand a long flat one |
| `High` | ten boxes per hand: four fingers and a thumb that fold, so a point extends a real index finger |
| `Auto` (default) | `Low` until the character is `detailThreshold` pixels tall on screen, then `High` |

`Auto` needs `view` - a character cannot ask how big it looks without knowing
what it is being looked at through - and stays `Low` without one. It biases
toward fingers while a gesture is shaping the hands, since that is what they
are for, and it has a hysteresis band so a character drifting across the line
does not grow and shed ten boxes a hand every few frames.

`detailedHands` is read-only and reports which one is on screen right now.

### Making a gesture readable

Two properties, and they work together:

```qml
Character {
    gloves: true          // hands get their own colour, and a cuff at the wrist
    handScale: 1.45       // and they are drawn bigger than the tables give
}
```

The oldest trick in cartoon animation, and it is about legibility rather than
costume. A hand the colour of the arm it is on has to be found before it can
be read, and a hand the colour of the background cannot be found at all — so
the glove is a single high-contrast shape that separates from both. The cuff
is the half that does the separating: a pale hand is just a pale hand, the
band across the wrist is what says where the arm stops.

`handScale` scales the wrist joint, so the hand grows out of the cuff instead
of drifting off the end of the arm — and it scales the *whole* hand rather
than lengthening the finger, because stretching the one part that has to stay
legible is what produces a spike where an index finger should be.

`detail` accounts for it: bigger hands mean the fingers are worth drawing from
further away, so the Auto threshold divides by `handScale`.

The two levels are built to match in outline, so the switch is meant to go
unnoticed; `plugins/clay_character3d/bench/HandSandbox.qml` is where that is
checked, and `h` flips the fingers on one character without moving anything
else.

### Face anchors

`Head` publishes where its features are, in the head node's own frame, so
accessories parented to `character.head` (beards, spectacles, hair) do not
restate its layout arithmetic and then drift from it:

`faceOffsetZ`, `faceFront`, `jawFront`, `upperHeadBottom`, `crownTop`,
`eyeLine`, `eyeWidth`, `eyeSpacing`, `noseBottom`, `earPos`, `earSize`,
`mouthLine`, `mouthWidth`, `mouthBottom`, `chinBottom`.

`mouthLine` stays put while the jaw stretches open; `mouthBottom` and
`chinBottom` move with it. `Character` publishes `rightShoulderPos`,
`leftShoulderPos` and `headPos` in character-local coordinates for the same
reason.

## Best Practices

1. **Use ParametricCharacter** for quick character creation with intuitive parameters.

2. **Activity-Based Animation**: Set the `activity` property to control animations - speeds are auto-derived from geometry.

3. **Toon Shading**: Use the Canvas3D DirectionalLight setup for consistent cartoon rendering.

4. **Character Editor**: Add CharacterEditor during development for visual tuning, remove for production.

5. **Proportions**: Adjust `realism` (0-1) to shift between cartoon and realistic body ratios.

## Technical Implementation

The Character3D plugin implements:

- **Modular Body Parts**: Head, torso, arms, legs with independent dimensions
- **Procedural Animation**: Walk, run, idle animations derived from body geometry
- **Animation-Speed Coupling**: Movement speeds calculated from leg swing geometry
- **Facial Expressions**: Multiple expression states (idle, joy, anger, sadness, talk)
- **Editor Integration**: 3D picking, parameter sliders, and per-character persistence
- **Coordinate System**: Origin at ground level (Y=0 at feet), character faces +Z when rotation is (0,0,0) - the nose sits on the +Z face of the head and `CharacterController` walks along +Z at yaw 0

The animation system uses frame-based updates with biomechanically-inspired joint rotations and parent-child transform hierarchies.

## Performance Scripts

A performance script is one string carrying what a character says and what it
does, in the order it happens - the way a director writes a scene. It is
authored text: it diffs, it translates, and it can be asserted on without
watching it run.

```qml
Performance {
    id: perf
    performer: prof            // a Character, or any object with the verbs below
    searchRoot: view3d.scene   // where target names are looked up
}

perf.play("*point at battery* This is the battery. (2s) " +
          "*face viewer* *happy* It stores the energy our circuit spends.")
```

Two rules carry the format:

- **Directives are instant, speech and pauses are not.** A directive is
  dispatched and the script moves straight on, so "point at it *while* saying
  this" is the natural thing to write. Only a spoken line and an explicit
  `*pause*` consume time.
- **Parsing is strict.** An unknown directive is a reported error with its
  position in the source, and `play()` refuses to run the script. A typo never
  becomes dialogue. (`Character.say()` keeps its lenient parse - see
  `parse(script, {strict: false})` below.)

### Vocabulary

Directives are matched case-insensitively and their inner whitespace is
normalized, so `*Point   At  battery*` is `*point at battery*`. Everything
outside a `*...*` is spoken.

| Directive | What it does | Performer method |
|---|---|---|
| `*happy*` `*sad*` `*angry*` `*neutral*` | Sets the emotion for the lines that follow. Aliases: `joy`, `sadness`, `anger`, `calm` | `setEmotion(value)`, else the `*emotion*` annotation is prefixed to the next `say()` |
| `*point at NAME*` | Points at the target | `pointAt(pos)` |
| `*look at NAME*` | Head-only aim at the target | `lookAt(pos)`, else `turnTo(pos)` |
| `*face NAME*` | Whole-body turn to the target | `turnTo(pos)` |
| `*look at viewer*` / `*face viewer*` | Same, at the camera | `faceViewer()` for `face`, else the position from `viewerPosition` |
| `*thumbs up*` | Approval gesture | `thumbsUp()` |
| `*gesticulate*` | Talking hands on | `gesticulate()` |
| `*rest*` | Drops any gesture | `stopGesture()` |
| `*pause 800ms*` `*pause 2s*` `*pause 1.5s*` | Consumes that much time | - |
| anything else | A reported error in strict mode | - |

`NAME` is a QML `objectName`, taken verbatim from the script (case included)
and resolved against the scene - there is no second naming scheme. It may
contain spaces: `*point at the big red battery*`. `viewer` is the one reserved
name and means the camera. A duration is a number plus a unit, `ms` or `s`,
both required; `*pause 800*` is an error rather than a guess.

### Time hints

A spoken run may end with a duration in parentheses:

```
This is the battery. (2s)
```

The hint is stripped from the spoken text and becomes that line's authoritative
duration: the script advances 2 s after the line starts, whether or not the
performer is still talking. Without a hint the line ends when the performer
stops reporting that it is talking, and a backstop timeout
(`estimate * 1.5 + 2000` ms, off `Speech.estimateDurationMs()`) ends it if the
performer never reports anything at all.

The rule is deliberately narrow: the parenthetical counts as a hint only at the
very end of a run and only when whitespace precedes it. `This (2s) is the
battery.` and `Battery(2s)` are text.

### A whole script

```qml
perf.play(
    '*point at battery* This is the battery. (2s)\n' +
    '*face viewer* *happy* It stores the energy our circuit spends.\n' +
    '*pause 500ms* *gesticulate* Watch what happens when I close the switch.\n' +
    '*rest* *neutral*')
```

Ten cues: point, say (hinted at 2000 ms), face, emotion, say, pause, gesticulate,
say, rest, emotion.

### Performance

| Property | Meaning |
|---|---|
| `performer` | The character. Duck-typed: each cue calls the method named in the table above if the performer has it, and is skipped and recorded if it does not |
| `searchRoot` | Node whose children are walked (recursively, by `objectName`) to resolve a target name to its `scenePosition` |
| `resolveTarget` | `function(name)` returning a vector3d or null; replaces the `searchRoot` walk |
| `viewerPosition` | A vector3d or a `function()` returning one - where "viewer" is |
| `voiceOf` | `function(sayIndex)` returning a clip url per spoken line; with a clip and a performer that has `tell()`, the line is played from the file. `sayIndex` counts spoken lines from 0 |
| `spoken` | What a bare line (no clip) does. True (default) goes through `say()` - the speech engine. False keeps the lab silent: a performer with `tell()` shows and mouths the line without audio, the professor's narration mode |
| `extraVerbs` | Extra directive names the parser accepts |
| `debug` | Logs `[perform] 1234ms cue 3/7: point at battery` per cue |

| Method | Meaning |
|---|---|
| `play(script)` | Parses strictly and plays from the first cue. Returns false and plays nothing when the script has errors |
| `playFrom(index)` | Plays the last parsed script from a cue - a debugging aid |
| `stop()` | Disarms every timer, ends speech (`stopSpeaking()`/`quiet()`) and drops gestures. Does not emit `finished()` |
| `registerVerb(name, handler)` | Teaches the parser a directive and dispatches it to `handler(arg)`. The seam for actions only one character has; a handler that throws is recorded, the script continues |
| `estimateMs(text)` | What the performer's speech engine expects the line to take, or 72 ms per character |

### Observability

A script is verified by reading state, not by watching it.

| Property / signal | Meaning |
|---|---|
| `running` | True between `play()` and the last cue |
| `done` | True once the last cue has fired |
| `cueIndex` / `cueCount` | Which cue is playing, out of how many |
| `currentCue` | The current cue as a one-liner, e.g. `point at battery` |
| `errors` | Parse errors of the last `play()`, each `{at, directive, message}` |
| `skipped` | Cues that could not be carried out, each `{cue, reason}` - an unresolved target, a missing verb, a handler that threw |
| `firedLog` | Every cue that fired, each `{ms, cue}`, ms measured from `play()` |
| `finished()` | Emitted after the last cue |
| `customCue(verb, arg)` | Emitted for a custom cue with no registered handler |

An unresolved target is never fatal: the cue is skipped, recorded in `skipped`
and warned about once.

### The parser on its own

`scripting/performancescript.js` is Qt-free - no Qt types, no clock, no
randomness - so scripts can be checked without an engine:

```
node plugins/clay_character3d/scripting/performancescript.test.js
```

- `parse(script, options)` -> `{cues, errors}`. `options.strict` (default true);
  `options.extraVerbs` accepts additional directive names as
  `{type: "custom", verb, arg}` cues. Every cue carries `at`, its character
  index in the source.
- `describe(cue)` -> the one-liner `Performance.currentCue` publishes.
- `lint(scriptA, scriptB)` -> divergences between the directive sequences of
  two languages of the same script, each `{index, a, b, message}`.

### Cross-language lint

Direction lives inside the translated string, which is what lets a German
script time its cues to German word order - and what lets a translator reorder,
drop or translate a stage direction by accident. `lint()` compares the two
directive sequences, ignoring the spoken text and the time hints:

```js
const Script = require('.../performancescript.js')
Script.lint(strings.en.introScript, strings.de.introScript)
// [] when the two are in sync
// [{index: 2, a: "point at battery", b: "point at Batterie",
//   message: "argument differs: point at battery vs point at Batterie"}]
```

### Speech timing

`Speech` publishes the numbers a script schedules against, instead of every
caller measuring a speech rate of its own:

- `estimateDurationMs(text)` - how long the engine would take over the text at
  the current rate, without saying it.
- `durationMs` - the current line's length; stale once the line ends.
- `wordMarks()` - the current line's words as `{offset, ms}`.

Two engine behaviours a scheduler depends on: an empty or whitespace-only line
reports `started()` and `finished()` (asynchronously, never re-entrantly), so a
queue advancing on `finished()` cannot hang on it; and of several `say()` calls
in one tick, exactly the last one runs and it is the only one that reports
anything - a line replaced before it began emits neither signal.
