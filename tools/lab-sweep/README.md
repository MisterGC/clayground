# lab-sweep — run a study's matrix, tabulate what came back

A **study** is a question posed against a lab: an objective, what is held
fixed, what is varied, how many seeds, and a hard cap on runs. It lives in
`labs/<lab>/studies/<slug>/study.md`, prose first, with one machine-readable
JSON block inside it. `lab-sweep` is what turns that block into records.

```
tools/lab-sweep/lab-sweep <study-dir>                  # run it
tools/lab-sweep/lab-sweep <study-dir> --check          # answerability, no runs
tools/lab-sweep/lab-sweep <study-dir> --dry-run        # print the matrix
tools/lab-sweep/lab-sweep <study-dir> --only topology=ring --seed 42
tools/lab-sweep/lab-sweep <study-dir> --records-dir DIR # regenerate elsewhere
```

Worked example: `labs/street-network-101/studies/topology-four-houses/`.

## What it does, and what it refuses to do

It drives `clayrender` once per cell, writes one `.labrec` per run into the
study's `records/`, then reads those records back to build `results.md`.

It contains **no optimization and no search**. It does not pick the next
experiment, stop early on a promising cell, or fit anything. That is not a
missing feature: a runner that chose its own next experiment would be making
the scientific decisions, and those belong to whoever asked the question.

Three properties it does owe:

- **Deterministic** — every run stops the frame ticker and advances the clock
  by hand, so sim time is a function of the step count and not of the machine.
  Two sweeps of one manifest produce byte-identical records.
- **Parallel-safe** — runs share nothing: isolated preferences, own temp
  files, own record path. `--jobs` has no effect on results.
- **Budgeted** — `run.budget` is a hard cap on matrix size, checked before
  anything launches. Widening a sweep has to be a deliberate edit.

`--records-dir` writes the records somewhere other than the study's `records/`
and, like a filtered run, leaves `results.md` alone. It is how
`tools/lab-check/lab-check` regenerates a study's records and compares them
against the committed ones without ever writing into the tree it is checking.

A **filtered** run (`--only` / `--seed`) rewrites its records and leaves
`results.md` alone. A table built from three of sixteen runs, looking exactly
like the full one, is the worst artifact this tool could produce — so
re-running one cell to check determinism cannot truncate the table the
conclusion was read from.

## `--check`: the mechanical half of answerability

Loads the lab, reads its `labInfo()`, and confirms that every probe and
parameter the study names actually exists — with the lab's real list in the
error when one does not:

```
answerability check FAILED:
  - probe 'throughput' does not exist in this lab. It has: arrivals, cars, meanSpeed, waiting
  - fixed parameter 'demnad' does not exist in this lab. It has: demand, simSpeed, speed
```

It deliberately stops there. Whether the *model* holds for the question is
not mechanical — only the kit's model card can answer that, and the study's
answerability table is where a human argues it. `--check` says so on success
too, so passing it is never mistaken for the question being answerable.

## The manifest

Fenced JSON inside `study.md`, declaring `"manifest": "clay-lab-study/1"` so
the parser can find it among other JSON in the document. Why JSON in the
markdown rather than YAML beside it: this runner is stdlib-only, the standard
library parses JSON and not YAML, and a hand-rolled YAML subset is a parser
with its own bugs sitting between a claim and its evidence. Keeping it inside
the study means reviewing the study *is* reviewing what was run. Multi-line
JS is written as arrays of lines, which diff one statement at a time. The
full reasoning is at the top of `manifest.py`.

| key | meaning |
|---|---|
| `lab` | sandbox path, or a lab id under `labs/` |
| `objective` | `{probe, statistic, direction}`, optional `normalize` |
| `report` | extra `{probe, statistic}` columns for the results table |
| `record.probes` | what each record keeps (the objective and reported probes are added automatically) |
| `run` | `{warmupSteps, steps, stepHz, budget}` |
| `fixed` | parameter values held constant |
| `setup` | JS run before every cell |
| `parameters` | what is varied: `kind` is `eval`, `scenario` or `param`, each with `levels` |
| `seeds` | one run per level combination per seed |

`normalize` divides the objective statistic by another statistic of the same
probe. It exists because of a real mistake: ranking four networks by the raw
standard deviation of an arrival rate, when the rates themselves differed
fourfold, ranked them mostly by their means. `"normalize": "mean"` makes it a
coefficient of variation, which is comparable across cells; the study that
found this documents it.

## Tests

```
python3 tools/lab-sweep/tests/run_sweep_tests.py
```

Registered with CTest as `lab_sweep`. Pure — manifest parsing, matrix
expansion, the answerability check and record reading — so it needs no
graphics session and never skips. The subprocess half is exercised by the
committed study records, which are regenerated by re-running the sweep.
