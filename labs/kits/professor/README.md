# Professor kit — someone to be taught by

A cartoon teacher that arrives in a puff, flies to the thing under
discussion, points at it and says a line. The kit owns the character and how
it behaves; the lab owns the scene and therefore where anything is.

Used by `labs/kits/professor/Sandbox.qml` (the bench) and by any lab that
drops a `Professor` into its `View3D`. Nothing here is electronics-specific.

## Why it exists

A flow already says the right words in the right order. What a text panel
cannot do is what a teacher does without thinking: turn to the thing being
discussed and put a finger on it. **The face is not the point; the pointing
is.** Everything else in the kit is in service of making the pointing read as
deliberate.

What it deliberately does not do: it says only what it is given. Everything
else in these labs is an answer from a solver, and a character that started
volunteering opinions would be the first thing on screen asserting authority
it had not earned.

## Parts

| type | what it is |
|---|---|
| `Professor` | the whole character, one `Node`. Drop it in a `View3D`, give it `view`. |
| `FlowGuide` | hands a lab's guided flow to a professor — the wiring, so no lab writes it twice |
| `Hair` | five cuts: `wild`, `swept`, `tidy`, `ring`, `none` |
| `Beard` | five: `full`, `walrus`, `goatee`, `chin`, `none` |
| `Spectacles` | rims, bridge, arms, placed off the head's own eye geometry |
| `Hoverboard` | what it travels on, so nobody has to animate a walk cycle |
| `Puff` | the cloud it arrives in and leaves by |

The gestures and the hands are not in this table because they are not in
this kit any more: `Professor` drives the character plugin's own `GestureAnim`
(point, present, thumbs up, gesticulation, look-at) and `DetailedHand`. See
"What this kit pioneered" below.

## Using one

```qml
Professor {
    id: prof
    view: view3d              // the enclosing View3D, for the speech bubble
    height3d: 1.48            // NOMINAL height - see the trap below
    stand: Qt.vector3d(0, 0, 0)
}

prof.appear()                 // arrives in a puff
prof.travelTo(spot)           // flies there on the board, lands, emits arrived()
prof.pointAt(thing)           // turns and points, with the elbow bent
prof.presentAt(group)         // turns and offers an open hand - for an area, not a part
prof.faceViewer()             // turns to the camera - says it to the reader
prof.gesticulate()            // talks with the hands, until told otherwise
prof.tell("Two in series.")   // bubble + mouth, NO audio
prof.thumbsUp()               // approval
prof.nod()                    // acknowledgement, without losing the aim
prof.lookAt(thing)            // eyes only; null hands them back
prof.thinking = true          // eyes leave the target while working it out
prof.vanish()                 // leaves the puff behind
```

The face runs itself. It blinks, and its eyes move inside the head rather
than pointing wherever the head points: `faceViewer()` and `pointAt()` aim
them along with the body, and because the eyes arrive before the slow body
turn does, the professor is looking at you before it has finished turning.
`thinking` sends them off-axis — the only "working it out" signal a face
this boxy has, since there is no brow furrow to read at the size a
professor stands on a board. The gap between a line being asked for and the
engine starting it counts as thinking on its own, but that gap is usually
milliseconds; a flow that wants a visible beat has to hold the property
itself.

`nod()` rides on its own rotation channel, so it does not disturb where the
head is aimed — a nod at someone is still a nod *at* them.

`pointAt()` is for one thing; `presentAt()` is for several — a group of parts,
a whole circuit — where a finger at the centroid would point at bare board.
The open hand stays at chest height, palm up, and turns toward the target
rather than reaching for it. In a performance script it is `*present NAME*`
(or `*show NAME*`).

`tell()` is the narration verb. `say()` is the same thing through the
character plugin's speech engine, which means text-to-speech — right for a
character meant to be heard, wrong for a lab someone is working through at
their own pace.

### Narrating a flow

The lab supplies one function and gets the choreography:

```qml
FlowGuide {
    professor: prof
    running: myFlow.running
    step: myFlow.currentStep
    text: myFlow.currentText
    subjectOf: (i) => ({ stand: standingSpotFor(i), look: thingFor(i) })
}
```

`subjectOf` is the whole of the kit/lab split: only the lab can know where
step four's subject is. Either field may be omitted (`stand` absent means
"say it from where you are"), and `null` means the step wants neither.

**The beat of a step is fly, speak, point, address.** The flight is silent on
purpose: the line is what every other piece of timing is measured against, so
spending three seconds of a nine-second line in the air leaves the point on
arrival with whatever is left, which can be nothing. Speaking starts where the
sentence is about.

