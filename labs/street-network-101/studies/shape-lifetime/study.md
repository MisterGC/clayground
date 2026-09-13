# Four shapes, one demand — how long does a car survive on each?

*A study against `labs/street-network-101`. Kit model card:
`labs/kits/traffic/README.md`. Companion paper: `../../paper.md`.*

## The question

Four road networks, each drawn by one of the lab's presets, each fed the
same light demand. A car on any of them drives until it runs out of road:
there is no routing, and a lane with no exit ends the journey.

**How long does a car survive on each shape, and what about the shape
decides it?**

*Survive*, not *arrive*: these four plans have no houses, so nothing ever
arrives anywhere. What differs is how often a car's random walk through the
junctions lands on a stub, and the study's claim is that this is a property
of the plan that can be read off the lane model before any car has moved.
The objective is the **mean lifetime** of the cars that have left (maximize),
with the **loss rate** — cars running out of road per minute — quoted beside
it, because a plan that holds five cars and one that holds nineteen are not
comparable on lifetime alone.

The four candidates, all the lab's own presets:

| id | shape | what it is |
|---|---|---|
| `crossroads` | one crossing, four stubs | every exit from the one junction is a dead end |
| `cul-de-sac` | a spine with four branches, two joined | a tree with a few loops |
| `grid` | three by three crossings | many junctions, some stubs at the edges |
| `ring` | a loop with a bar across and two spurs | most of the road is a loop |

## Answerability

Before running anything: every quantity the question needs, mapped onto a
probe, a preset, or a model-card claim.

| the question needs | maps to | how it is checked |
|---|---|---|
| "the same demand" on every shape | `demand` = 0.4, `speed` = 15 | `fixed`, checked against `labInfo().params` by `lab-sweep --check` |
| the shape as the thing varied | four `scenario` levels, the lab's own presets | each is one of `scenarios()`, checked likewise |
| how long a car lives | the `lifetime` probe: mean age of every car that has left, in seconds | `labInfo().probes`; the *last* sample of a run is the mean over the whole run |
| how fast the plan leaks | the `lost` probe: departures at dead ends per minute, smoothed over the kit's 12 s window | likewise |
| that the plan is in free flow | `mean(waiting)`, `mean(meanSpeed)` | read out of each record |
| how many cars the plan held | `mean(cars)` | likewise |
| how leaky the *shape* is, before any traffic | the plan-constant probes `deadEndShare`, `junctions`, `turns`, `pTerminal`, `meanLane` | recorded with stddev 0 in every run, which is the check that they are properties of the plan |
| that a difference is not noise | three seeds; the seed spread is in the table | `seeds` |
| the model to hold for "a car walks until it runs out of road" | **model card**, *No routing* and *dead ends*: a car picks uniformly among legal exits, and a lane with no exit absorbs | argued below |

**Where it is honest, and where it is reduced.** Two things this lab cannot
hold:

1. **No destinations.** A car is not going anywhere, so "lifetime" is the
   life of a random walk, not of a journey. The question is asked in exactly
   those terms; "how long does a trip from A to B take on each shape" is
   **not answerable here**.
2. **Cars spawn anywhere there is room**, including on the stubs. A car born
   on a dead-end lane lives a fraction of a second, and it counts. The
   lifetime is therefore the mean over *every* car the plan ever held,
   which is the number a plan's leakiness actually produces, but it is
   lower than the life of a car that reached the interior — and it is why
   the one-line prediction below overshoots the shapes with the most
   spur-born cars.

**Why `last(lifetime)` and not `mean`.** The probe is a running mean over
every car that has left so far. Its last sample is the mean over the whole
run; averaging the running mean over time would weight the early, short
lives twice.

## Method

Each run: apply the preset, reset the clock, advance 20 simulated seconds
unrecorded so the fleet reaches its working size, then record 50 seconds at
1/60 s steps, sampled every 0.25 s — 200 samples per record.

Runs are driven by `tools/lab-sweep`, which stops the frame ticker and
advances the clock by hand — a frame is a wall-clock interval, so a lab left
to play itself is not reproducible. Steps in, sim seconds out, same bytes
every time.

```json
{
  "manifest": "clay-lab-study/1",
  "study": "shape-lifetime",
  "lab": "labs/street-network-101/Sandbox.qml",

  "objective": { "probe": "lifetime", "statistic": "last", "direction": "maximize" },

  "report": [
    { "probe": "cars", "statistic": "mean" },
    { "probe": "meanSpeed", "statistic": "mean" },
    { "probe": "lost", "statistic": "mean" },
    { "probe": "waiting", "statistic": "mean" }
  ],

  "record": { "probes": ["lifetime", "lost", "cars", "meanSpeed", "waiting",
                         "deadEndShare", "junctions", "turns", "pTerminal", "meanLane"] },

  "run": { "warmupSteps": 1200, "steps": 3000, "stepHz": 60, "budget": 12 },

  "fixed": { "demand": 0.4, "speed": 15 },

  "parameters": [
    {
      "name": "shape",
      "kind": "scenario",
      "levels": [
        { "id": "crossroads", "scenario": "crossroads" },
        { "id": "cul-de-sac", "scenario": "cul-de-sac" },
        { "id": "grid", "scenario": "grid" },
        { "id": "ring", "scenario": "ring" }
      ]
    }
  ],

  "seeds": [11, 23, 42],

  "tables": {
    "lifetime": {
      "rows": "shape",
      "columns": [
        { "head": "dead-end share of lane (%)", "expr": "mean(deadEndShare)", "digits": 1 },
        { "head": "junctions", "expr": "mean(junctions)", "digits": 0 },
        { "head": "turns", "expr": "mean(turns)", "digits": 0 },
        { "head": "cars", "expr": "mean(cars)", "digits": 1 },
        { "head": "speed (u/s)", "expr": "mean(meanSpeed)", "digits": 2 },
        { "head": "waiting (%)", "expr": "mean(waiting)", "digits": 1 },
        { "head": "lost (/min)", "expr": "mean(lost)", "digits": 1 },
        { "head": "mean lifetime (s)", "expr": "last(lifetime)", "digits": 1 },
        { "head": "seed spread (s)", "expr": "last(lifetime)", "over": "spread", "digits": 1 }
      ]
    },
    "walk": {
      "rows": "shape",
      "columns": [
        { "head": "p", "expr": "mean(pTerminal)", "digits": 3 },
        { "head": "1/p", "expr": "1 / mean(pTerminal)", "digits": 1 },
        { "head": "mean lane (u)", "expr": "mean(meanLane)", "digits": 1 },
        { "head": "speed (u/s)", "expr": "mean(meanSpeed)", "digits": 2 },
        { "head": "predicted (s) = lane / (p × speed)", "expr": "col('mean lane (u)') / (col('p') * col('speed (u/s)'))", "digits": 1 },
        { "head": "measured (s)", "expr": "last(lifetime)", "digits": 1 }
      ]
    }
  }
}
```

