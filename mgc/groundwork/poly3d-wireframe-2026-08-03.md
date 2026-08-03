---
status: approved
tracker: https://github.com/MisterGC/clayground/issues/183
---

# Poly3D + per-object wireframe

## 1. Sizeable rating

| axis | rating | why |
| --- | --- | --- |
| effort / complexity | **high** | new C++ geometry type, a triangulation dependency, a new vertex-attribute contract, shader work in three files |
| risk (blast radius / reversibility) | **high** | changes the property surface and the *rendered look* of `Box3D` and `VoxelMap`, which every lab and example already uses |
| attention demand | **high** | "professional look" and "excellent performance" are judgement calls; the storage/quality trade-offs are baked into the vertex layout and expensive to unwind |

Earns a full groundwork: the vertex-attribute contract and the "who owns
edges" answer constrain everything built on `Canvas3D` afterwards, and two
of the three changes are visible in existing scenes.

> Note: three groundwork docs are still `awaiting-review`
> (`lab-authoring-harvest`, `lab-flows`, `lab-publishing`). This is a fourth
> open one.

## 2. The requirement, as I understand it

`Canvas3D` has a box, a voxel map, lines and labels — and **no area
primitive**. Anything shaped like a region (a lake, a plaza, a footprint, a
zone on the ground) has to be faked, today with a fan of horizontal ribbon
strips from `LineBatch3D` plus a hand-tuned depth ramp to stop the coplanar
strips z-fighting. That workaround cannot express a hole, its outline is only
as good as the line drawn over the strip ends, and it costs far more than the
shape deserves.

Separately, the edges `Box3D` and `VoxelMap` already draw are *face borders* —
a box shows its twelve borders and never its triangulation. When the mesh
itself is the subject (a lab explaining how a shape is built), those are the
wrong lines.

**What you get:** a `Poly3D` you can hand a ring of points and get a proper
filled area — planar, but freely orientable in space (D11), and either flat or
extruded into a prism — that can also show its own triangulation as crisp
screen-space-consistent lines, plus edges across the whole `Canvas3D` family
that can finally be *a colour* rather than "the fill, but darker".

Constraints you set, which I am treating as requirements:

- **Wireframe is optional, and paying for it is opt-in.** With edges off, the
  geometry uses the lean layout; turning them on rebuilds.
- **Not a mass-batch type.** A handful of objects, or one at a time on
  demand — not thousands.
- **Excellent performance and professional look.** Cheap when idle; when
  edges are on they must be genuinely crisp, not a shimmering approximation.
- **Must not feel alien** next to what `Canvas3D` already offers.
- **Flat polygons *and* meshes.** See D7 — this splits into two features and
  only one of them belongs in #183.

**Out of scope:** a mass-scale batched sibling (`PolyBatch3D`); textured
polygons; concave-with-self-intersection input (rejected, not repaired);
outline rendering for arbitrary loaded meshes (D7 — proposed as its own
issue); animated / per-frame-changing rings (rebuild cost is documented, not
optimised).

**Assumptions, please correct:**

- The polygon itself is **planar** — a ring of 2D points, not a 3D point
  cloud. Where that plane sits in space is free (D11).
- Ring sizes are tens to low hundreds of points, not thousands.
- Per-vertex colour on a polygon is not needed now, but closing the door on
  it would be a mistake.

## 3. Findings from the investigation

These are what the decisions below rest on; each is checked in the tree.

**F1 — there are already two unrelated edge techniques, not one.**
`Box3D` derives edges from face UVs with `fwidth` for screen-space-constant
thickness (`box3d.frag:107`). `VoxelMap` ignores UVs entirely and draws a
*procedural object-space grid* at voxel cadence (`voxel_map.frag:20`). They
look similar and share nothing.

