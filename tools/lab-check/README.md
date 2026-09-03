# lab-check — the lab contract as a failing test

A lab signs a contract: it loads clean, its runs are deterministic, its flows
pass, its records regenerate, and it says the same things in both languages.
Until this existed the contract was discipline and nothing else — nothing in
`ctest` so much as loaded a lab — and discipline decays quietly. A record whose
committed bytes no longer regenerate is still a file. A lab with no flow still
opens.

```
tools/lab-check/lab-check labs/electronics-101
tools/lab-check/lab-check labs/electronics-101 --only flows
tools/lab-check/lab-check labs/electronics-101 --only determinism --keep
```

One `lab_check_<lab>` CTest gate per lab is registered from `labs/CMakeLists.txt`,
discovered from the tree: a directory with a `Sandbox.qml` is a lab and gets a
gate at the next configure.

```
ctest --preset default -R lab_check                 # every lab
ctest --preset default -R lab_check_electronics     # one of them
```

## What one run checks

Each check prints a named `PASS`/`FAIL` line; any FAIL is a non-zero exit.

| Check | What it asserts |
|---|---|
| `load` | the lab reaches phase `ready`, a root exists, and it logged no QML warning or error of its own |
| `determinism` | for every name in `scenarios()`, two stepped runs of N steps produce byte-identical run records |
| `flows` | every id in `flows()` runs to `finished`, with no unresolved verb, no unsatisfied task and no failed `expect` |
| `strings` | EN and DE carry the same key set, and every `flow.<flowId>.<key>` a `FlowStep` needs exists in both |
| `records` | `records/make.sh` and every `studies/*/records/` regenerate to the committed bytes |
| `remarks` | open CriticMarkup marks in `paper.md` and `studies/*/study.md` — counted, reported, never failed |

Exit codes: `0` everything passed, `1` something failed, `77` (CTest's
`SKIP_RETURN_CODE`) the machine cannot run the check at all — `clayliveloader`
is not built.

## `lab-check.json`

Beside `Sandbox.qml`, written by `tools/lab-new` for every new lab. Absent is
not an error; the defaults below apply.

```json
{
    "purpose": "teaching",
    "steps": 600,
    "flows": ["led-basics", "logic-gates"],
    "scenarios": "all"
}
```

| Key | Meaning |
|---|---|
| `purpose` | `learning`, `teaching` or `research`. Documentation, not behaviour. |
| `steps` | Length of a stepped determinism run, in 1/60 s steps. Default 600 (ten simulated seconds). |
| `flows` | The flow ids to run, or `"all"`-by-omission (whatever `flows()` answers). An empty `flows()` is a FAIL unless this says `"none"` **and** `flowsReason` says why. |
| `flowsReason` | Required with `"flows": "none"`. A sentence, in the file, arguing that this lab does not want a flow — so "it has no flow" is a decision somebody made rather than something nobody got round to. |
| `scenarios` | `"all"` (default) or an explicit list, when a lab has scenarios the gate should not run. |
| `maxFlowSteps` | Upper bound on sim frames per flow. Default 20000 (≈ 5½ simulated minutes); hitting it is a FAIL, never a hang. |

## How it drives the lab, and why that way

Through **`clayliveloader` offscreen**, over the file-based inspector protocol
(`.clay/inspect/`) — the same route `tools/lab-new`'s boot tests take.

Issue #208 proposed `clayrender --paused` instead. `clayrender` needs a real
graphics session and refuses to run under `QT_QPA_PLATFORM=offscreen`, so a gate
built on it could never be green in CI, and a gate that only runs on one desk is
a footnote again. The loader runs offscreen, and its `eval` **returns values**,
which is the other half of what #208 wanted from #207. The `records` check is
the one part that still shells out to `clayrender`, because that is what a
record's own `command` field says regenerates it; with no display it reports
itself as not-run rather than inventing a verdict.

Three things the runs do that are easy to get wrong, and each cost a session:

- **The clock is paused before the root that will be measured exists.** The
  pause is a property of the loader, not of the scene, so it survives a reload:
  pause, then reload, and the new root's `SimClock` never ticks a wall-clock
  frame. That is what "no wall-clock frame ran before `applyScenario`" means,
  and it is exactly the drift #208 predicted — sensor-fusion-101's first GPS
  sample used to depend on how many frames happened to run during the load.
- **The outgoing root's clock is reset before the reload.** The loader captures
  `viewState()` from every root it discards and re-applies it to the next one,
  and a lab's view state carries its sim time — so `Lab.applyViewState()`
  re-steps the brand-new clock to where the finished run left it. Without the
  reset a "fresh" root arrives having already replayed the previous run.
- **Every stepped run gets its own loader process.** Two runs sharing a process
  share everything a QML engine does not throw away with the root. Under one
  process electronics-101's parts come back numbered `part12` in the first run
  and `part20` in the second: two records with identical numbers in them and
  different bytes, a determinism failure that says nothing about determinism.
  That is also why one gate takes minutes rather than seconds.

## What it needs from a lab

The conventions the skill already describes, plus one this makes load-bearing:
the sandbox root is `id: root`. The gate evaluates its drivers in the root's own
context and has to name it. Everything else it asks for is already the contract
— `scenarios()`, `applyScenario()`, `flows()`/`startFlow()`, `flowActions()`,
and probes registered with the kernel.

`.clay/` is created next to the sandbox while a gate runs and removed
afterwards; nothing else in the tree is written. Records regenerate into a
temporary directory (`records/make.sh --out-dir`, `lab-sweep --records-dir`) and
are compared from there.
