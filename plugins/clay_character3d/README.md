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

### Eyes: blinking, gaze and thinking

On by default, and it is what stops a face from reading as a mannequin:

```qml
Character {
    id: npc
    autoBlink: true          // default
    gazeBehaviour: true      // default
    blinkSeed: 7             // give each of a crowd its own, or they blink in step
}

npc.lookAt(player.scenePosition)   // eyes first, head after
npc.thinking = true                // eyes leave the target and settle off-axis
```

`lookAt()` aims the **head**; `GazeAnim` aims the **eyes inside it**, and the
difference in when they arrive is the whole effect. The target is mapped
into the head's own frame, so what comes back is the angle the head has
*not covered yet* — large while it is still easing round, large again when
the target is past its 65° limit, and nothing once it has arrived. Point
the eyes at that residual and they lead on the way out and re-centre on
arrival, with no second animator racing the first.

`thinking` is the most legible signal a boxy face has for working
something out — there is no brow furrow to read at ninety pixels. Set it
around the gap between being asked and answering.

Everything idle here is **deterministic for a given `blinkSeed`**: the
blink spacing, the wander, the micro-saccades and the direction of an
aversion. Two runs of a sandbox render identically, which keeps a
`clayrender` comparison meaningful; two characters with different seeds
do not, which is what a crowd needs.

Off at `Detail.Minimal` regardless, where there is no eye left to move.

### Listening

The other half of a conversation:

```qml
npcB.listeningTo = npcA     // hold A's face, break away now and then,
                            // mark the ends of A's phrases
npcB.listeningTo = null     // done
```

Everything else in this plugin describes a character while it *speaks*.
Without this the one who is not speaking does nothing at all, which is
what makes two characters talking read as two monologues taking turns.

Phrase boundaries are read off **the speaker's mouth**, not its script: a
gap in `Speech.mouthOpen` while it is still speaking ends a phrase,
whatever produced the timeline. So it works on an unknown recording read
by the envelope tier exactly as it does on an aligned one — which is what
makes it usable on dialogue nobody wrote down.

`listeningTo` owns the look target while it is set; it and `lookAt()` are
the same channel by construction.

#### The head does two things at once

A nod has to happen *while* an aim holds, and be given back without the
aim having been forgotten. So the head is the one joint that does not own
its own rotation:

| Channel | Driven by | For |
|---|---|---|
| `Head.poseEuler` | the body animators, via `HeadEulerAnim` | where the head is aimed |
| `Head.offsetEuler` | anyone | a momentary rotation on top |
| `Head.nod(deg, times)` | — | the built-in one |

`eulerRotation` is the sum, and a **binding**. Animating a head's
`eulerRotation` directly writes to that sum and will be overwritten the
next time any part of it changes — animate `poseEuler` instead. Every
other joint is unchanged and still uses `EulerAnim` on `eulerRotation`.

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

// Recorded dialog line - the mouth follows the recording
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

// How closely a recorded line is read. Spectral (the default) measures
// formant bands, so vowels get their own shapes; Envelope reads loudness
// only and is the floor everything else falls back to.
npc.speechAccuracy = Speech.Envelope
console.log(npc.speech.effectiveAccuracy)   // what the last line ACTUALLY got

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

#### How closely a recording is read

`say()` with a file decodes it in full before playback starts, and how
hard it looks at what it decoded is `speechAccuracy`:

| Tier | Reads | Gets |
|---|---|---|
| `Speech.Envelope` | loudness, zero crossings | how far the jaw dropped |
| `Speech.Spectral` (default) | formant bands | *which* shape - open/closed, spread/rounded, fricative |
| `Speech.Aligned` | the above, plus a transcript | the script's own shapes on the recording's clock |

`Aligned` is the one that needs something from you:

```qml
npc.speechAccuracy = Speech.Aligned
npc.say("dialog/intro.wav", "", "Hello! Welcome to Clayground.")
```

Given the script, the sequence of shapes stops being a guess - the text
says there is an `/m/` there, so the mouth closes. No acoustic tier can
do that reliably, because a bilabial is *voiced*: every measurement of
one says "loud", not "shut". Only the timing then comes from the audio,
by dynamic-time-warping the script against the measured frames.

A transcript that does not match the recording is worse than none - it
would drag the mouth confidently through the wrong syllables for a whole
line - so a pairing whose durations disagree by more than about 2.5x is
rejected and the tier below takes over.

Alignment also carries word marks onto the recording, so `currentWord`
and per-word callbacks work for recorded dialogue, not just for TTS.

The tiers are **not** a performance dial. A 512-point transform every
16 ms is a few hundred thousand flops for a whole line, once, which is
below the noise floor of the decode that produced the samples. What
separates them is time-to-first-sound, the samples held while the
analysis runs, and - for `Aligned` - whether anyone wrote the line down.
That last one is an authoring cost rather than a runtime one, and it is
the real reason a lecture and a barked NPC line want different answers.

