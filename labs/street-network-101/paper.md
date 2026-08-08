# Street Network 101 — why the shape of a city decides its traffic

A lab about the step every traffic model has to take before it can move a
single car: turning **roads a human drew** into **lanes a car can drive**.
You build the network yourself, the lane model follows, and then the cars
tell you what you built.

Companion board: `overview.grafli`. Runnable lab: `Sandbox.qml`.

## The question

A road is a line between two points. A lane is a thing with a direction, a
side of the road, a place it comes from and a set of places it may go. Nothing
about the second is drawn by hand — all of it is *derived* from the first, and
that derivation is the whole subject:

- Where two roads cross, who owns the overlap?
- Which side does a car drive on, and how far from the centre?
- Arriving at a junction, which turns are legal, and which two turns may not
  be taken at the same moment?
- And when a road simply stops — what happens to a car on it?

Once the lane graph exists, a second question becomes askable, and it is the
one the lab is really for: **how much of a network's behaviour is decided by
its shape alone?**

## The derivation

Three steps, each a rule a traffic engineer would recognise
(`labs/kits/traffic/lanemodel.js`).

**1 — Junction boxes.** At a node, each leg is trimmed back far enough to
clear every other carriageway crossing it. Two legs meeting at angle *θ*, the
second with half-width *h*: a point *d* along the first sits *d·sin θ* from
the second's centerline, so clearing it needs

    d ≥ h / sin θ

The node's radius is the largest such *d* over all its legs, capped at a third
of the shortest road running into it so a short block still has lane left
between two boxes. Two consequences fall out for free: a right-angle bend of
two 7-unit roads gets a box of exactly one half-width (3.5), and a *collinear*
joint — two roads continuing straight through a node — gets a radius of
**zero**, because sin θ vanishes and there is nothing to clear. A straight
continuation is not a junction, and the geometry says so without being told.

**2 — Lane centerlines.** Each road carries `lanes` lanes per direction,
offset to the right of the centerline for right-hand traffic. With forward
direction **u** in the XZ plane, the right-hand normal is

    r = u × ŷ = (−u_z, u_x)

so lane *k* of the forward direction sits at `(k + ½)·W·r` with W = 3.5, and
the backward direction mirrors it. Lane 0 is the kerb lane.

**3 — Turn connectors.** Inside the box, every arriving lane is joined to one
lane of every *other* road at that node by a quadratic Bézier whose control
point is where the two lanes' own lines cross — so the curve leaves along the
incoming lane and arrives along the outgoing one. The target lane index
mirrors the source (kerb to kerb), clamped to what the target road has, so a
fan never crosses itself.

**No U-turns.** An arriving lane is never joined back to its own road. This
single omission is what creates dead ends: at a degree-1 node there *is* no
other road, so the arriving lane has no exits at all. A dead end is not a
special case in the code — it is a lane whose exit list is empty.

A four-way crossing of two one-lane roads therefore derives to 8 lanes and 12
turns: four straight, four left, four right.

## Right of way

Two turns **conflict** if their curves cross, or if they feed the same lane (a
merge conflicts even though the paths only touch at the end). Conflicts are
computed once, at derivation time, by sampling the curves and testing segment
intersections. A plain four-way crossing yields 30 conflicting pairs.

The rule the sim then applies is one sentence: **a car may enter a turn only
when neither that turn nor any turn conflicting with it is claimed, and its
exit lane has room.** A claim is held for as long as the car is inside. That
is the entire right-of-way model — no signals, no priority roads — and it is
enough to make a crossing look like a crossing.

Two things about it are load-bearing, and both were found the hard way:

- **A grant is a booking the car keeps, not a verdict re-taken each step.**
  Re-polling livelocks: a car's waiting time resets the instant it starts
  rolling, so the car just waved through immediately loses priority to the
  ones still standing, brakes, and re-queues. Mean speed collapsed to 1.4 of a
  15 free-flow maximum with 20 of 24 cars standing.
- **Only the car at the stop line may hold a booking, and that has to be
  re-checked every step.** Being the lead car when the booking was granted is
  not enough — another car can spawn in front afterwards. The car behind then
  holds a turn it can never reach while the car ahead waits on a conflicting
  turn that the booking blocks, and neither ever moves. Revalidating the
  booking each step is what makes the invariant self-healing; a sweep of 625
  runs (5 network shapes × 5 demand levels × 25 seeds) is clean only with it.

## Turn restrictions

A movement can be switched off. A restriction is keyed on
**(junction, arriving road, leaving road)** and is **directed**: closing
A → B says nothing about B → A, exactly as a real "no left turn from Main
into Elm" does. Keying it on roads rather than on derived lane pairs is what
lets it survive everything that re-derives the lane model — a lane-count
change, a node move, a reload, and the split of a road it names (the ban
follows the half that still reaches the junction).

A banned movement is still built and still drawn, dashed and in the alarm
colour. A restriction you cannot see is one you cannot undo — and the drawn
curve is also the thing you click to lift it.