**F2 — the voxel technique is the better one for voxels, and must stay.**
Greedy meshing merges a run of voxels into one quad with four corners
(`voxelchunk.cpp:124`). The procedural grid still draws every cell border
inside that merged quad. Any mesh-derived technique (barycentric included)
would collapse a merged 8×3 face to a single outline. So voxels do *not* want
the polygon technique.

**F3 — but the voxel thickness math is wrong, and fixably so.** It converts
pixels to world units as `distanceToCamera * edgeThickness / viewportHeight`
(`voxel_map.frag:29`), where `viewportHeight` is wired to
`Screen.desktopAvailableHeight` (`VoxelMap.qml:369`) — not the `View3D`'s
height — and the formula ignores FOV and surface foreshortening entirely. So
"thickness in pixels" is only accidentally true, on a maximised window, on a
face square to the camera. `Box3D` already moved to `fwidth`, which is
correct on all three counts, and left the uniform behind as dead
(`box3d.frag:16`). **This is the concrete answer to "can the voxels benefit":
yes — not from the polygon geometry, but from its edge *math* and its
colour.** Split out as **#184** and worked alongside this; D6 records the
decision, P5 the pass over existing scenes.

**F4 — neither type can express "dark grey edges on a purple face".** Both
only have `edgeColorFactor`, a multiplier on the fill (`box3d.frag:129`,
`voxel_map.frag:43`). On a light fill the edges come out nearly invisible.
This is the smallest and most immediately visible win in the whole issue.

**F5 — the free attribute slots.** `QQuick3DGeometry` offers Position,
Normal, TexCoord0/1, Tangent, Binormal, Color, Joint, Weight. `Box3D` uses
Position+Normal+TexCoord0 (`box3dgeometry.cpp:350`); `VoxelMap` uses
Position+Color+Normal (`voxelmapgeometry.cpp:423`). **TexCoord1, Tangent and
Binormal are unused across the plugin** — there is room for a barycentric
attribute without displacing anything.

**F6 — triangle wireframe forces unshared vertices.** Per-triangle
barycentric coordinates cannot be shared between triangles, so index reuse is
gone in wireframe mode. For a 60-point ring: lean indexed layout ≈ 2.1 KB
(60 verts × 24 B + 174 indices), wireframe layout ≈ 6.3 KB (174 verts ×
36 B, unindexed) — **about 3×**. That is the honest price of the feature, and
the reason the lean layout is worth having.

**F7 — `Box3D` pays nothing for this.** It already emits 36 unshared
vertices with no index buffer at all (`box3dgeometry.cpp:318` sets vertex
data only). Adding barycentric costs 36 × 12 B = 432 bytes per box, once.

