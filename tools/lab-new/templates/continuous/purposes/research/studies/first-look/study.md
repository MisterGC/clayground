# How much of the nudge is left after ten seconds?

*A study against `labs/{{slug}}`. Companion paper: `../../paper.md`. Started
{{date}}.*

> Skeleton, not content. It is here so the lab is a research lab from its
> first commit: a question, an answerability table, a manifest, one committed
> record and one table rendered from it. Replace the question with yours,
> widen the manifest, re-run the sweep, and delete this quote block.

## The question

The `intro` scenario starts the mass 1.6 m from rest on a spring of
stiffness 6 N/m with a damping of 0.35 N·s/m, and nothing drives it. **What
share of its starting energy does it still hold after ten simulated
seconds?**

## Answerability

| the question needs | maps to | how it is checked |
|---|---|---|
| the starting energy | `first(energy)` of the `energy` probe | `lab-sweep --check` confirms the probe exists |
| the energy after ten seconds | `last(energy)`, 600 steps at 1/60 s | likewise |
| one fixed starting state | the `intro` scenario | the manifest names it |
| that a difference is not noise | nothing to average: the spring draws no random numbers | one seed; a second would repeat the record byte for byte |

**Where it is reduced.** The model is a linear spring with linear damping,
integrated in fixed steps; the answer is the model's, not a real spring's.

## Method

One run: apply `intro`, record 600 steps at 1/60 s, sampled every 0.05 s.

```json
{
  "manifest": "clay-lab-study/1",
  "study": "first-look",
  "lab": "labs/{{slug}}/Sandbox.qml",

  "objective": { "probe": "energy", "statistic": "last", "direction": "maximize" },

  "report": [
    { "probe": "energy", "statistic": "first" }
  ],

  "record": { "probes": ["energy", "position", "velocity"] },

  "run": { "warmupSteps": 0, "steps": 600, "stepHz": 60, "budget": 1 },

  "parameters": [
    { "name": "scenario", "kind": "scenario", "levels": [ { "id": "intro", "scenario": "intro" } ] }
  ],

  "seeds": [42],

  "tables": {
    "energy": {
      "rows": "cells",
      "columns": [
        { "head": "E at 0 s (J)", "expr": "first(energy)", "digits": 3 },
        { "head": "E at 10 s (J)", "expr": "last(energy)", "digits": 3 },
        { "head": "% left", "expr": "100 * last(energy) / first(energy)", "digits": 1 }
      ]
    }
  }
}
```

```sh
tools/lab-sweep/lab-sweep labs/{{slug}}/studies/first-look --check
tools/lab-sweep/lab-sweep labs/{{slug}}/studies/first-look
```

## Results

Rendered from `records/` by `tools/lab-sweep/lab-table` between the markers;
`tools/lab-check/lab-check` goes red when it no longer matches the records.

<!-- table: energy -->
| configuration | E at 0 s (J) | E at 10 s (J) | % left | records |
|---|---|---|---|---|
| intro | 7.680 | 0.220 | 2.9 | `intro-42` |
<!-- /table -->
