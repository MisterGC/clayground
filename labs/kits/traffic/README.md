# Traffic kit — draw a street network, watch what it does

Three layers: an editable planar road graph, a lane model derived from it,
and a microscopic car simulation that runs on the lanes. Draw a road and
junctions, lanes, turn connectors and conflicts all appear because they were
*derived*, not authored.

Used by `labs/street-network-101/`. Checked by
`node labs/kits/traffic/traffic.test.js` (135 assertions).

## Model card

*A lab card in the sense of a spec sheet: what this kit is a model of, what
it deliberately is not, and therefore which questions it can be asked.*

### What it models

**(1) `roadgraph.js` — the plan.** Nodes joined by straight segments, with
one invariant everything downstream rests on: **the graph stays planar**.
Two roads may only meet at a node, so inserting a road splits whatever it
lands on *and* everything it crosses, laying itself down as a chain through
those crossings. **Turn bans** are keyed on `(node, from-road, to-road)` and
are **directed** — banning A→B says nothing about B→A, which is how a real
"no left turn from Main into Elm" works — and keying them on roads rather
than on derived lanes is what lets a ban survive a lane-count change, a node
move, a reload, and a split of the road it names.

**(2) `lanemodel.js` — the derivation.** Road graph → lane graph in three
steps a traffic engineer would recognise:

- **Junction boxes.** For two legs at angle *t*, a point *d* along one sits
  `d · sin t` from the other's centreline, so clearing half-width *h* needs
  `d >= h / sin t`; the node radius is the maximum over all leg pairs,
  capped at 0.34× the shortest incident road. Near-parallel legs need
  nothing — which is exactly why a straight-through node gets no box and a
  right-angle bend does.
- **Lane centrelines**, `lanes` per direction, offset `(k + 0.5) · LANE_W`
  with `LANE_W = 3.5` to the right-hand side. Lane 0 is the kerb lane.
- **Turn connectors**: every arriving lane joins one lane of every *other*
  road at the node — no U-turns, which is what makes a dead end a dead end —
  as a quadratic Bézier through the intersection of the two lane lines.
  Two connectors **conflict** if their polylines cross *or* if they feed the
  same lane (a merge is a conflict even though the curves only touch at the
  end).

**(3) `traffic.js` — the sim.** Deterministic: every draw comes from the
`rng` handed in, and `step()` takes a fixed `dt`, so a run is reproducible
from `(seed, graph, parameters)` alone. Three rules:

- **Follow** — a gap rule, *not* IDM: the desired gap is
  `minGap + v · headway`,
  braking proportional to how badly the gap is missed, acceleration
  otherwise. Look-ahead extends one element past the current one, so a queue
  backs up *through* a junction rather than piling into it.
- **Yield** — the whole right-of-way model. A turn is *claimed* while a car
  is in it; a car may enter only when that turn and every conflicting turn
  are unclaimed **and the exit lane has room** — the last condition is what
  stops a junction filling with cars that cannot leave. A grant is a
  **booking** held until the car is through, not a per-step verdict, and
  requests are ordered by waiting time so a busy approach cannot starve a
  quiet one.
- **Leave** — a lane with no exits is a dead end; the car fades and is gone.

Cars spawn **anywhere there is room on any lane**, which is what makes the
*network* the subject rather than an entry point. `demand` is therefore a
request, not a command: a spawn still needs a clear gap.

**(4) Houses — fixed origins and sinks, opt-in.** Pass `par.houses` (node
ids) and journeys stop being anonymous: a car is placed only on a lane
*leaving* a house, and a car reaching the far end of a lane *arriving* at one
is absorbed there and counted (`arrived`, `arrivedAt`, and a smoothed
`arrivalRate` in cars per minute, over the same 12 s window as the per-road
rate). Pair it with `par.target`, an explicit fleet size that overrides the
lane-length rule.