**F8 — "works for meshes too" is not one feature.** Triangle wireframe needs
per-vertex data, so it can only ever work on geometry *we* build. An
arbitrary `Model` — `#Sphere`, a loaded `.mesh`, a `Character3D` — has a
vertex buffer we do not own, and Qt exposes no per-object wireframe (see the
issue's Qt survey). The only thing that works there is an **inverted-hull
silhouette**: draw the mesh again, slightly grown, front-faces culled. That
is a genuinely different feature with a different look (silhouette, not
triangulation).

**F9 — selection already has a *marker*, which is a different job.**
`SelectionFrame3D` (`plugins/clay_lab/SelectionFrame3D.qml:1`) documents the
choice: *"Flat bars on the surface rather than a box around the object: the
frame then reads at any camera angle, never hides the object it marks, and
cannot fight the object's own silhouette."* That settles how selection is
*signalled*; it says nothing about what a selected object may then *show* of
itself. Wireframe-on-select as an inspection view sits on top of it rather
than against it. See D10.

**F10 — the family idiom is "rich few end / mass-scale end", stated
everywhere.** `Label3D` ↔ `LabelBatch3D`, `Line3D` ↔ `LineBatch3D`,
`StaticVoxelMap` ↔ `DynamicVoxelMap`. A new type that is explicitly *not*
for mass use has to say so in the same voice, or it reads as an omission.

**F11 — there is a 2D namesake.** `Clayground.Canvas`'s `Poly`
(`plugins/clay_canvas/Poly.qml:69`) takes `vertices`, `fillColor`,
`strokeColor`, `strokeWidth`. Two idioms pull on the naming — see D9.

**F12 — dependency precedent exists both ways.** `thirdparty/` vendors
qml-box2d and csv-parser; `clay_ai` and `clay_network` use `FetchContent`.

**F13 — there is no triangulation code in the tree, and never was.** Checked
both the working tree and the full history. Polygons exist here only as
*data* or as somebody else's problem: `svgreader`/`svgwriter` parse and emit
rings, `VisualizedPolyBody` hands vertices to Box2D (convex-only, and Box2D
does the work), and the 2D `Poly` delegates to `QtQuick.Shapes`, which
triangulates internally and exposes nothing. History turns up `ScalingPoly`
(deleted, 2D, also Shapes-based) and Box2D's own `b2PolygonShape` — no ear
clipping, no tessellator, nothing reusable. So the experiments you remember
did not leave a triangulator behind.

**F14 — `SceneLoader3d` cannot load a polygon at all.** It handles rectangles
and answers circles with `console.log("Not yet supported.")`
(`SceneLoader3d.qml:45`); there is no polygon branch, while `SceneLoader2d`
has had one for years (`SceneLoader2d.qml:56`). The SVG reader already emits
`polygon(id, points, fillColor, strokeColor, description)`. So `Poly3D` is
the missing half of "draw a lake in Inkscape, get it in the 3D world" — which
is the clearest answer to *when should this be used*.

**F15 — `CustomMaterial` shader snippets have no `#include`** (no snippet in
the plugin uses one, and Qt documents these as fragments it stitches, not
standalone shaders). Sharing edge code between the three shaders therefore
means duplicating a small block or concatenating at build time. **To be
confirmed in P0** — it decides whether "one edge helper" is real or aspirational.

## 4. Decisions

### Structural

#### D1 — `Poly3D` is the rich/few end, with no batch sibling in v1

One `Model`, one draw call, per polygon. Documented in the README in the same
voice as `Label3D` vs `LabelBatch3D` (F10), naming the ceiling explicitly
("tens of areas, not thousands") so the absence reads as a decision rather
than a gap. *Rationale:* matches the stated use, and a batched sibling later
is additive rather than a rewrite. Filed as **#185** so it is not forgotten.

#### D2 — two vertex layouts, switched behind the ordinary edge properties

**What the user writes is just the family's existing knobs** — nothing about
storage appears in the API:

```qml
Poly3D {
    vertices: [...]
    color: "#0f9d9a"
    showEdges: true              // off by default on Poly3D
    edgeMode: Poly3D.Triangles   // or FaceBorders
    edgeColor: "#2f3437"
}
```

Behind that: lean layout (default) is indexed, shared vertices,
Position + Normal — 24 B/vertex. Wireframe layout is unshared,
Position + Normal + barycentric — 36 B/vertex, no index buffer. Setting
`showEdges` rebuilds the geometry the first time.

*Rationale:* directly the "if not used, use more optimal storage" ask, at the
measured 3× (F6) — but the two layouts are an implementation detail, not a
second concept for the user to learn. `showEdges` is the same property name
`Box3D` and `VoxelMap` already use, so a reader who knows one knows all three.
(`showEdges` defaults to `false` here and `true` on `Box3D`: a box's borders
are its look, a polygon's triangulation is a deliberate choice.)

*The consequence to weigh:* if wireframe is ever driven by hover, every
hover-in rebuilds. So the buffer **upgrades but never downgrades** — once a
polygon has been asked for edges, it keeps the fat layout for its lifetime.
Toggling then costs a uniform write, not a rebuild. Worst case is memory, not
a frame hitch, which is the right way round.

#### D3 — barycentric rides `TangentSemantic` (vec3)

`vec3(baryU, baryV, edgeFlags)` — two barycentric coordinates plus three bits
saying which of the triangle's edges is a real boundary rather than an
interior diagonal, packed into the third float.

*Rationale:* Tangent is free (F5) and is a vec3, which the two-coordinate
encoding plus flags exactly fills. It leaves `Color` free for the per-vertex
tint we might want later and `TexCoord0` free for texturing — spending either
of those on plumbing would be the expensive mistake. The flags are what let
one attribute serve both `FaceBorders` and `Triangles` mode instead of
needing two techniques.

*Risk:* `TANGENT` in a `CustomMaterial` vertex shader is normally
tangent-space data. We do no normal mapping, so nothing collides — but Qt is
free to normalise, orthogonalise or regenerate the attribute, and if a future
Qt starts doing so, the diagonals simply stop appearing. Nothing in a build
log would say why.

**How we find out early — three layers, cheapest first:**

1. **A pixel test that fails when the attribute is mangled.** A two-triangle
   square rendered head-on with `edgeMode: Triangles` must have a dark pixel
   at its centre (the shared diagonal) and a light one a quarter of the way
   into a triangle. Sampling those two pixels is the whole assertion. If Qt
   ever normalises the vector, the barycentric values stop reaching 0 at the
   diagonal and the centre pixel goes light — the test names the cause in its
   failure message rather than leaving a mystery. This is the load-bearing
   one: it runs on every build and on every Qt upgrade, unattended.
2. **A one-line runtime check on the attribute contract**, guarding against
   the silent-nothing case: if `edgeMode: Triangles` is set and the shader
   compiles but the attribute is absent, warn under `clay.poly` rather than
   rendering an edgeless polygon that looks like a content mistake.
3. **A pitfalls entry** (`skills/clay-lab/references/pitfalls.md`), where the
   Qt Quick 3D traps already live, stating the contract in one sentence: *we
   use `TANGENT` as a data channel, not as a tangent; do not enable normal
   mapping on these materials.* That is what stops a future change from
   walking into it deliberately.

### External commitment

#### D4 — vendor `earcut.hpp` for triangulation

Checked first, as you asked: **there is nothing already in the tree** (F13).
The old polygon experiments went through `QtQuick.Shapes` and Box2D, both of
which triangulate internally and hand nothing back — so there is no earlier
work to revive.

Mapbox's earcut: single header, MIT, ~700 lines, handles holes by bridging,
robust on the degenerate input real data produces. Vendored into
`thirdparty/` (F12) rather than fetched, because a header-only library does
not need a build and the WASM target must not depend on network fetch at
configure time.

*Rationale:* the alternative is hand-rolled ear clipping, which is a
weekend to write and a year to make robust. Triangulation is not where this
feature's value is. `QPainterPath` + Qt's `qTriangulate()` is the third
option and is rejected: it is private API.

### Cross-cutting

#### D5 — `edgeColor` as an absolute colour on `Box3D`, `VoxelMap`, `Poly3D`

`edgeColorFactor` stays and keeps its meaning; `edgeColor` wins when set.
"Set" means **alpha > 0** — a fully transparent edge has no meaning, so it is
free to serve as the sentinel, and a plain `color` property defaults to
opaque black which would otherwise be indistinguishable from "unset".

*Rationale:* F4. This is independently shippable and changes no existing
scene's appearance.

#### D6 — one edge-thickness rule for the family: `fwidth`, in pixels — **#184**

`VoxelMap` adopts `Box3D`'s screen-space derivative math; the
`viewportHeight` uniform and the `Screen.desktopAvailableHeight` binding go
away in both.

*Rationale:* F3 — the current voxel math is wrong under FOV changes,
non-fullscreen views and grazing angles, and "professional look" does not
survive edges that thicken as the camera pulls back. Same knob, same units,
across all three types.

*This changes how existing voxel scenes look.* The thickness will not match
pixel-for-pixel. That is the point (it was wrong), but it needs a deliberate
before/after pass over the labs and examples in P5, not a silent swap.

#### D7 — arbitrary meshes are out of scope here; propose a separate `Outline3D`

#183 delivers triangle/border wireframe for geometry `Canvas3D` builds.
Silhouette outlining for any `Model` (F8) is a different technique with a
different look, and belongs in its own issue — where it can be judged on its
own merits (it is also the thing that would let a `Character3D` be outlined,
which the wireframe never can).

*Rationale:* folding both into #183 would mean shipping two rendering
techniques under one property name and having neither be clearly the answer
to "how do I outline a thing".

*This is the decision most likely to be wrong* if what you actually pictured
was "any mesh shows its triangles". If so, say — it changes the shape of the
whole feature.

#### D8 — `edgeMode: FaceBorders | Triangles` on `Box3D` too, always built

`Box3D` gets the barycentric attribute unconditionally rather than switching
layouts. *Rationale:* F7 — 432 bytes on a type that is already unshared. A
second code path to save that would cost more than it saves.

#### D9 — property surface follows `Canvas3D`, vocabulary follows `Poly`

`color`, `showEdges`, `edgeThickness`, `edgeColor`, `edgeMode` from the
`Canvas3D` family; `vertices` from the 2D `Poly` (F11). Plus `holes`,
`extrude` (0 = flat), `plane` (D11) and `depthBias`.

*Rationale:* how it composes with its neighbours matters more than how it
reads against its 2D namesake — but where the concept is genuinely the same
thing, the same word should mean it in both dimensions. Deliberately *not*
`fillColor`/`strokeColor`: in 3D the edge is a shaded surface feature, not a
stroke, and calling it one would promise dash patterns and joins that do not
exist.

`depthBias` is not cosmetic — a flat polygon on the ground plane z-fights
without it, and this is exactly the failure the strip-fill workaround hand-
tuned per strip.

#### D10 — wireframe is an inspection view; `SelectionFrame3D` stays the marker

Two different jobs, and they compose: the frame says *this one is selected*,
wireframe says *and here is what it is made of*. So a lab that wants "select a
thing, see its structure" writes `showEdges: selected` and gets both — the
frame still reads at any camera angle, the wireframe adds the detail. Nothing
about the selection language changes.

*Rationale:* F9 — the flat-bars decision is about how selection is *signalled*
and does not constrain what a selected object then reveals. D2's
upgrade-never-downgrade rule is what makes binding `showEdges` to `selected`
cheap enough to do per hover.

*Not in v1, but nothing here blocks it* — it is a two-line binding in a lab
once `edgeMode` exists, which is the right amount of machinery for a use case
we have not yet felt the need for.

#### D11 — planar polygon, freely orientable; `plane` names the three easy cases

The geometry is emitted in a local plane, and **any orientation in space is
already free**: a `Poly3D` is a `Node`, so `eulerRotation` / `rotation` /
`position` place it wherever it belongs. Nothing in the geometry has to know.

On top of that, a `plane: Poly3D.XZ | XY | YZ` enum (default `XZ`) decides
which two components a `vertices` entry maps to, and which axis the normal and
any `extrude` follow. It is pure vertex mapping — no extra vertices, no extra
branch at draw time, three lines in the builder.

*Rationale:* you had it right — once XZ works the other two are free, because
they *are* XZ with the components permuted. The enum exists only so the common
axis-aligned cases read as intent (`plane: Poly3D.XY` for a wall) instead of
as a `-90°` rotation the reader has to decode. Anything not axis-aligned is
the node's rotation, which is the answer the rest of Qt Quick 3D already gives.

*The one thing that is genuinely not free* is a **non-planar** ring — points
that do not lie in a common plane. Triangulating that has no correct answer
(it depends on a projection you would have to choose), so `vertices` stays 2D:
the type cannot be handed an unplanar ring in the first place. That is a
deliberate limit, not an omission.

### Resolved silently

- Rings are closed implicitly; a repeated last == first point is dropped.
- Winding is normalised in C++ (outer CCW, holes CW) rather than demanded of
  the caller.
- Degenerate input (< 3 points, all-collinear, zero area) yields empty
  geometry plus one `qWarning` under `clay.poly` — same shape as the
  `clay.voxel` warnings.
- Extruded side walls get their own normals (hard edges, no smoothing) —
  toon shading wants facets.
- `extrude: 0` emits no side walls and no bottom cap at all.
- `edgeMask` (the `Box3D` per-edge bitmask) is not extended to `Poly3D` —
  meaningless for an arbitrary ring.
- Triangulation runs on the calling thread. Ring sizes here are far below the
  point where the off-thread machinery `StaticVoxelMap` needs would pay off.

## 5. Phasing

Every phase after P0 is independently shippable, so this can stop at any
boundary without leaving something half-built.

- **P0 — spikes (small, de-risks the rest).** Confirm: Tangent survives to
  the shader untouched (D3); `fwidth` edges on a voxel face look right and
  the uniform can go (D6); earcut builds for WASM (D4); whether shader
  snippets can `#include` (F15). **Blocks on nothing, but its answers can
  change D3 and D6.**
- **P1 — `edgeColor` across `Box3D` / `VoxelMap` / `Poly3D`.** Self-contained,
  visible immediately, no geometry work. Ships alone.
- **P2 — `Poly3DGeometry`: flat fill, lean layout, holes, `plane`,
  `depthBias`.** No edges yet. At the end of this phase the strip-fill
  workaround is already replaceable.
- **P3 — barycentric attribute, `edgeMode`, `Poly3D.qml`.** The wireframe
  proper, including the diagonal pixel test that guards D3's Tangent
  contract.
- **P4 — `extrude`.** Prisms, side walls, caps.
- **P5 — `Box3D` `edgeMode`, and the voxel thickness unification (#184).**
  ⚠️ **Blocks on you**: D6 changes how existing scenes look, so this phase
  ends with a before/after pass rather than a green test suite.
- **P6 — bench entry, docs, pitfalls entry, and removing the workarounds from
  the skills.** Deletes the strip-fill and stub-disc folklore from `clay-lab`
  guidance rather than documenting around it.

Reorderable: P1 can land before or after P0. P4 can be deferred indefinitely.
P5 could precede P3 if the voxel fix is wanted sooner than the polygon.

**Deliberately not in this plan:** wiring `SceneLoader3d`'s missing polygon
branch (F14). It is the obvious payoff and it is one handler — but it belongs
to `clay_world`, not `clay_canvas3d`, and it should follow once `Poly3D` has
settled rather than ride along and blur what #183 delivered.

## 6. Key code references

| what | where |
| --- | --- |
| box edge shader (the technique that wins) | `plugins/clay_canvas3d/box3d.frag:107` |
| voxel edge shader (procedural grid — stays) | `plugins/clay_canvas3d/voxel_map.frag:20` |
| the wrong thickness math | `plugins/clay_canvas3d/voxel_map.frag:29` |
| `Screen.desktopAvailableHeight` bindings | `plugins/clay_canvas3d/VoxelMap.qml:369`, `Box3D.qml:170` |
| box attribute layout (already unshared) | `plugins/clay_canvas3d/src/box3dgeometry.cpp:318` |
| voxel attribute layout | `plugins/clay_canvas3d/src/voxelmapgeometry.cpp:419` |
| greedy quad emission (why F2 holds) | `plugins/clay_canvas3d/src/voxelchunk.cpp:124` |
| 2D namesake | `plugins/clay_canvas/Poly.qml:69` |
| selection language | `plugins/clay_lab/SelectionFrame3D.qml:37` |
| the missing 3D polygon branch (F14, follow-up) | `plugins/clay_world/SceneLoader3d.qml:45` |
| new: `src/poly3dgeometry.{h,cpp}`, `poly3d.{vert,frag}`, `Poly3D.qml` | `plugins/clay_canvas3d/` |
| new: vendored triangulator | `thirdparty/earcut/` |

**Untouched on purpose:** `voxelchunk.cpp` and the greedy mesher (F2 — the
voxel technique is not the one being replaced); `linebatchgeometry.cpp` and
the whole line family (the strip-fill workaround is *retired*, not
refactored); `clay_character3d` (D7 puts it behind the separate outline
issue).

## 7. Drift — what changed during implementation

- **D9 was wrong about `depthBias`, and it matters.** In Qt Quick 3D
  `Model::depthBias` biases the distance used to *sort* objects; it is not a
  polygon depth offset. Measured on a coplanar ground polygon at a grazing
  angle: surviving pixels out of ~3600 were 199 at bias 0, 925 at 500, 962 at
  100000, 233 at −100000 — versus 3613 for a plain 0.5 lift along the normal.
  So it only decides exact depth ties and does nothing about the fight itself.
  The z-fighting claim stands; the cure named in D9 does not. **Open design
  call:** document "lift it yourself", or add a `surfaceOffset` that
  translates along the plane normal. Knock-on: the strip-fill workaround's
  hand-tuned depth ramp is *not* replaceable by `depthBias` (P6).
- **D4: earcut is ISC, not MIT.** Permissive and compatible; the vendored
  LICENSE says ISC. Version v3.2.3, commit `c68c8835`.
- **D11 is cheap but not symmetric.** XZ is left-handed against +Y, so a ring
  that is CCW on paper faces *down* there while the same ring faces the camera
  under XY/YZ. Resolved by normalising winding **per triangle** at emission
  (2D cross sign, swap two indices) rather than per ring per plane — which
  also makes us independent of earcut's own output convention.
- **`addAttribute()` appends**, so a geometry rebuild must `clear()` first or
  attributes stack. `Poly3DGeometry` does; `box3dgeometry.cpp` does not, and
  was left alone.
- Files touched beyond the phase's stated scope: root `CMakeLists.txt` (one
  `add_subdirectory`), `demo/qmldir` and `demo/Sandbox.qml` (one line each).
- Still open from D1: the README ceiling statement ("tens of areas, not
  thousands") lives only in the `Poly3D` QDoc so far.
- **Two independent reasons voxel edges were invisible by default, not one.**
  F3 found the thickness math; verified afterwards by render, `VoxelMap`'s
  default `edgeColorFactor` is **1.0** (`VoxelMap.qml:108`) — edge colour
  equals fill colour, so edges could not show at *any* thickness. A 10×10 face
  square to the camera drew nothing at thickness 0.05, 0.4, 5 and 50 alike.
  With the factor lowered, the old default drew 1 grid line of 18; with the
  new math and `edgeColor` set, all 18 at one clean pixel. This makes D5 the
  load-bearing change rather than the small one.
- **D6 did not actually unify the units.** `Box3D` and `VoxelMap` now share
  the property name and both go through `fwidth`, but not the resulting width:
  `VoxelMap` draws a solid line of N pixels while `Box3D` smoothsteps its
  border over N in UV space, so the box line comes out several times thinner.
  Measured: `Box3D` at `edgeThickness: 8` yields roughly a 2 px border, and at
  3 px it is invisible next to a bold voxel grid at the same setting. The demo
  carries a documented ×4 factor on the boxes to make the pair comparable.
  **Open:** unify for real, or rename so the two knobs stop implying parity.

## 8. grafli

Warranted — five components plus a new dependency and a new attribute
contract. Not yet authored; the prose above stands on its own, so it is worth
correcting the framing first and drawing the agreed one.
