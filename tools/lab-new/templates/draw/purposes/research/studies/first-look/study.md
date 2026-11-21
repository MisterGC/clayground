# Does the pen stay on the drawing?

*A study against `labs/{{slug}}`. Companion paper: `../../paper.md`. Started
{{date}}.*

> Skeleton, not content. It is here so the lab is a research lab from its
> first commit: a question, an answerability table, a manifest, one committed
> record and one table rendered from it. Replace the question with yours,
> widen the manifest, re-run the sweep, and delete this quote block.

## The question

The `intro` scenario puts one 8 m line on the sheet, and the pen walks the
drawing at 3 m/s. **Over ten simulated seconds, does the distance the pen
has walked along the drawing ever exceed the drawing's length?**

## Answerability

| the question needs | maps to | how it is checked |
|---|---|---|
| the drawing's length | `mean(length)` of the `length` probe | `lab-sweep --check` confirms the probe exists |
| how far along it the pen is | `max(walked)` and `last(walked)` of the `walked` probe | likewise |
| one fixed drawing | the `intro` scenario | the manifest names it |
| that a difference is not noise | nothing to average: the pen draws no random numbers | one seed; a second would repeat the record byte for byte |

**Where it is reduced.** Nothing is drawn by hand during the run: the
question is about the pen on a fixed drawing, not about drawing.

## Method

One run: apply `intro`, record 600 steps at 1/60 s, sampled every 0.1 s.

```json
{
  "manifest": "clay-lab-study/1",
  "study": "first-look",
  "lab": "labs/{{slug}}/Sandbox.qml",

  "objective": { "probe": "walked", "statistic": "max", "direction": "minimize" },

  "report": [
    { "probe": "length", "statistic": "mean" }
  ],

  "record": { "probes": ["walked", "length", "segments"] },

  "run": { "warmupSteps": 0, "steps": 600, "stepHz": 60, "budget": 1 },

  "parameters": [
    { "name": "scenario", "kind": "scenario", "levels": [ { "id": "intro", "scenario": "intro" } ] }
  ],

  "seeds": [42],

  "tables": {
    "pen": {
      "rows": "cells",
      "columns": [
        { "head": "length (m)", "expr": "mean(length)", "digits": 2 },
        { "head": "max walked (m)", "expr": "max(walked)", "digits": 2 },
        { "head": "walked at 10 s (m)", "expr": "last(walked)", "digits": 2 }
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

<!-- table: pen -->
| configuration | length (m) | max walked (m) | walked at 10 s (m) | records |
|---|---|---|---|---|
| intro | 8.00 | 7.95 | 5.95 | `intro-42` |
<!-- /table -->