**Then point, then address.** The professor arrives, points
at the subject and holds it for as long as the step's first sentence takes to
read — then lets go, turns to the camera and talks the rest of it out with its
hands. Pointing is deixis: it means "this one", it has said that in a second
or two, and a finger left on a part for a whole paragraph turns the teacher
into a signpost. What comes after the deixis is explanation, and people
deliver explanation to a face.

`addressViewer: false` keeps the finger on the part for the whole step, for a
lab whose steps are one short label each. `pointHoldMs` overrides the
first-sentence estimate with a fixed hold.

**The hands stop when the sentence does.** Talking body language is only
talking body language while something is being said; left running past the end
of the line it is a person miming at an empty room. So the end of a line —
the mouth timer, or the narration clip finishing — puts the arms down. A
`pointAt()` is not affected: a point outlives the sentence that introduced it,
on purpose. All three ways a line can end feed the same stop — the mouth timer,
a narration clip, the speech engine — and `gestureMaxMs` (12 s) is the floor
under all three, for the clip that will not decode, the engine that never
starts, and the caller who asked for gesticulation without saying anything.

### Pre-rendered narration

A step can carry a recording. Same split again — the lab says where its audio
is, the kit decides when to play it:

```qml
FlowGuide {
    voiceOf: (i) => Qt.resolvedUrl("voice/en/" + keyOf(i) + ".wav")
}
```

`tell(text, clip)` plays the file and runs the mouth for the recording's real
length instead of a character-count estimate. An empty clip — the default —
is text only, so a flow that is half recorded still runs, and so does one with
no audio at all. Playback is `Clayground.Sound`'s `Music`, which is the kit's
one dependency on that module: a narration line has to be stoppable when the
step changes, and `Music` is the wrapper that reports a duration and an end.

This is not `say()`. Nothing is synthesised at runtime — the audio is rendered
in advance, which is the only way anyone gets to hear a line before a learner
does. electronics-101 ships English narration this way for both of its flows,
as 48 kbps AAC (about 2 MB for 29 clips); the wav masters stay out of the repo.

### Directed steps — a script instead of the built-in beat

The plugin's `Performance` (see the character plugin README, "Performance
Scripts") drives the professor directly: it has every verb the sequencer
calls, including `tell()` for silent lines and `setEmotion()`, which wears
script emotions as `mood` — `*angry*` comes out as `cross`, because a
professor is cross, not furious. Set `spoken: false` on the Performance so
bare lines go through the bubble rather than the speech engine; the bench's
`P` key is a complete example.

A flow hands scripts over per step:

```qml
FlowGuide {
    scriptTargets: view3d.scene       // where *point at NAME* looks names up
    scriptOf: (i) => i === 0
        ? "*point at the bench* This is where we start. (2500ms)"
          + " *face viewer* *gesticulate* Every lesson begins here."
        : ""                          // other steps: the built-in beat
}
```

A step with a script still flies to its `subjectOf` stand — only the lab
knows where to stand — but everything after landing belongs to the script:
the built-in speak-point-hold-address beat and the step's `text` both stand
aside for that step. `guide.script` exposes the sequencer for assertions
(`guide.script.done`, `.errors`, `.skipped`).

Two more seams for directed steps. `scriptResolve` is the lab's own name
lookup — `function(name)` returning a world position — for a scene whose
parts are model data rather than named nodes (the circuit lab answers
"the resistor" from its element list, the same authority `subjectOf` uses).
And `scriptVoiceOf(step, sayIndex)` is the audio twin of `scriptOf`,
per LINE where `voiceOf` is per STEP: a directed step usually speaks more
than once, and a pointed sentence and an addressed one are two recordings
(`battery-0.wav`, `battery-1.wav`). A step's `voiceOf` clip is ignored on
directed steps. Measured with pre-rendered clips: the sequencer advances
about 80 ms after the recording actually ends — the clip's real duration is
the cue clock, not an estimate.

## Traps

**`height3d` is not the height it renders at.** It is `bodyHeight` on the
character plugin, which feeds proportion tables whose parts sum to about 1.3
times it — 1.48 in, 1.95 out. Anything positioned from it (a camera pivot, a
label) aims at the chest. Read **`standHeight`**, or `faceY` for the eyes.

**Scale the professor to the lab's units.** Everything in the kit is
proportional to `height3d`, so one number fits a board measured in
centimetres or in metres. Nothing else needs touching.

**A raised straight arm is not an acceptable silhouette** and the plugin's
`GestureAnim` enforces that (`Character.safeSilhouette`, on by default and
left on here): the higher the aim, the more the elbow is forced to bend, so
the upper arm stays low and the forearm reaches. It costs no accuracy — the
bend is given back through the shoulder and the wrist — which means it looks
like dead code to anyone optimising the solve. It is not. Together with the
extended index finger on `DetailedHand`, it is what keeps a point upward from
reading as a fascist salute. Re-check the silhouette, not just the aim error,
after touching that maths — `PointBench.qml` reports both.

