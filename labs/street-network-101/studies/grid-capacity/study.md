# The grid under rising demand — how much does it hold?

*A study against `labs/street-network-101`. Kit model card:
`labs/kits/traffic/README.md`. Companion paper: `../../paper.md`.*

## The question

The grid preset — nine crossings, no signals, no routing — is asked to hold
more and more cars. `demand` is what it is asked for; the fleet it actually
carries is whatever the spawn rule can fit into the gaps.

**How much traffic does the grid hold as demand rises, and where does it
stop taking more?**

The objective is **throughput** — cars times mean speed, in car·u/s, the
amount of driving the network is doing per second (maximize) — with the
cars **asked for** and the cars **held** quoted beside it, because the gap
between those two is the capacity making itself visible.

## Answerability

| the question needs | maps to | how it is checked |
|---|---|---|
| one plan, the same in every run | `setup` applies the `grid` preset | `lab-sweep --check` confirms the scenario exists |
| the demand as the thing varied | six `param` levels of `demand`, 0.5 to 3.0 | checked against `labInfo().params` |
| "the same driving" in every run | `speed` = 15, kit defaults otherwise | `fixed`, likewise |
| what the network was asked to hold | the `asked` probe: the kit's `targetCount` for this plan and demand | `labInfo().probes` |
| what it actually held | `mean(cars)` | read out of each record |
| how much driving it got done | the `throughput` probe: `cars × meanSpeed` | likewise |
| whether it is congested while it does it | `mean(waiting)`, `mean(meanSpeed)` | likewise |
| that a difference is not noise | three seeds; the seed spread is in the table | `seeds` |
| the model to hold for "a network fills up" | **model card**, *spawning*: a car appears only where there is a clear gap, nothing enters from off-stage | argued below |

**Where it is honest, and where it is reduced.** One thing this lab cannot
hold: a network that is *asked* for more traffic than it has gaps for does
not queue the excess at its edges — nothing enters from off-stage. So what
this study measures is a **saturation**, the point where the spawn rule
finds no room, and not the collapse of a fundamental diagram under an
inflow it cannot refuse. "What happens to a queue at the boundary" is **not
answerable here**.

## Method

Each run: apply the grid, set the demand, reset the clock, advance 20
simulated seconds unrecorded so the fleet reaches its working size, then
record 50 seconds at 1/60 s steps, sampled every 0.25 s — 200 samples per
record.

Runs are driven by `tools/lab-sweep`, which stops the frame ticker and
advances the clock by hand. Steps in, sim seconds out, same bytes every
time.

```json
{
  "manifest": "clay-lab-study/1",
  "study": "grid-capacity",
  "lab": "labs/street-network-101/Sandbox.qml",

  "objective": { "probe": "throughput", "statistic": "mean", "direction": "maximize" },

  "report": [
    { "probe": "asked", "statistic": "mean" },
    { "probe": "cars", "statistic": "mean" },
    { "probe": "meanSpeed", "statistic": "mean" },
    { "probe": "waiting", "statistic": "mean" }
  ],

  "record": { "probes": ["throughput", "asked", "cars", "meanSpeed", "waiting"] },

  "run": { "warmupSteps": 1200, "steps": 3000, "stepHz": 60, "budget": 18 },

  "fixed": { "speed": 15 },

  "setup": [ "applyScenario(\"grid\")" ],

  "parameters": [
    {
      "name": "demand",
      "kind": "param",
      "levels": [
        { "id": "0.5", "value": 0.5 },
        { "id": "1.0", "value": 1.0 },
        { "id": "1.5", "value": 1.5 },
        { "id": "2.0", "value": 2.0 },
        { "id": "2.5", "value": 2.5 },
        { "id": "3.0", "value": 3.0 }
      ]
    }
  ],

  "seeds": [11, 23, 42],

  "tables": {
    "capacity": {
      "rows": "demand",
      "columns": [
        { "head": "cars asked", "expr": "mean(asked)", "digits": 0 },
        { "head": "cars held", "expr": "mean(cars)", "digits": 1 },
        { "head": "speed (u/s)", "expr": "mean(meanSpeed)", "digits": 2 },
        { "head": "waiting (%)", "expr": "mean(waiting)", "digits": 1 },
        { "head": "throughput (car·u/s)", "expr": "mean(throughput)", "digits": 0 },
        { "head": "seed spread", "expr": "mean(throughput)", "over": "spread", "digits": 0 }
      ]
    }
  }
}
```

