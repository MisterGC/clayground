# lab-check — the lab contract as a failing test

A lab signs a contract: it loads clean, its runs are deterministic, its flows
pass, its records regenerate, its tables are rendered from those records, and
it says the same things in both languages. What the contract *demands* depends
on what the lab is for — its `purpose` — and what a lab *has* is checked
whatever the purpose.
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
| `load` | the lab reaches phase `ready`, a root exists, and nothing but [the environment](#what-counts-as-the-environment) logged a warning or error — the lab, its kits and the kernel alike |
| `determinism` | for every name in `scenarios()`, two stepped runs of N steps produce byte-identical run records |
| `flows` | every id in `flows()` runs to `finished` through `Lab.runFlow()`, with no unresolved verb, no unsatisfied task and no failed `expect` |
| `strings` | EN and DE carry the same key set, and every `flow.<flowId>.<key>` a `FlowStep` needs exists in both |
| `records` | `records/make.sh` and every `studies/*/records/` regenerate to the committed bytes |
| `tables` | every `<!-- table: … -->` block in `paper.md` and `studies/*/study.md` renders to the committed bytes (`tools/lab-sweep/lab-table --check`); pure, never NOT RUN |
| `study` | a research lab has at least one `studies/<slug>/study.md` whose manifest parses, with committed `records/` and an `## Answerability` section |
| `triad` | `paper.md` exists; `overview.grafli` exists where the purpose owes a board |
| `remarks` | open CriticMarkup marks in `paper.md` and `studies/*/study.md` — counted, reported, never failed |

Exit codes: `0` everything passed, `1` something failed, `77` (CTest's
`SKIP_RETURN_CODE`) the machine cannot run the check at all — `clayliveloader`
is not built.

## What counts as the environment

A headless run logs a few warnings whatever the lab is. These, and only these,
do not fail `load`; they are matched by name in `ENVIRONMENT` in
`lab_check.py` and printed as a count under the `load` line:

| Name | The message, as it starts | Why it is the machine's |
|---|---|---|
| `qtquick3d-no-rhi` | `The Qt Quick scene is using a rendering method that is not based on QRhi and a 3D graphics API.` | offscreen has no RHI, so Qt Quick 3D refuses every `View3D` |
| `qtquick3d-no-rhi-assert` | `Unexpected condition met: "QSGRendererInterface::isApiRhiBased(` | the same refusal, as the soft assert Qt Quick 3D logs after it |
| `offscreen-default-font` | `Populating font family aliases took <n> ms. Replace uses of missing font family "Sans Serif"` | under `QT_QPA_PLATFORM=offscreen` on macOS Qt asks for a default family the system does not have, once |
| `linux-multimedia-libraries` | `Couldn't load <library> library` or `Couldn't resolve <library> symbols`, in the category `qt.multimedia.symbolsresolver` only | on Linux Qt Multimedia loads optional system libraries (PipeWire, VA-API) at run time and logs each one the machine lacks; the CI runner lacks them all |
| `linux-no-pulseaudio` | `PulseAudioService: pa_context_connect() failed` | the same Qt Multimedia on a Linux machine with no PulseAudio server, such as the CI runner |
| `offscreen-no-font-directory` | `QFontDatabase: Cannot find font directory <dir>` | offscreen on Windows reads fonts from the Qt installation's `lib/fonts`, which a Qt install does not ship, so the machine has no fonts at all |

Every other warning or error fails `load`, wherever it comes from: a file of
the lab, a kit under `labs/kits/`, the kernel in `plugins/clay_lab/` (shown as
its source file, not its `qrc:` URL), any other plugin — and a message that
names no file at all, such as a `console.warn`. Each is printed with the file
and line it names, or `(names no file)`. A lab that came up and logged one
still gets every other check, so one run says everything that is wrong.

Until #534 a message counted as the lab's only when it named a file inside the
lab's own folder, and a kit that threw a `TypeError` at load passed. A message
belongs on this list only when it comes from the machine whatever the lab is;
the list and this table change together.

## `lab-check.json`

Beside `Sandbox.qml`, written by `tools/lab-new` for every new lab. `purpose`
is required (#209): it decides which checks are demands, so a lab without one
cannot be judged. Everything else has a default.

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
| `purpose` | `learning`, `teaching` or `research`. **Required.** What the lab is for, and therefore what the gate demands — the table below. |
| `steps` | Length of a stepped determinism run, in 1/60 s steps. Default 600 (ten simulated seconds). |
| `flows` | The flow ids to run: an explicit list, `"all"` (the default — whatever `flows()` answers), or `"none"`. Whether *none* is allowed is the purpose's call, not this file's. |
| `scenarios` | `"all"` (default) or an explicit list, when a lab has scenarios the gate should not run. |
| `maxFlowSteps` | Upper bound on sim frames per flow. Default 20000 (≈ 5½ simulated minutes); hitting it is a FAIL, never a hang. |

`flowsReason` (#208) is no longer read: the purpose is the reason.

### What the purpose decides

A lab is checked for what it *has* whatever its purpose — a research lab that
ships a flow has it run, one that ships German has the parity checked — and
for what its purpose *owes* on top:

| check | every purpose | teaching | research | learning |
|---|---|---|---|---|
| `load`, `determinism`, `records`, `tables`, `remarks` | as above | — | — | — |
| `flows` | every published flow finishes with its expects holding | at least one flow, and each declared flow carries at least one `expect` | — | — |
| `strings` | EN registered; if DE is registered, the key sets match and every flow key exists in both | DE registered | — | — |
| `study` | — | — | a study with a parsing manifest, committed records and an answerability section | — |
| `triad` | `paper.md` exists | `overview.grafli` exists | — | `overview.grafli` exists |

The tiers themselves — what a research paper, a lesson plan and a study path
look like — are in `skills/clay-lab/references/triad.md`; this tool checks
what is mechanical about them and nothing more.

## How it drives the lab, and why that way

Through **`clayliveloader` offscreen**, over the file-based inspector protocol
(`.clay/inspect/`) — the same route `tools/lab-new`'s boot tests take.

Issue #208 proposed `clayrender --paused --result -` instead. That command
exists (#207) and is the right one for asking one lab one question by hand:

```bash
./build/bin/clayrender labs/<lab>/Sandbox.qml --out /tmp/x.png \
    --paused --result - --eval 'Lab.runFlow("<flowId>")'
```

It is the wrong one for a gate. `clayrender` needs a real graphics session and
refuses to run under `QT_QPA_PLATFORM=offscreen`, so every `lab_check_<lab>`
would skip on a headless runner, and a gate that only runs on one desk is the
footnote this tool exists to remove. The loader runs offscreen and its `eval`
returns values, so the same questions get the same answers. The `records` check
is the one part that still shells out to `clayrender`, because that is what a
record's own `command` field says regenerates it; with no display it reports
itself as not-run rather than inventing a verdict.

**The flow check is `Lab.runFlow()`, not a second implementation of it.** The
kernel decides what "this task was solved" and "this expect held" mean — a flow
run by hand through `clayrender` and a flow run by the gate have to agree, or
one of them is lying. What the gate adds is running *every* flow of a lab, each
in a lab nobody has touched, and turning the answer into a line.

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
are compared from there; tables render in memory (`lab-table --check`) and are
compared against the committed prose.