The consequence worth noticing: it is not a decoration but a modelling tool.
Ban every exit from a lane and *that lane becomes a dead end* — no special
case anywhere, just an empty exit list, and cars begin fading out at a place
that used to be a through road.

### Closing turns changes capacity, and the sign is not obvious

Every interior four-way of the grid, one class of movement closed at each,
three seeds averaged:

| demand | restriction | cars | speed (u/s) | waiting | throughput |
|---|---|---|---|---|---|
| 0.5 | everything open | 23.7 | 11.50 | 6 % | 273 |
| 0.5 | no left turns | 23.6 | 12.64 | 3 % | **299** |
| 0.5 | no right turns | 23.7 | 10.29 | 11 % | 244 |
| 0.5 | no straight through | 23.8 | 11.17 | 8 % | 266 |
| 1.5 | everything open | 67.9 | 6.34 | 25 % | 431 |
| 1.5 | no left turns | 65.6 | 7.50 | 15 % | **492** |
| 1.5 | no right turns | 70.0 | 4.93 | 33 % | 345 |
| 1.5 | no straight through | 68.7 | 5.87 | 24 % | 403 |

**Taking a movement away makes the network carry more.** Banning left turns
lifts throughput 14 % at demand 1.5 (431 → 492) and cuts the standing share
from 25 % to 15 %. Banning right turns costs 20 %.

The mechanism is in the conflict sets, and it is worth reading off the model
rather than being told. At a four-way crossing of one-lane roads:

| movement | conflicts with |
|---|---|
| right turn | 2 movements |
| straight through | 6 movements |
| left turn | **7 movements** |

A left turn crosses almost everything else, so it holds the junction against
the most traffic; removing the four of them frees the crossing far more than
it costs in detour. A right turn blocks almost nothing, so banning it only
pushes cars onto movements that block more. This is why real networks
restrict left turns and not right ones, and here it is a measured consequence
of a conflict rule rather than a fact anybody wrote down.

## Stated simplifications

This is a teaching model, and it is worth being explicit about what it is not:

- Roads are **straight segments**; curves are built from several.
- The graph is kept **planar** — roads meet only at nodes. Drawing across an
  existing road splits both; a node drag that would create a crossing without
  a junction is refused rather than allowed to produce a plan whose lane model
  no longer matches what you see.
- **No traffic signals and no priority roads.** Right of way is
  first-come-first-served by booking, ordered by waiting time so a busy
  approach cannot starve a quiet one. Turn restrictions are the only
  junction control the lab offers.
- **No routing.** At a junction a car picks uniformly among its legal exits.
  There is no origin, no destination, no shortest path — deliberately, because
  the subject is what the *network* does, not what a commuter wants.
- **No lane changing.** A car stays in the lane it was given until a turn
  moves it.
- Car following is a simple gap rule (a desired gap of `2.4 + 0.85·v`), not a
  calibrated model such as IDM.
- Cars **spawn anywhere there is room** and vanish at dead ends. Nothing
  enters from off-stage.

## Measured results

All figures from the lab itself, sim time only, averaged over 50 s after a
20 s settling period. Seed 42.

### Shape decides how long a car survives

At demand 0.4, where every scenario is still in free flow (≤5.4 % of cars
waiting), so the comparison is about topology and not congestion:

| scenario | dead-end share of lane | junctions | turns | cars | speed (u/s) | lost/min | mean lifetime |
|---|---|---|---|---|---|---|---|
| crossroads | 50.0 % | 1 | 12 | 5.9 | 12.60 | 54.0 | **6.6 s** |
| cul-de-sac | 28.0 % | 4 | 28 | 8.8 | 13.49 | 81.6 | **6.5 s** |
| grid | 17.8 % | 9 | 108 | 18.7 | 12.03 | 112.8 | **10.0 s** |
| ring | 6.2 % | 4 | 32 | 12.0 | 13.23 | 25.2 | **28.5 s** |

A car on the ring lives **4.3× longer** than one at the lone crossroads, at
essentially the same speed. The network is not slower — it is *leakier*.