Eighteen runs, and `run.budget` is 18: the cap is a hard one. Check it
against the lab before running it:

```
tools/lab-sweep/lab-sweep labs/street-network-101/studies/grid-capacity --check
```

<!-- results:begin — everything below is the answer.
     For a student edition, cut from here down and withhold records/ and
     results.md; everything above states the question, the validity argument
     and the method, which is exactly the assignment. -->

## Results

Run with:

```
tools/lab-sweep/lab-sweep labs/street-network-101/studies/grid-capacity
```

Full tables in `results.md`; the 18 records are in `records/`. The table
below is rendered from them by `tools/lab-sweep/lab-table` and names the
records each row was read from; nothing here was typed.

<!-- table: capacity -->
| demand | cars asked | cars held | speed (u/s) | waiting (%) | throughput (car·u/s) | seed spread | records |
|---|---|---|---|---|---|---|---|
| 0.5 | 24 | 23.7 | 11.44 | 5.7 | 272 | 15 | `0.5-11`, `0.5-23`, `0.5-42` |
| 1.0 | 47 | 46.3 | 8.15 | 17.7 | 378 | 31 | `1.0-11`, `1.0-23`, `1.0-42` |
| 1.5 | 71 | 68.0 | 6.17 | 26.4 | 418 | 50 | `1.5-11`, `1.5-23`, `1.5-42` |
| 2.0 | 94 | 76.0 | 5.67 | 28.7 | 425 | 37 | `2.0-11`, `2.0-23`, `2.0-42` |
| 2.5 | 118 | 76.0 | 5.67 | 28.7 | 425 | 37 | `2.5-11`, `2.5-23`, `2.5-42` |
| 3.0 | 140 | 76.0 | 5.67 | 28.7 | 425 | 37 | `3.0-11`, `3.0-23`, `3.0-42` |
<!-- /table -->

**Up to demand 1.5 the grid holds what it is asked to**, within a few cars:
24 of 24, 46 of 47, 68 of 71. **From 2.0 on it is saturated at 76 cars** and
refuses more — 94, 118 and 140 asked for, 76 held, every time. The three
saturated rows are identical to every digit the records carry, across all
three seeds: once the network is full the spawn rule finds the same gaps
whatever the demand says, and the run no longer depends on the number that
was asked for.

Throughput climbs from 272 to 418 car·u/s over the first three levels and
then flattens at 425, while mean speed halves (11.4 to 5.7 u/s) and the
waiting share quintuples (5.7 % to 28.7 %). The network does more driving in
total by doing it more slowly, up to the point where it cannot fit another
car — and then it does exactly the same amount however hard it is asked.

## Conclusion

**The grid's capacity is about 76 cars at this speed and this spawn rule;
above demand 1.5 asking for more traffic changes nothing.** The gap between
*asked* and *held* is where that capacity shows, and the lab prints the
same two numbers in its stats panel while you turn the demand up.

Read that with its limits attached. It is a saturation, not a collapse: a
model that never forces a car into a gap that is not there cannot show
throughput falling over, and a real network with an inflow it cannot refuse
would. An earlier version of the lab's paper reported a dramatic collapse
above demand 0.85; that was a junction deadlock, not traffic physics, and
this study is the record of what the fixed model does instead.

### Where to take it next

Sweep `speed` at fixed demand to see whether capacity is a count of cars or
a count of car-lengths per second; give the grid houses and ask the same
question with a pinned fleet; or ban left turns at every interior crossing
and see whether the plateau moves — the paper's restriction table says it
should, and that table is the next one owed to a study.
