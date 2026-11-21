# Does one lever light the whole board?

*A study against `labs/{{slug}}`. Companion paper: `../../paper.md`. Started
{{date}}.*

> Skeleton, not content. It is here so the lab is a research lab from its
> first commit: a question, an answerability table, a manifest, committed
> records and one table rendered from them. Replace the question with yours,
> widen the manifest, re-run the sweep, and delete this quote block.

## The question

The `intro` scenario wires a block, a lever and a second block in a row.
**With the lever off and with it on, how many of the three parts are lit?**

## Answerability

| the question needs | maps to | how it is checked |
|---|---|---|
| how many parts are lit | `mean(lit)` of the `lit` probe | `lab-sweep --check` confirms the probe exists |
| that the board is the same in both runs | `mean(wires)` of the `wires` probe | likewise |
| the lever as the thing varied | two `eval` levels: as built, and with the lever flipped | each level's script is in the manifest |
| that a difference is not noise | nothing to average: the board draws no random numbers | one seed; a second would repeat each record byte for byte |

**Where it is reduced.** The stub model lights whatever is wired to a lever
that is on; it has no time, so every sample of a run reads the same.

## Method

Each run: apply `intro`, set the lever, record 600 steps at 1/60 s, sampled
every 0.1 s.

```json
{
  "manifest": "clay-lab-study/1",
  "study": "first-look",
  "lab": "labs/{{slug}}/Sandbox.qml",

  "objective": { "probe": "lit", "statistic": "mean", "direction": "maximize" },

  "report": [
    { "probe": "wires", "statistic": "mean" }
  ],

  "record": { "probes": ["lit", "wires"] },

  "run": { "warmupSteps": 0, "steps": 600, "stepHz": 60, "budget": 2 },

  "parameters": [
    {
      "name": "lever",
      "kind": "eval",
      "levels": [
        { "id": "off", "eval": "applyScenario(\"intro\")" },
        {
          "id": "on",
          "eval": [
            "applyScenario(\"intro\")",
            "flip(board.parts.find(p => p.type === \"lever\").id)"
          ]
        }
      ]
    }
  ],

  "seeds": [42],

  "tables": {
    "lever": {
      "rows": "lever",
      "columns": [
        { "head": "parts lit", "expr": "mean(lit)", "digits": 0 },
        { "head": "wires", "expr": "mean(wires)", "digits": 0 }
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

<!-- table: lever -->
| lever | parts lit | wires | records |
|---|---|---|---|
| off | 0 | 2 | `off-42` |
| on | 3 | 2 | `on-42` |
<!-- /table -->