That pairing is the point. Without it `demand` scales with lane length, so a
larger network silently gets more cars and a comparison of two *shapes*
measures how much road was drawn. Pin the houses and pin the fleet, and two
plans over the same four points differ only in their topology — which is what
makes `labs/street-network-101/studies/` possible at all.

What houses are **not**: destinations. There is still no routing (see below).
A car leaving house A does not aim for house B; it walks the network at
random and is absorbed by whichever house it reaches first. "Arrivals" is
therefore a measure of how well the network *delivers traffic between fixed
points*, not of anybody completing an intended trip.

### Deliberate simplifications

- **Roads are straight segments**; curves are several of them. No
  super-elevation and no curve speed limit beyond a flat factor on
  non-straight connectors.
- **No traffic signals and no priority roads.** Right of way is
  first-come-first-served by booking. Turn bans are the only junction
  control on offer.
- **No routing.** At a junction a car picks **uniformly** among its legal
  exits. There is no shortest path and no destination *choice* — the subject
  is what the *network* does, not what a commuter wants. Trip length is
  therefore a random walk, and absorption (at a dead end, or at a house)
  governs how long a car lives. Houses fix *where* journeys begin and end;
  they do not give a car anywhere it is trying to get to, so an "A→B trip
  time" is not a quantity this kit has.
- **No lane changing.** A car keeps its lane until a turn moves it, so on a
  two-lane road a slow leader blocks its lane permanently and overtaking can
  never relieve congestion.
- **Car following is a hand-rolled gap rule**, not a calibrated model: no
  equilibrium time headway, no free-acceleration exponent, no reaction time.
- **Turn lane assignment is index mirroring** (kerb to kerb, clamped) — no
  turn pockets, no lane-use signage.
- **Flow is counted at lane exit**, not at a fixed detector cross-section.
- Speed spread between cars is cosmetic, present because identical cars make
  a queue look like a train.

### Where it stops being valid

- **Anything whose answer depends on signals, priority, lane changes or
  route choice is out of scope** — signal offsets, green waves,
  priority-road capacity, weaving sections, and travel-time-driven route
  effects such as Braess's paradox.
- **What saturates here is not the fundamental diagram.** Throughput
  plateaus rather than collapsing, because this model never forces a car
  into a gap that is not there. Asking for 3× the traffic yields the same
  cars at the same speed, and that is a property of the spawn rule as much
  as of the network.
- **Free flow only holds below roughly demand 0.4.** Above that, a
  comparison between two network shapes mixes topology with congestion.
- **Junction deadlock is a fixed bug kept as a regression, not an
  impossibility.** An earlier paper reported a "dramatic collapse above
  demand 0.85" that turned out to be a booking held by a car that could not
  reach it — exactly the kind of result a simulation will happily hand you.
  Four `(seed, demand)` pairs are pinned in the suite; any of them going
  still again means the invariant broke.
- **Geometric degeneracies are real.** Near-parallel legs get no clearance
  (the formula divides by a vanishing sine); a short block between two large
  junctions gets an artificially small box; roads under 7 units are refused.
  Lane count is clamped to 1–2 per direction.
- **Conflict detection samples the connector polylines** and only counts
  interior crossings, so a near-tangential turn pair can be missed.
- **After a graph edit, cars are re-homed approximately** (nearest lane
  within 9 units and agreeing in heading); the rest are dropped.
- **Hard ceilings**: 140 cars in the sim, 160 drawable.

### What you can vary

| knob | default | range where a lab exposes it |
|---|---|---|
| `demand` | 0.5 | 0.05 – 3.0, cars asked for per unit of lane |
| `vmax` | 15.0 | 5 – 28 u/s |
| `accel` / `brake` | 7.0 / 18.0 | source-level |
| `headway` / `minGap` | 0.85 s / 2.4 | source-level |
| `maxCars` | 140 | source-level ceiling |
| `houses` | `null` (open model) | node ids; journeys start and end there |
| `target` | `null` (lane-length rule) | explicit fleet size, clamped by `maxCars` |

