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
tools/lab-check/lab-check labs/electronics-101 --ready-timeout 30 --verbose
tools/lab-check/lab-check labs/electronics-101 --jobs 8
tools/lab-check/lab-check labs/electronics-101 --clayrender build-debug/bin/clayrender --strict
tools/lab-check/lab-check labs/electronics-101 --json > result.json
tools/lab-check/lab-check ~/elsewhere/heat-101      # a lab in no checkout
```

With no `--loader` and no `--clayrender` it takes the build of the checkout
the lab sits in, `build/bin/` under the root it finds by walking up to
`.git`. A lab in no checkout - copied to a folder of its own, or made with
`tools/lab-new/lab-new <slug> --dir <elsewhere>` - or a lab whose checkout
has no build takes the build beside the tool instead: `build/bin/` of the
checkout `tools/lab-check/` is in. Until #573 such a lab skipped with
"clayliveloader does not exist". `lab-sweep` finds its `clayrender` the same
way.

One `lab_check_<lab>` CTest gate per lab is registered from `labs/CMakeLists.txt`,
discovered from the tree: a directory with a `Sandbox.qml` is a lab and gets a
gate at the next configure.

```
ctest --preset default -R lab_check                 # every lab
ctest --preset default -R lab_check_electronics     # one of them
```

## What one run checks

Each check prints a named `PASS`/`FAIL` line; any FAIL is a non-zero exit. A
check this machine cannot run prints `NOT RUN` instead — today only `records`,
when there is no `clayrender` or it finds no graphics session. It is never
counted as a pass: the summary reads `17/17 checks passed, 2 not run`, and with
`--strict` a NOT RUN exits `1` too (#535).

| Check | What it asserts |
|---|---|
| `load` | the lab reaches phase `ready`, a root exists, and nothing but [the environment](#what-counts-as-the-environment) logged a warning or error — the lab, its kits and the kernel alike |
| `determinism` | for every name in `scenarios()`, two stepped runs of N steps produce byte-identical run records |
| `flows` | every id in `flows()` runs to `finished` through `Lab.runFlow()`, with no unresolved verb, no unsatisfied task and no failed `expect` - once in every language the lab registers, one line each: `flows: <id> [en]`, `flows: <id> [de]` |
| `strings` | EN and DE carry the same key set, and every `flow.<flowId>.<key>` a `FlowStep` needs exists in both |
| `teaching` | for a teaching lab, the lesson rules a program can test (#542): every flow has a step the learner acts on (a `task`, which a question the lab takes an answer to and a `"wiring": true` task are) and an `expect`; every line a flow can say — its steps' keys, answered variants and scripts, the hints its tasks name, its title — is at most 240 characters in every language, a script's `*cues*` not counted; and no step's narration is a `say` literal in the QML |
| `records` | `records/make.sh` and every `studies/*/records/` regenerate to the committed bytes, with the `clayrender` given as `--clayrender` (default: the build's, found as above); `records/session.labrec`, the scratch run `Shift+R` writes, is not compared |
| `tables` | every `<!-- table: … -->` block in `paper.md` and `studies/*/study.md` renders to the committed bytes (`tools/lab-sweep/lab-table --check`); pure, never NOT RUN |
| `study` | a research lab has at least one `studies/<slug>/study.md` whose manifest parses, with committed `records/` and an `## Answerability` section |
| `triad` | `paper.md` exists; `overview.grafli` exists where the purpose owes a board |
| `remarks` | open CriticMarkup marks in `paper.md` and `studies/*/study.md` — counted, reported, never failed |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | every check passed; without `--strict`, a check may also have been NOT RUN |
| `1` | a check failed - `lab-check.json` that does not parse or names no `purpose` included - or, with `--strict`, a check was NOT RUN |
| `2` | the command line is wrong and nothing was checked: the directory has no `Sandbox.qml`, `--only` names a check that does not exist, or an option is unknown or misspelt |
| `77` | the machine cannot run the check at all: no `clayliveloader` where it looked (CTest's `SKIP_RETURN_CODE`) |

`--json` changes none of them.

### Every lesson in every language

A flow runs once per language the lab registers with `LabLang`, English
first. A step waits for as long as its line takes to read (`dwellOf` in
`Flow.qml`), so a lesson takes a different number of frames in each
language - sensor-fusion-101's `fusion-basics` runs 5358 frames in English
and 4494 in German - and a flow can
finish in one and run out of `maxFlowSteps`, or reach a task at another
moment, in the other (#573). The run sets `LabLang.lang` before
`Lab.runFlow()`. Every loader the check starts gets a settings store of its
own (`CLAY_STORAGE_DIR` under the check's temporary directory), because
LabPrefs keeps the language: a run in German would otherwise leave the
reader's own dojo, and every run after it, in German.

## Reading the result from a program

`--json` prints one JSON document on stdout, and the lines a person reads
on stderr, for every exit code - `2` and `77` too, with nothing checked:

```json
{
  "lab": "electronics-101",
  "path": "/home/me/clayground/labs/electronics-101",
  "purpose": "teaching",
  "exit": 1,
  "error": null,
  "seconds": 41.207,
  "passed": 37,
  "failed": 1,
  "notRun": 0,
  "checks": [
    {"name": "load: the lab reaches phase ready", "check": "load",
     "status": "pass", "passed": true, "detail": "phase=ready",
     "seconds": 1.302},
    {"name": "flows: led-basics [de]", "check": "flows",
     "status": "fail", "passed": false,
     "detail": "expect failed: measure-led", "seconds": 12.48}
  ],
  "notes": ["records: first difference in ..."]
}
```

| Key | Meaning |
|---|---|
| `lab`, `path` | the lab's directory name and its absolute path; `null` when the command line did not get that far |
| `purpose` | what `lab-check.json` declares, `null` before it is read or when it is wrong |
| `exit` | the process's exit code, as in the table above |
| `error` | why nothing was checked, for exit `2` and `77`; `null` otherwise |
| `seconds` | the whole check, wall-clock |
| `passed`, `failed`, `notRun` | how many entries of `checks` have each status; they add up to its length |
| `checks` | one entry per `PASS`, `FAIL` and `NOT RUN` line, in the order printed |
| `checks[].name` | the line's name, as printed - `flows: led-basics [de]` |
| `checks[].check` | the check it belongs to, the part of `name` before the first `:` - one of the checks above, or `config`, `contract`, `protocol` |
| `checks[].status` | `"pass"`, `"fail"` or `"not run"` |
| `checks[].passed` | `true`, `false`, or `null` for a check that did not run |
| `checks[].detail` | the text in brackets after the line's name, `""` when there is none; for `not run` the reason |
| `checks[].seconds` | how long the work behind the line took. A determinism line is its two runs together, a flow line its run, a records line its regenerating runs together - each a process of its own, from its start, so with `--jobs` above 1 these add up to more than `seconds`. Every other line is timed from the start of its check in lab-check itself; the `load` lines include the loader's start |
| `notes` | the indented lines that are not checks - environment messages, the first differing line of a record, open remarks - in the order printed |

### When the loader dies or the lab never gets ready

Every wait on the loader also looks at its process (#536). A loader that
ends — a crash, a plugin it cannot load — fails the run it was serving within
a fraction of a second: the FAIL line says `the loader ended with exit code
<n>` (or `was killed by signal <n> (<name>)`) and what it was waiting for, and
the loader's last lines of output follow it. Without `--verbose` that output
is not shown, but it is still read, so the last lines are there when it dies.

A loader that stays up and never gets the lab to phase `ready` fails after
`--ready-timeout` seconds, 90 by default, which the first line of every run
states (`ready within 90 s`). The first loader that times out fails its
check; every loader run after it is NOT RUN, rather than each waiting out the
same timeout again. A loader that is up and stops answering a request fails
one `protocol:` line, and the scene checks after it do not run.

None of this stops the checks that need no loader: `records`, `tables`,
`study`, `triad` and `remarks` report whatever happened to the scene.

The `lab_check_<lab>` gates run without `--strict`, because CI's Linux runners
render offscreen, where `clayrender` does not start: there the records check is
NOT RUN, and only the Windows runners regenerate records. The CI log says per
runner which records were regenerated (the step after `Test`).

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
| `inspector-replace-retry` | `ClayInspector: replacing "<…>/.clay/inspect/<…>" took <n> attempts` | on Windows a file cannot be renamed over while it is open, and lab-check's own reads of `state.json` and `response.json` sometimes are; the inspector's retry succeeded. One that never succeeds logs `failed to write` and still fails `load` (#572) |

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
| `flows` | every published flow finishes with its expects holding | at least one flow | — | — |
| `strings` | EN registered; if DE is registered, the key sets match and every flow key exists in both | DE registered | — | — |
| `teaching` | — | each flow has a task and an `expect`; no narration line over 240 characters; no `say` literal | — | — |
| `study` | — | — | a study with a parsing manifest, committed records and an answerability section | — |
| `triad` | `paper.md` exists | `overview.grafli` exists | — | `overview.grafli` exists |

The tiers themselves — what a research paper, a lesson plan and a study path
look like — are in `skills/clay-lab/references/triad.md`; this tool checks
what is mechanical about them and nothing more. Which of the skill's rules it
checks, and which are judgement, is marked beside each rule in the skill's
references (`teaching.md`, `flows.md`, `triad.md`).

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
itself as NOT RUN rather than inventing a verdict.

**The flow check is `Lab.runFlow()`, not a second implementation of it.** The
kernel decides what "this task was solved" and "this expect held" mean — a flow
run by hand through `clayrender` and a flow run by the gate have to agree, or
one of them is lying. What the gate adds is running *every* flow of a lab, each
in a lab nobody has touched, and turning the answer into a line.

Two things the runs do that are easy to get wrong, and each cost a session:

- **The clock is paused before the root that will be measured exists.** Every
  stepped run starts its loader with `--paused`, so the root is created with
  `Clayground.paused` already set and its `SimClock` never ticks a wall-clock
  frame. That is what "no wall-clock frame ran before `applyScenario`" means,
  and it is exactly the drift #208 predicted — sensor-fusion-101's first GPS
  sample used to depend on how many frames happened to run during the load.
  Until #572 the run paused by request, reset the clock and reloaded to reach
  such a root; the root of a loader started paused is that root from birth,
  and has no outgoing root whose `viewState()` it could inherit.
- **Every stepped run gets its own loader process.** Two runs sharing a process
  share everything a QML engine does not throw away with the root. Under one
  process electronics-101's parts come back numbered `part12` in the first run
  and `part20` in the second: two records with identical numbers in them and
  different bytes, a determinism failure that says nothing about determinism.
  The processes are independent, so they run side by side: `--jobs` of them
  at a time (4 by default, as `lab-sweep`'s), each under `--instance` so it
  serves its protocol in a directory of its own, and with an empty settings
  store of its own (`CLAY_STORAGE_DIR`), since two loaders opening one
  LocalStorage database at once race on its version. The flows, the determinism
  pairs and the records regeneration share that one limit; `records/make.sh`
  runs once per committed record when each record's `command` names its
  scenario, and `lab-sweep` gets `--jobs` for a study. The output keeps its
  order whichever run ends first, so a check takes about as long as its
  longest run (#572).

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

Both regenerators run with the `clayrender` lab-check was given — `make.sh`
reads it from `$CLAYRENDER`, `lab-sweep` from `--clayrender` — and both find the
lab from their own path, not as `labs/<slug>` under a checkout. So a lab made
with `tools/lab-new/lab-new <slug> --dir <elsewhere>` regenerates its records
there, and its records keep the `labs/<slug>/…` spelling in their `command`
field wherever the lab sits (#535).

## Pages that are not labs

`load_check.py <Sandbox.qml>` is the load stage alone, for a page with no
paper, flows or records to judge: the kernel's demo page
(`ctest -R lab_kernel_demo_load`) and the professor kit's sandbox
(`ctest -R kit_professor_load`). It fails on any warning raised from QML or JS
— the kernel's files count as much as the page's — and ignores what the
offscreen environment logs about itself (Qt Quick 3D without an RHI, the font
alias cache). Exit 0 clean, 1 a warning, no load or a loader that died (with
its exit code and last output), 77 no loader built.
