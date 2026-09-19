# Explaining details in lab flows — evaluation (#269)

Four prototypes of how a lesson gets *inside* a thing the scene shows as a
lump, built on one subject (the NPN transistor of `labs/kits/circuit`) and
compared in one dojo (`labs/kits/explain/Sandbox.qml`, scenarios `1`–`4`,
`5` the favourite combination, `T` for the current one's lesson). This document is the comparison, the
favourite with its reasoning, and how the pieces would land in the framework
for good. Remarks go inline as `{>>comments<<}`.

## 1. The question, as understood

The professor can point at the transistor and say "three legs, a base current,
a chip inside" — and the learner sees a black case. The words are right; the
picture cannot follow them. #269 asks which *mechanism* lets the picture
follow the words when the words are about something the scene hides: inside a
part, at a scale the eye cannot reach, or in an abstraction (a graph) that has
no place on the board at all.

In scope: one prototype per approach the issue names (exploded view, in-scene
markers, chalkboard) plus one of my own (the dive-in the issue hints at), each
far enough to *judge*, not to ship; a bench that switches between them on the
same subject and the same lesson; a favourite with reasoning; a plan for the
reusable pieces. Out of scope: wiring anything into `electronics-101`
(its `meet` step is the target of the follow-up, and it stays untouched
here), narration audio, a `labs/<lab>` with records and paper (this is an
evaluation, not a lesson).

Assumptions I made because nobody could be asked: the subject stays the
transistor (the issue's own example); "blends in with the lab" is judged
against the paper-and-ink look and the television grammar `CameraDirector`
already speaks; "reusable" means a second kit — hydraulics, the character
lab — could use the mechanism without editing it.

## 2. The criteria

| # | criterion | what it asks |
|---|---|---|
| C1 | structure | does the learner see *what the parts are and where* |
| C2 | function | does it show *what moves* — cause and effect, ideally from the lab's own numbers |
| C3 | continuity | does the learner keep the link to the real part on the board (or is it a cut to somewhere else) |
| C4 | the professor | do pointing, marks and the camera grammar work without special cases |
| C5 | authoring cost | what a lab author writes for the *next* subject |
| C6 | reach | electronics only, or any kit (a pump, a joint, a junction) |
| C7 | verifiable | goal properties a headless `Lab.runFlow` can assert; nothing a record would see |
| C8 | maths | can it carry a graph or a formula |
| C9 | readability | at 1400×900, both themes, and in a browser |
| C10 | framework risk | what the kernel would have to grow or bend |

## 3. What was built, and how to look at it

```bash
./build/bin/claydojo --sbx labs/kits/explain/Sandbox.qml     # 1-4 pick an approach, 5 the combination, T runs its lesson
```

One kit, `labs/kits/explain/` (`README.md` is the contract every type was
built against):

| approach | scenario | mechanism | content |
|---|---|---|---|
| 1 exploded view | `exploded` | `ExplodedView3D.qml`, `ExplodePart.qml` | `TransistorAnatomy3D.qml` from `anatomy.js` |
| 2 callouts | `callouts` | `CalloutLayer.qml` (+ the anatomy's `xray`) | the same anatomy's `partAt()` |
| 3 chalkboard | `chalkboard` | `Chalkboard.qml`, `chalk.js` | `transistorSection()`, `gainGraph()` in `chalk.js` |
| 4 dive in | `inside` | `DiveIn.qml`, `carriers.js` | `TransistorInterior3D.qml` |
| 5 the combination | `combined` | 1 + 3, in that order; the slate beside the open part | nothing new |

Scenario `5` is §5's verdict as one lesson, so it can be judged as a
whole rather than assembled in the head: x-ray, take apart, focus the
layers, then the chalk section draws itself *beside* the open die and the
gain graph follows on the same slate, the professor still in the picture
pointing at the real base layer; the case goes back on last. Its one
switch (the bench button "slate beside the part" / "slate over the scene")
is the open fork of §9: the beside variant is the Chalkboard's `safe`
margin set to half the width with a light scrim, the over variant is
approach 3's cut. While the slate stands beside, the Narrator carries the
line — a bubble sized in pixels over a figure framed into a third of the
width lands under the panel or under the slate.

All five lessons say the same thing in the same order (three legs → the
case opens → three layers → a small current steers a large one) so the
words drop out of the comparison; every mechanism is a **verb** in the
bench's `flowActions()` (`explode`, `xray`, `focus`, `callouts`, `chalk`,
`dive`, `currents`) and every animated quantity is a goal with a read-only
interpolant, which is what lets `Lab.runFlow()` walk all five headless.
The professor is the same `FlowGuide` + `CameraDirector` wiring
`electronics-101` uses; the only new seam is `resolveName()`, which answers
a part id with a scene point from `anatomy.partAt()` (or the interior's
while inside), so `mark:` lists and the finger land on pieces of a part
without the lab knowing any geometry.

Each mechanism also has a bench of its own under `bench/` for working on
it alone.

## 4. Findings

Each approach was judged on its own bench by the agent that built it, and
then by me in the shared sandbox with the professor and the lesson running.
"Measured" means a number out of `report()`, `partAt()` or a `--wait-for`
that held; "seen" means I looked at the render.

### 4.1 Exploded view — the thing, opened

*Seen.* The assembled anatomy and the circuit kit's own transistor side by
side read as the same part (same silhouette, same silkscreen); the missing
gold pad domes are the one difference. At `spread 1` the column reads
bottom-to-top — footprint, three fanned legs, header, N slab, P slab, N
island, two gold wires, the facet, the case — *if the camera comes along*:
the stack reaches y 11.6 above a 3.1-unit part, and the bench's resting
shot cuts it. In the lesson the two-shot holds the pieces the line names
(`parts:` in the sandbox's choreography), which is what made the three
slabs and their three captions legible. The x-ray at 0.75 is the single
most convincing frame of the whole evaluation: the TO-92 is still itself
and the header, the N-P-N stack and both bond wires are legible at once,
with no narration.

*Measured.* `partAt("leg.base")` = (0, 0.55, 1.75) at rest, so a ring and a
finger land on the leg; at `spread 1` `die.base` sits 1.4 above
`die.collector` and the case 2.7 above the wires (`--wait-for` held). Node
`opacity` blends on `PrincipledMaterial` *and* on `Box3D`'s custom material
in Qt 6.11.1 — no material tricks needed. Lesson headless: `finished:
true`, no unresolved verbs, no failed expects.

*Limits.* Structure only: nothing about a slab floating 5.5 units up says
"thin enough that carriers shoot through". Exploding destroys the part's
real look for the duration; the facet originally flew toward the camera
and hid the die (fixed in `anatomy.js` by sending it sideways — an
authoring rule: offsets fan *away from the viewing side*). `xray: 1`
deletes the case; the useful range is 0.6–0.85.

### 4.2 Callouts — naming what you can see

*Seen.* For the three legs this is unbeatable: a ring, a number and a
two-line card each, the leader stroked with a paper halo so it survives
crossing the black case, revealed one at a time. Sequencing turns a
diagram into a lesson. With the case ghosted the same cards reach the die
— but nine callouts on a part 150 px wide is a knot of rings that only the
badge numbers rescue, and with the professor in the two-shot all nine
cards stack in one column. The "far side" placement rule the contract
asked for crossed leaders over a centred subject; the near-side rule
(`autoRule: "near"`) does not, and is what the sandbox uses.

*Measured.* Six cards pairwise disjoint and inside 1400×900 (`cardsClean()`
held); `screenOf()` moves with the camera (yaw 0 → 60 changed every point
but the one on the axis); a `keepOut` box faded the callouts inside it
(`visibleCount 1 < shownCount 6`). Lesson headless: `finished: true`.

*Limits.* It can only point at what is already visible — callout 9 on a
solid case is a claim, not a sight; that is the issue's "for many too
weak", confirmed. Density degrades fast; German captions elide at 220 px.
Found on the way: `mapFrom3DScene` answers zeros until the view has drawn
once, and with a camera that never moves the kernel's `MarkLayer` pattern
never re-projects — invisible in every orbiting lab, fatal in a still shot
or a `clayrender` figure (`plugins/clay_lab/MarkLayer.qml:156-161`).

### 4.3 Chalkboard — the idea, drawn

*Seen.* The cut is a cross-dissolve: the scrim comes up, the slate arrives
at 0.94 → 1 over 450 ms, and the drawing draws itself in the kernel's own
handwriting face — so the board reads as the same hand that writes every
hint in the lab, moved onto a darker surface. The cross-section says
"three doped layers, a small current into the middle one, a large one
straight through" and nothing else, with a priced `pause` between structure
and currents that reads as a teacher's beat. The gain graph is the argument
for the approach: it is not a picture of the part at all, and no arrangement
of slabs, rings or carriers produces one.

*Measured.* 72/72 node assertions on `chalk.js` (`at()` monotone and
clamped, `total` = Σ `length`, both drawings inside the unit box);
`presence` reaches 1 at 416 ms, `progressNow` rises linearly over 5993 ms
(trace); about 2 fps of cost while inking. Lesson headless: `finished:
true`.

*Limits.* It throws the object away for the duration and asks the learner
to map the drawing back afterwards. The slate is a screen overlay, not a
thing in the room — the professor cannot walk to it or point at it; a
3D-plane variant (the same `Canvas` through `Texture { sourceItem }`) is
the obvious next step. Two theme traps: chalk must be `inkOn(slate)` (in
the dark palette `paper` is near-black) and a scrim needs a role that
darkens in both palettes (`ink` inverts) — `LabTheme` has no such token.
The narrator's strip and the slate collided until the slate got a `safe`
guard, and `I_B` is not handwriting (`Ib` is).

### 4.4 Dive-in — the inside as a place

*Seen.* Inside, the emitter island being small, the base a sliver between
two mustard junction rings and the collector the whole substrate are not
facts to be told, they are the room the shrunken professor is standing in;
the figure on the island is what carries the scale. Carriers stream from
the island through the base into the collector, a shorter terracotta train
comes in sideways at the base contact. The case stays as a faint shell;
the anatomy's own die and wires fade out as the interior takes their place
(from a hand's breadth away a ghosted bond wire was a beam across the whole
picture). The camera at pitch 18 ends up just outside the case — a close-up
more than a fly-through.

*Measured.* 45/45 node assertions on `carriers.js` (inside the die box for
many `(t, iB, iC)`, same `t` → identical array, zero current → frozen);
a 113-frame trace shows `rig.distance` 25.6 → 2.69, `prof.height3d`
6.2 → 0.37 and `depth` 0 → 1 each as one monotone glide; the round trip
lands back at distance 26, `clipNear` 0.5 and full height exactly, and it
is interruptible (`leave()` at depth 1 while the figure is still flying
in still lands it on its old spot). Lesson headless: `finished: true`.

*Limits.* Function only half as well as it promises: the carriers move at
the lab's currents and `iB = 0` freezes everything, but *why* the small
sideways stream permits the big vertical one is exactly the causal step
the picture cannot make — a learner who does not already know reads "more
dots when I turn the knob". No text at all by design; the labels have to
come from marks (they do, through `resolveName()`). The most expensive
mechanism: an interior model per subject, three rig floors relaxed and
restored, the presenter's size and speed glided, and the flow guide has to
stay off the camera for the whole journey (`director` is unbound while
`depth > 0`). Kernel gaps it ran into: `applyState()` takes no duration
(the return goes through a fabricated viewpoint and a spurious jump-list
entry), `fit()` of two corners frames the box's diagonal and hangs six
corners off the edge, `Box3D` cannot blend (the slabs are plain cubes),
and the rig does not own `clipNear`.

### 4.5 Side by side

| | 1 exploded + x-ray | 2 callouts | 3 chalkboard | 4 dive-in |
|---|---|---|---|---|
| C1 structure | **best** — same object, opened | names what is visible | schematic, not the object | as a place; layers occlude |
| C2 function | none | text only | **best** — arrows, a graph | carriers move, cause unclear |
| C3 continuity | kept | kept | **lost** for the cut | kept, at a new scale |
| C4 professor | points/marks/camera unchanged | professor + cards compete for the frame | professor behind the scrim | shrinks; camera off limits to the director |
| C5 authoring next subject | a part table + geometry | a list of `{at, label, detail}` | **a JS drawing**, language-neutral | an interior model + paths |
| C6 reach | any assembly | any scene | any idea | anything with an inside |
| C7 verifiable | `partAt()` numbers | `cardsClean()`, `screenOf()` | `node` checks the whole drawing | trace + round trip |
| C8 maths | no | no | **yes** | no |
| C9 readability | dark: case by silhouette only | 9 on one part is a knot | good in both themes | good; slabs need blending |
| C10 framework risk | low | low (MarkLayer fix) | low (theme roles) | **high** (four rig gaps) |

## 5. The favourite, and why

**The exploded view with x-ray — approach 1 — as the mechanism to build
the framework around, with the chalkboard as its complement.**

The reasoning, in order of weight:

1. **It is the only approach that keeps the object.** A learner watching
   the case lift off the *same* lump the professor just pointed at never
   has to take on faith that the picture is about the part on the board.
   The chalkboard asks for that leap explicitly; the dive changes the
   learner's position and scale so completely that the return trip is
   needed to re-anchor it. The x-ray at 0.75 is the frame that made the
   whole evaluation for me: the TO-92 is recognisably itself and its inside
   is legible, with no words.
2. **It manufactures the subject every other mechanism needs.** What made
   the bench work at all is `anatomy.js` + `partAt(id)`: a part table with
   ids, roles, teaching order and offsets. Marks and callouts ring its
   parts, the finger lands on them, the camera holds them, the interior
   stands on its die, the chalk draws its layers. The exploded view is that
   contract's first consumer; the others are its beneficiaries. Promote the
   contract and the explosion comes almost free (`ExplodedView3D` +
   `ExplodePart` are ~230 lines with no electronics in them).
3. **It costs nothing to verify and nothing to author beyond geometry.**
   Every claim about the picture is a number out of `partAt()`; a headless
   `Lab.runFlow` asserts `spread` and `focus`; no timers, no RNG.
4. **Its weakness has a cheap, complementary cure.** It cannot show a
   current or a relationship. The chalkboard can, is the cheapest of the
   four to author for a new idea (one JS function per drawing,
   language-neutral by construction), is `node`-checkable end to end, and
   its one cost — the cut away from the object — is exactly what the
   exploded view has already paid for by then: the learner knows what is
   inside before the drawing abstracts it. The issue's own request for
   maths (graphs) is only answerable this way.

Where that leaves the other two: **callouts** are not a rival but the
words for whichever mechanism is on screen — they fold into `MarkLayer` as
captioned marks with leaders, and their honest limit (they can only point
at what is visible) is exactly why they pair with the x-ray. The **dive**
is the payoff shot, not the lesson: the most memorable frame, the only one
where the professor stays in the world, and the one whose kernel bill is
four rig features and an interior model per subject. Worth building —
*after* the anatomy contract exists, and as a `CameraDirector` shot
rather than as its own controller.

## 6. How it lands sustainably

Decisions I would make for the follow-up; each is one heading so it can be
argued with on its own.

### D1 The subject contract goes to the kernel

`ExplodedView3D` and `ExplodePart` move to `plugins/clay_lab/` unchanged
in API: `spread`/`spreadNow`, `focus`, `unit`, `partIds`, `partAt(id)`,
`idsInOrder()`, and `ExplodePart { partId; offset; anchor; order; role }`.
Anything a lesson can take apart is one of these; anything that can be
pointed at by name answers `partAt`. Content — `TransistorAnatomy3D`,
`anatomy.js` — moves to `labs/kits/circuit/`, where the transistor lives.

### D2 The circuit kit's transistor *is* its anatomy

`CircuitElement3D`'s transistor branch (`labs/kits/circuit/CircuitElement3D.qml:360-460`)
is replaced by the anatomy at `spread 0` — same silhouette, same pads,
same silkscreen (the anatomy replicated them) — so every transistor on a
board is explodable and x-rayable without a swap. The pad domes and the
working-region collar stay with the element. Cost to check: five
transistors × eleven parts on the XOR board; if that shows in the frame
time, the alternative is a `detail` node swapped in for the one part a
lesson opens.

### D3 Details are verbs and script cues, not new FlowStep fields

The bench proved a lesson needs no kernel change to drive any of this:
`explode`, `xray`, `focus`, `chalk`, `dive` are verbs in `flowActions()`,
so `FlowStep.demo` switches them as data and `Lab.runFlow` replays them.
For directed steps the same verbs register as custom cues on the guide's
`Performance` (`registerVerb`, as `*cut to*` does today), so a script can
say `*open the transistor* Three legs …`. No parser change.

### D4 Marks grow cards; the projection gets fixed

`CalloutLayer` folds into the kernel beside `MarkLayer` on a shared
projected-overlay base (`view`, `camera`, `keepOut`, `clear()`,
`screenOf()`), with `MarkLayer` keeping rings and `CalloutLayer` the
layout engine (two columns, stacking, leaders). Two fixes ride along:
re-project on the first drawn frame and per frame when asked
(`plugins/clay_lab/MarkLayer.qml:156-161` freezes at the origin in a still
shot), and `keepOut` as one rect *or a list* — a presenter plus two panels
is the normal case.

### D5 The chalkboard is a kernel chrome block

`Chalkboard.qml` moves next to `LabBanner`/`HintBar`; `chalk.js` next to
`format.js`, with `transistorSection`/`gainGraph` left behind in the
circuit kit as `drawings.js`. It arrives with what the prototype learned:
chalk is `inkOn(slate)`, a scrim needs a `LabTheme.scrim` role that darkens
in both palettes, a `safe` guard keeps it out of the narrator's strip, and
the 3D-plane variant (the same `Canvas` through `Texture { sourceItem }`)
is the next step, not this one.

### D6 The dive becomes a director shot, after four rig features

`director.descend(interior, presenter)` / `surface()` — `_shoot` plus three
extra floors captured and restored, plus a scale journey of the presenter.
It waits for: `OrbitCamera3D.applyState(s, ms)`, an `OrbitCamera3D.clipNear`
the rig owns, `fit()` of a box (or `corners(a, b)`), and a blendable
`Box3D`. Each is a small, separately shippable change; none is worth
working around a second time.

### D7 The goal/interpolant rule becomes doctrine

Every animated quantity in the kit is a goal plus a read-only `…Now`
interpolant, and every headless assertion reads the goal. That is what let
four lessons run under `Lab.runFlow` without an event loop. It goes into
the clay-lab skill's rules with the sentence the bench earned: *a flow
asserts what it asked for, never what the screen shows*.

### Resolved silently

A kit bench instead of a `labs/<lab>` lab (an evaluation, not a lesson to
ship); the transistor as the one subject; the professor at 4.6 not 6.2
beside one part; `xray` driven at 0.75; the facet exploding sideways; the
Narrator carrying the line while the slate is up; EN + DE strings from the
first commit; `electronics-101` untouched.

## 7. Phasing

1. **Kernel small pieces** — D4 (MarkLayer fix + cards), D5 (Chalkboard +
   chalk.js), the `LabTheme.scrim` role. Independent of each other.
2. **The subject contract** — D1, then D2 in the circuit kit; then the
   `meet` step of `electronics-101`'s `logic-gates` flow
   (`labs/electronics-101/Sandbox.qml:2061-2067`) gets `["xray", 0.75]`
   and captioned marks, and its `gain` step gets the chalk graph. This is
   the issue's original example, fixed.
3. **Director grammar** — D3 cues on the guide, an `anatomy` shot that
   frames the opened part with the floors relaxed like a portrait.
4. **The dive** — D6, once the four rig features exist. Blocks on nothing
   above but wants all of it.

Phases 1 and 2 can run in parallel; 3 wants 2; 4 wants 3.

## 8. Key code references

The prototype: `labs/kits/explain/README.md` (contract), `anatomy.js`,
`ExplodedView3D.qml`, `ExplodePart.qml`, `TransistorAnatomy3D.qml`,
`CalloutLayer.qml`, `Chalkboard.qml`, `chalk.js`, `DiveIn.qml`,
`TransistorInterior3D.qml`, `carriers.js`, `Sandbox.qml`, `strings.js`,
the four benches under `bench/`, and the three node suites registered in
`labs/CMakeLists.txt`.

Where the follow-up lands: `plugins/clay_lab/MarkLayer.qml:156-161` (the
projection), `plugins/clay_lab/CameraDirector.qml` (`_shoot`,
`_captureFloors`), `plugins/clay_canvas3d/OrbitCamera3D.qml` (`fit`,
`applyState`), `labs/kits/circuit/CircuitElement3D.qml:360-460` (the
transistor), `labs/kits/professor/FlowGuide.qml` (`_onCue`, `registerVerb`),
`labs/electronics-101/Sandbox.qml:2061-2067` (the `meet` step).

Deliberately untouched here: everything under `plugins/`,
`labs/electronics-101/`, `labs/kits/circuit/`.

## 9. Open — the forks the issue does not settle

- **D2's shape**: anatomy *as* the transistor visual (every part explodable,
  a frame-time question on the XOR board) or a `detail` node swapped in for
  the one part a lesson opens?
- **The chalkboard's place**: a screen overlay (built) or a plane in the
  scene the professor walks to and points at (proposed)? The drawing model
  is the same either way.
- **Presenter scale**: a one-part lesson wants a smaller professor than a
  board lesson (4.6 vs 6.2 here). Is that a lab setting, or does the
  director scale the presenter to the subject?
- **Copy**: the legs are captioned in conventional current, the dive shows
  electrons. Both are right; one lesson should pick a convention and say
  which.