Plus the network itself, which is the real knob: insert and remove roads and
nodes, split a road, set 1 or 2 lanes per direction, and ban any individual
turn.

### What you can measure

`summary()` gives `cars`, `target`, `spawned`, `goneAtDeadEnds`,
`meanSpeed`, `stoppedShare` and `simTime`; with houses declared it also gives
`arrived` (journeys that reached a house — kept apart from `goneAtDeadEnds`,
which is journeys that ran out of road), `arrivedAt` (per house node) and
`arrivalRate`. `roadRate(roadId)` gives a
smoothed per-road flow in cars per minute. The lane model publishes
`stats`: nodes, roads, lanes, connectors, banned turns, junctions, dead
ends, total lane length and **conflict pairs**. Derived quantities the
existing paper builds from these: throughput (cars × mean speed), mean car
lifetime, dead-end share of lane length, and the share of turns whose target
lane is terminal.

### Questions it can answer

- What does a network's *shape* cost, holding demand fixed? (Grid versus
  ring versus cul-de-sac at the same `demand` and seed.)
- Which of several networks over the **same fixed points** moves traffic
  between them most, or most steadily? (Houses + `target`, several seeds —
  `labs/street-network-101/studies/topology-four-houses/` is the worked
  example.) The answer is about delivery between fixed points, not about
  anyone's commute.
- Where is the capacity ceiling of a given layout, and what is binding at
  it — junction conflicts, dead ends, or lane length?
- What does one banned turn do to the whole network, and is the effect local?
- How many conflicts does a junction geometry actually create? (Read
  `conflicts` per connector: seven for a left turn, two for a right, at a
  four-way of one-lane roads.)
- How long does a car survive before a dead end absorbs it, and how does
  that scale with the share of terminal turns?

### Questions it cannot answer

- *"Should this junction be signalised?"* — there are no signals to compare
  against.
- *"Will this change reduce commute times?"* — houses give journeys fixed
  ends, but no driver chooses one, so a trip here is still a random walk.
- *"How much traffic goes from house A to house B?"* — arrivals are counted
  per house, never per origin/destination pair; a car's origin is not carried
  with it, and no car is trying to reach a particular house anyway.
- *"Is the traffic between the houses fairly shared?"* — `arrivedAt` gives
  per-house totals, but they are not a recorded series, so a study can quote
  a final split and not its behaviour over time.
- *"What is the road's capacity in veh/h?"* — the follow model is
  uncalibrated and the spawn rule, not driver behaviour, sets the plateau.
- Anything about overtaking, weaving, or multi-lane strategy.

## API

- `roadgraph.js` — `empty`, `clone`, `insertRoad`, `splitRoad`,
  `removeRoad`, `removeNode`, `pruneOrphans`, `setLanes`, `nearestNode`,
  `nearestRoad`, `closestOnRoad`, `bounds`, `totalLength`; bans via
  `isBanned` / `setBanned` / `toggleBanned` / `pruneBans`.
- `lanemodel.js` — `derive(graph)`, `deadEnds`, `poseOn`, `elementLength`;
  render helpers `surfaceRuns`, `laneRuns`, `markingRuns` (all emitting
  plain coordinate runs, never Qt types, so the kit runs under node).
- `traffic.js` — `defaultParams`, `createState`, `step`, `rehome`,
  `targetCount`, `originLanes`, `meanSpeed`, `stoppedShare`, `roadRate`,
  `arrivalRate`, `summary`.
- QML: `Cars3D` (one instanced fleet, slots held for a car's lifetime so it
  does not flicker through the palette), `Streets3D`.
- `strings.js` — the kit's EN/DE vocabulary.

## Tests

```bash
node labs/kits/traffic/traffic.test.js
```

Covers graph planarity and ban migration, the lane derivation's geometry,
and the sim's invariants — including byte-for-byte determinism over 900
steps and the four pinned deadlock regressions.