**Measure a gesture after `settled`, not after `pointAt()`.** The pose eases
in over ~420 ms. Measuring immediately reports 60–160° of aim error and looks
exactly like a broken solver; `clayrender --wait-for 'prof.settled'` gives the
true 0.0–0.3°.

**One animator per joint.** The professor used to carry a gesture driver of
its own next to the character's, and the two wrote the same eight joints:
the character's look-only pose eased the arms to zero while the kit's point
eased them up, and the zero won — a `pointAt()` turned the head and left the
arm hanging. Everything that moves an arm goes through `Character`'s verbs
now. Do not add a second driver.

**A gesture is solved once**, against the frame the professor stood in when it
was asked for. `travelTo()` therefore drops it at take-off; point again after
`arrived`, which is also how a person does it.

**Eye size and hair fight over the forehead.** The plugin's cranium is ~1.4×
wider than tall and sizes the eyes off the *width*, so `eyeSize` much above
1.0 puts the lens tops within a hair of the crown and `Hair` — which refuses
to grow anything below that line — comes out bald in every style.

**`Label3D`'s default corner radius is `-1`, which means "half the height".**
A lozenge, and right for the one-line callouts it was built for. The speech
bubble wraps, the text inside it is a rectangle, and on a five-line bubble
those caps have a 75-pixel radius — so the first and last lines run off the
ends of their own bubble. The kit sets `labelStyle.radius` explicitly. Any
multi-line `Label3D` has to.

**Only one thing may own the top centre of the window.** The bubble hangs over
the professor's head and is sized in *pixels*, so it does not shrink when the
shot pulls back: frame to the top of the head and the bubble goes off the edge
into the chrome. A lab that keeps the professor in shot frames to about twice
the figure height, and hides whatever else lives in that strip while
`prof.present` — the same call the hint bar makes when the Narrator takes the
bottom one.

**`OrbitCamera3D.clipNear` defaults to 10**, which is fine for a lab looking
at a board from 80 units and slices the ground away when you stand 3 units
from a character. The rig does not expose it: set `rig.camera.clipNear`.

## What this kit pioneered, and where it lives now

The gestures were promoted. `plugins/clay_character3d` now has a held-pose
layer (`GestureAnim`) with point, thumbs up, gesticulation and look-at on
every `Character`, articulated hands behind `Character.detail`, published
face anchors on `Head`, and the performance-script system — all of it
generalized from what this kit built first.

The hands have now gone back the other way. The kit's `DetailedHand` and its
`HandBench` are deleted: the plugin's version overtook the original (knuckles
on the back of the palm, a hinge on the palm-side edge, a palm with a hand's
proportions) and the professor draws the plugin's hands, fed from this kit's
gesture layer through a `Binding` on `Arm.handPose`. `plugins/clay_character3d/bench/HandSandbox.qml`
is where a hand is worked on now.

The gestures have gone back the same way. The kit's `PointAnim` is deleted:
`GestureAnim` carries its beat table and its silhouette policy unchanged, the
professor's `pointAt`, `thumbsUp`, `gesticulate`, `stopGesture`, `gesture`,
`gestureHand` and `settled` are the character's own verbs and state under the
same names, and its `handPose` is `Character.handPose` — the resting pose of
whichever hand the gesture is not using. The one gesture added since,
`presentAt()`, was added to the plugin directly, which is where new ones go.
`PointBench.qml` measures the real professor now.

Still kit-only: the beard, the spectacles and the hair styles. They attach
through arithmetic the plugin's new head anchors now publish, so promoting
them has become a file move plus `CharacterEditor` knobs — the next batch.

## Checking it

There is no unit suite — the kit is geometry and animation, and both are
judged by looking. What there is:

- the bench: `./build/bin/claydojo --sbx labs/kits/professor/Sandbox.qml`,
  with a pretend four-step lesson on `G` that drives the real `FlowGuide`
  (steps 0 and 2 are directed by scripts, 1 and 3 keep the built-in beat)
  and a scripted scene on `P` that exercises the whole directive vocabulary
- `PointBench.qml`, `LookBench.qml`, `HairBench.qml` — isolated scenes, one
  per hard problem, kept because each was needed twice. The hand's bench lives
  with the hand now, in `plugins/clay_character3d/bench/HandSandbox.qml`.
  `PointBench` prints aim error and elbow bend for a point (`report()`) and
  hand height against waist and chest for a present (`presentReport()`):
  `clayrender labs/kits/professor/PointBench.qml --eval 'presentAt("board")'
  --wait-for 'prof.settled'`
- `clayrender --wait-for` against the bench for anything numeric