No tier leaves the mouth dead. A recording the analyser cannot read
falls back to the one below on its own, and `Envelope` is the floor.
Read `speech.effectiveAccuracy` for what the last line actually got -
asking for `Spectral` and getting `Envelope` back is a normal outcome,
not an error.

What `Spectral` assumes is one close-miked speaker on a reasonably dry
recording. Against a music bed the formant bands read the instruments,
and heavy reverb fills in the gaps that mark a closure. Both degrade to
the envelope rather than to a guess, per-frame, via a confidence gate.

`plugins/clay_character3d/bench/SpeechSandbox.qml` puts both tiers on
one recording side by side.

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

### Hands and faces, and how much of each to draw

`handPose` says what the hands are doing - `relax`, `open`, `point`,
`thumbsUp`, `fist` - and a gesture overrides it for as long as it holds them.
Both levels of detail answer it.

`detail` says how much hand, and how much face, to spend on that:

| `Character.Detail` | what is drawn | draw calls |
|---|---|---|
| `Minimal` | one box per hand; the head keeps its skull, its hair and a drawn face, and loses its nose, its ears, the pupil highlights, the brows and the mouth corners | ~20 |
| `Low` | the whole body, one box per hand, reshaped per pose — a fist is a stubby block, an open hand a long flat one; the face keeps its irises and loses its brows and ears | ~21 |
| `High` | ten boxes per hand as well: four fingers and a thumb that fold, so a point extends a real index finger; the whole face | ~43 |
| `Auto` (default) | picks between the three by how tall the character lands on screen | |

The head is nine boxes at `High` — a cranium, a jaw, four of hair, a nose and
two ears — seven at `Low` and six at `Minimal`. It used to be nineteen,
because the eyes, their irises, their brows and the four pieces of the mouth
were all boxes standing in front of it. They are drawn into the head's own
surfaces by a fragment shader now, and cost nothing.

That has flattened the top of this table on purpose. `Minimal` used to be much
the cheapest level because it deleted the face, thirteen of a character's
thirty-three draw calls; now it saves one box over `Low`, and the only real
saving left between levels is the twenty boxes of fingers. What the two cheap
levels buy is no longer speed - it is a face that stays legible at twenty
pixels rather than one that shimmers. No level removes a face any more: a
character without one reads as broken rather than as distant.

Auto crosses into `High` at `detailThreshold` (240 px of figure) and drops to
`Minimal` below `minimalThreshold` (60 px). Both are measured rather than
picked — see their docs. Each character decides for itself, so a crowd pays
only for the ones that are near.

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

### The face, and how it is drawn

The eyes, their lids and irises, the brows and the mouth are not geometry. They
are signed distance fields evaluated in a fragment shader and drawn into the
front of the two head boxes - `bodyparts/FaceBox.qml` carries the material,
`face3d_main.glsl` draws the shapes. A face therefore costs no draw calls and
no vertices at all.

That buys three things a face built from boxes could not have. An eye is a
marking on a head rather than an object in front of one, so it no longer shows
its own side wall at twenty degrees off axis. `Head.gaze` aims the irises
without moving the head, which sliding a built iris sideways could never do -
it would carry the iris off its own eyeball. And `Head.autoBlink` is one
animated float rather than a pair of boxes resized every frame, which is why
the eyes never blinked before.

`plugins/clay_character3d/bench/HeadSandbox.qml` shows all three detail levels
side by side with named viewpoints, a blink, a gaze and a talking mouth, and a
readout giving the head and eye size in pixels - so "still readable at ninety
pixels" is a claim that can be checked rather than an impression.

### Face anchors

`Head` publishes where its features are, in the head node's own frame, so
accessories parented to `character.head` (beards, spectacles, hair) do not
restate its layout arithmetic and then drift from it:

`faceOffsetZ`, `faceFront`, `faceBack`, `jawFront`, `upperHeadBottom`,
`crownTop`, `eyeLine`, `eyeWidth`, `eyeSpacing`, `eyeRelief`, `noseBottom`,
`earPos`, `earSize`, `earTop`, `hairOuterX`, `mouthLine`, `mouthWidth`,
`mouthBottom`, `chinBottom`.

`mouthLine` stays put while the jaw stretches open; `mouthBottom` and
`chinBottom` move with it. `eyeRelief` is how far the eyes stand proud of
`faceFront` - zero, now that they are drawn rather than built, which is what
lets a spectacle rim settle onto the face instead of being pushed clear of a
pair of protruding cubes.

Use them. The professor kit spent a long time re-deriving all of this by hand
from the six head dimensions - fifteen-odd constants copied out of `Head.qml` -
and every one of them was a place a beard could slide off a chin with nothing
raising an error. These anchors also went unread for long enough that a binding
loop sat undetected in one of them: an anchor nothing evaluates is an anchor
nothing checks.

`Character` publishes `rightShoulderPos`, `leftShoulderPos` and `headPos` in
character-local coordinates for the same reason.

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
