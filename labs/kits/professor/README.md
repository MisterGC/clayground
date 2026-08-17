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
| `PointAnim` | the held gestures (point, thumbs up). One driver, because they share eight joints |
| `Hair` | five cuts: `wild`, `swept`, `tidy`, `ring`, `none` |
| `Beard` | five: `full`, `walrus`, `goatee`, `chin`, `none` |
| `Spectacles` | rims, bridge, arms, placed off the head's own eye geometry |
| `DetailedHand` | four fingers and a thumb, opt-in per character |
| `Hoverboard` | what it travels on, so nobody has to animate a walk cycle |
| `Puff` | the cloud it arrives in and leaves by |

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
prof.tell("Two in series.")   // bubble + mouth, NO audio
prof.thumbsUp()               // approval
prof.vanish()                 // leaves the puff behind
```

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

## Traps

**`height3d` is not the height it renders at.** It is `bodyHeight` on the
character plugin, which feeds proportion tables whose parts sum to about 1.3
times it — 1.48 in, 1.95 out. Anything positioned from it (a camera pivot, a
label) aims at the chest. Read **`standHeight`**, or `faceY` for the eyes.

**Scale the professor to the lab's units.** Everything in the kit is
proportional to `height3d`, so one number fits a board measured in
centimetres or in metres. Nothing else needs touching.

**A raised straight arm is not an acceptable silhouette** and `PointAnim`
enforces that: the higher the aim, the more the elbow is forced to bend, so
the upper arm stays low and the forearm reaches. It costs no accuracy — the
bend is given back through the shoulder and the wrist — which means it looks
like dead code to anyone optimising the solve. It is not. Together with the
extended index finger on `DetailedHand`, it is what keeps a point upward from
reading as a fascist salute. Re-check the silhouette, not just the aim error,
after touching that maths.

**Measure a gesture after `settled`, not after `pointAt()`.** The pose eases
in over ~450 ms. Measuring immediately reports 60–160° of aim error and looks
exactly like a broken solver; `clayrender --wait-for 'prof.settled'` gives the
true 0.0–0.3°.

**A gesture is solved once**, against the frame the professor stood in when it
was asked for. `travelTo()` therefore drops it at take-off; point again after
`arrived`, which is also how a person does it.

**Eye size and hair fight over the forehead.** The plugin's cranium is ~1.4×
wider than tall and sizes the eyes off the *width*, so `eyeSize` much above
1.0 puts the lens tops within a hair of the crown and `Hair` — which refuses
to grow anything below that line — comes out bald in every style.

**`OrbitCamera3D.clipNear` defaults to 10**, which is fine for a lab looking
at a board from 80 units and slices the ground away when you stand 3 units
from a character. The rig does not expose it: set `rig.camera.clipNear`.

## What this kit added that the character plugin lacks

Beard, eyewear, an articulated hand and a look-at were all built here rather
than in `plugins/clay_character3d`, because that plugin is shared and its
`CharacterEditor` would need matching knobs. `Head.qml` also exposes no anchor
points for eyes, nose, ears or jaw, so every accessory in this kit re-derives
that arithmetic and will rot silently if that file moves. Promoting `Hand.qml`
to palm-plus-fingers would give every existing character fingers for free.

## Checking it

There is no unit suite — the kit is geometry and animation, and both are
judged by looking. What there is:

- the bench: `./build/bin/claydojo --sbx labs/kits/professor/Sandbox.qml`,
  with a pretend four-step lesson on `G` that drives the real `FlowGuide`
- `PointBench.qml`, `LookBench.qml`, `HandBench.qml`, `HairBench.qml` —
  isolated scenes, one per hard problem, kept because each was needed twice
- `clayrender --wait-for` against the bench for anything numeric