The predictor is not the length of the dead ends but the chance of *choosing*
one. Let *p* be the share of turns whose target lane is terminal; a car then
survives about 1/*p* junctions, each costing roughly one mean lane length at
free-flow speed:

| scenario | p | 1/p | mean lane | predicted lifetime | measured |
|---|---|---|---|---|---|
| crossroads | 1.000 | 1.0 | 71.5 | 5.5 s | 6.6 s |
| cul-de-sac | 0.357 | 2.8 | 40.4 | 8.7 s | 6.5 s |
| grid | 0.333 | 3.0 | 37.2 | 8.6 s | 10.0 s |
| ring | 0.125 | 8.0 | 53.6 | 33.0 s | 28.5 s |

A one-line random-walk argument lands within about a third of the simulation
across a fivefold spread. It is worst on the cul-de-sac, where the walk is
least uniform — cars spawn on the dead-end branches too, so they start closer
to absorption than the model assumes.

Note that the crossroads has *p = 1*: every exit from its single junction
leads to a stub. It cannot recirculate a single car, which is why 50 % of its
lane length being terminal understates how leaky it is.

### A network has a capacity, and asking for more does not raise it

Demand swept on the grid, three seeds averaged:

| demand | cars asked | cars held | speed (u/s) | waiting | throughput (car·u/s) |
|---|---|---|---|---|---|
| 0.5 | 24 | 23.7 | 11.50 | 5.6 % | 273 |
| 1.0 | 47 | 46.4 | 7.89 | 19.2 % | 366 |
| 1.5 | 71 | 67.9 | 6.34 | 25.0 % | 431 |
| 2.0 | 94 | 77.0 | 5.72 | 27.9 % | 441 |
| 2.5 | 118 | 78.5 | 5.66 | 27.9 % | 444 |
| 3.0 | 140 | 78.5 | 5.66 | 27.9 % | 444 |

Up to demand ~1.5 the network holds what it is asked to. Past that the two
columns come apart and by 2.5 the network is **saturated at ~78 cars** and
flatly refuses more — a spawn needs a clear gap, and there are none. Asking
for three times the traffic yields the same cars at the same speed. The gap
between "asked" and "held" is the network's capacity making itself visible,
and the lab prints it.

Honest caveat: this is a *saturation*, not the classic collapse of the
fundamental diagram. Throughput plateaus rather than falling over, because
this model never forces a car into a gap that is not there. An earlier
version of this paper reported a dramatic collapse above demand 0.85 — that
was the junction deadlock described above, not traffic physics, and it went
away when the bug did. It is recorded here because it is exactly the kind of
result a simulation will happily hand you.

### The derivation, checked

`node labs/kits/traffic/traffic.test.js` — 110 assertions covering the graph
editing, the derivation, turn restrictions and the sim's invariants,
including the two deadlock regressions and the ban-follows-a-split case. Determinism is checked in the lab as well: two runs of 1800
stepped frames from the same seed produce byte-identical car state and
counters, and a reload restores the drawn plan, the exact car positions, the
clock and the watched set unchanged.

## Things to try

- Build a **crossroads**, run it, then join the four stubs into a ring. Watch
  "left at dead ends" stop climbing.
- Turn demand up until the "asked for" and "held" numbers separate, then find
  the demand where the waiting share stops rising — that is the capacity.
- Press **V** and compare flow numbers on a through road and a side road of
  the grid: the grid's own asymmetry is visible without any traffic being
  routed anywhere.
- Draw one long road straight across a finished grid and watch every crossing
  appear at once — one gesture, many intersections, the lane model following
  each of them.
- Give one road **two lanes each way** and see the turn fan at its junctions
  double.
- Watch two roads (**W**) and switch the plot to *Load* — the queue building
  on one approach and draining on the other is the booking rule, visible.
- Select a crossing and close its left turns, then watch the standing share
  in the network panel fall. Then close the right turns instead and watch it
  rise. The junction has not got smaller either time.
- Close **every** movement at one junction (**X**) while traffic runs: the
  approaches turn into dead ends and cars start dissolving where a through
  road used to be.

## Run it

```bash
./build/bin/claydojo --sbx labs/street-network-101/Sandbox.qml
```

One rule for the pointer: **a click selects, a drag draws.** Drag from open
ground, from a dead end (that is how two of them get joined), or off the
middle of a road (that is how a T-junction appears). While you drag, a green
ring means "joins that point" and a green cross means "splits that road
here", so the answer arrives before you let go. Moving a node is a second
act: select it, then drag it. Right-drag turns the view.

Select a junction and its legs are named on the plan, matching the rows and
columns of a matrix on the right: rows are the road you arrive on, columns
the road you leave by. Click a cell — or the turn curve itself — to close
that movement.

`S` starts and stops the traffic. Stopping clears the cars away so the plan
is yours to work on; starting seeds a fresh run from the seed, so the same
plan always produces the same traffic.

Keys: `1`–`4` scenarios · `S` simulate · `C` clear · `E` erase · `L` lane
model · `V` flow numbers · `M` lane graph · `W` plot the selected road ·
`X` close/open every movement at the selected junction · `#` grid mode ·
`Del` remove · `Esc` cancel · `Shift+R` record a run · `F` frame selection ·
`0` reset view.

## Source map

| file | what is in it |
|---|---|
| `labs/kits/traffic/roadgraph.js` | the editable planar graph: joining, splitting, crossing, the planarity invariant, directed turn bans |
| `labs/kits/traffic/lanemodel.js` | the derivation: junction radii, lane offsets, turn curves, conflicts |
| `labs/kits/traffic/traffic.js` | the sim: follow, yield, leave; spawning, re-homing after an edit |
| `labs/kits/traffic/traffic.test.js` | 110 assertions over all three, no engine needed |
| `labs/kits/traffic/Streets3D.qml` | asphalt, paint, lane overlay, chevron flow |
| `labs/kits/traffic/Cars3D.qml` | the instanced car population |
| `labs/street-network-101/Sandbox.qml` | the lab: drawing, HUD, scenarios, lane graph view |