Twelve runs, and `run.budget` is 12: the cap is a hard one. Check it
against the lab before running it:

```
tools/lab-sweep/lab-sweep labs/street-network-101/studies/shape-lifetime --check
```

<!-- results:begin — everything below is the answer.
     For a student edition, cut from here down and withhold records/ and
     results.md; everything above states the question, the validity argument
     and the method, which is exactly the assignment. -->

## Results

Run with:

```
tools/lab-sweep/lab-sweep labs/street-network-101/studies/shape-lifetime
```

Full tables in `results.md`; the 12 records are in `records/`. Every table
below is rendered from them by `tools/lab-sweep/lab-table` and names the
records each row was read from; nothing here was typed.

### Lifetime by shape

<!-- table: lifetime -->
| shape | dead-end share of lane (%) | junctions | turns | cars | speed (u/s) | waiting (%) | lost (/min) | mean lifetime (s) | seed spread (s) | records |
|---|---|---|---|---|---|---|---|---|---|---|
| crossroads | 50.0 | 1 | 12 | 5.9 | 13.02 | 1.2 | 52.4 | 6.2 | 0.6 | `crossroads-11`, `crossroads-23`, `crossroads-42` |
| cul-de-sac | 28.0 | 4 | 28 | 8.9 | 13.33 | 0.9 | 74.1 | 6.3 | 0.3 | `cul-de-sac-11`, `cul-de-sac-23`, `cul-de-sac-42` |
| grid | 17.8 | 9 | 108 | 18.8 | 12.25 | 4.0 | 106.3 | 9.1 | 0.6 | `grid-11`, `grid-23`, `grid-42` |
| ring | 6.2 | 4 | 32 | 12.0 | 13.69 | 1.1 | 22.1 | 20.0 | 3.4 | `ring-11`, `ring-23`, `ring-42` |
<!-- /table -->

The predictor is `pTerminal` — the share of turns whose target lane is a
dead end. A car survives about `1/p` junctions, each costing about one mean
lane length at the speed it drives, so *lane / (p × speed)* is a
one-line prediction with nothing fitted in it. It lands within about a third
of the measurement on three of the four shapes and is exact on the grid;
it overshoots the ring by half, for the reason the answerability section
gives: the ring's cars are born on its spurs as often as anywhere else, and
a car born on a spur is absorbed before it ever reaches the loop. The
crossroads has *p = 1*: every exit leads to a stub, and no car ever comes
back.

## Conclusion

**Among these four shapes, the ring keeps a car alive 3.2× longer than the
crossroads at the same demand and the same speed**, and the reason is a
number the lane model produces before any car has moved: one turn in eight
on the ring ends in a stub, against every turn at the crossroads.

Read that with its limits attached. Cars here have no destination, so this
is the life of a random walk, and a shape that is good at keeping walkers
circulating is not thereby a good street network. Cars are born on the
stubs as well as on the loop, so the lifetime is a plan-wide mean and not
the life of a car that made it to the interior.

### Where to take it next

Give the four plans houses and ask the topology question the other study
asks; sweep `demand` on the ring to find where its long lives turn into a
queue; or ban the turns onto the spurs and watch *p* — and the lifetime —
change without a road being redrawn.

<!-- table: walk -->
| shape | p | 1/p | mean lane (u) | speed (u/s) | predicted (s) = lane / (p × speed) | measured (s) | records |
|---|---|---|---|---|---|---|---|
| crossroads | 1.000 | 1.0 | 71.5 | 13.02 | 5.5 | 6.2 | `crossroads-11`, `crossroads-23`, `crossroads-42` |
| cul-de-sac | 0.357 | 2.8 | 40.4 | 13.33 | 8.5 | 6.3 | `cul-de-sac-11`, `cul-de-sac-23`, `cul-de-sac-42` |
| grid | 0.333 | 3.0 | 37.2 | 12.25 | 9.1 | 9.1 | `grid-11`, `grid-23`, `grid-42` |
| ring | 0.125 | 8.0 | 53.6 | 13.69 | 31.3 | 20.0 | `ring-11`, `ring-23`, `ring-42` |
<!-- /table -->
