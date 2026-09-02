# lab-new — start a lab from a template that already loads

```sh
tools/lab-new/lab-new heat-101
tools/lab-new/lab-new heat-101 --kind draw --purpose research
tools/lab-new/lab-new heat-101 --dry-run
```

Creates `labs/<slug>/` with everything the definition of done asks for: a
`Sandbox.qml` that boots in the dojo and answers the whole conventions
contract, a bilingual `strings.js` covering every key it shows, a `qmldir`,
a records driver, a figures driver, a `lab-check.json`, and the `paper.md` +
`overview.grafli` skeletons for the purpose you picked.

The point is not that typing is saved. It is that the *starting* state of a
new lab is already a lab: it has scenarios, a flow, probes, a key map, a
theme and two languages, so the first thing you change is the model rather
than the scaffolding — and there is no moment where the lab does not run.

## Options

| | |
|---|---|
| `<slug>` | lowercase kebab-case, e.g. `heat-101`. It becomes the directory name, the QML id after one substitution, and the URL segment in `/labs/run/?lab=<slug>`. |
| `--kind` | which template family. Discovered from `templates/` (see below). Default `continuous`. |
| `--purpose` | `learning`, `teaching` or `research`. Decides `paper.md`, `overview.grafli` and `lab-check.json`. Default `learning`. |
| `--dir` | parent directory for the lab. Relative paths resolve against the repo root. Default `labs`. |
| `--force` | overwrite an existing lab directory. |
| `--dry-run` | list what would be written, write nothing. |

Exit codes: `0` fine (a dry run included), `2` you asked for something that
cannot be done (bad slug, unknown kind or purpose, target exists without
`--force`), `1` a template is broken (it uses a token the generator does not
define).

## The tokens

Substitution is plain string replacement — there is no template language, no
conditionals and no partials, because a template here is a real lab that has
to keep loading while it sits in the tree. Exactly five tokens, replaced
literally, everywhere, in every generated file:

| Token | For `heat-101` | What it is for |
|---|---|---|
| `{{slug}}` | `heat-101` | directory name, record paths, the published URL |
| `{{Title}}` | `Heat 101` | the lab's display name |
| `{{id}}` | `heat_101` | identifier-safe form: QML ids, and the flow id (`{{id}}-intro`), which is a dictionary key prefix |
| `{{purpose}}` | `teaching` | as passed |
| `{{date}}` | `2026-09-02` | ISO date the lab was started |

After substitution **no `{{` may survive**. A leftover means a template used a
token that does not exist, and the generator refuses to write the lab rather
than leaving a hole in it.

## The templates tree

```
templates/
    common/                what every lab gets: qmldir, figures/make.sh
    purposes/<purpose>/    paper.md, overview.grafli, lab-check.json
    <kind>/                Sandbox.qml, strings.js, records/make.sh
```

Three layers, applied in that order; a later layer wins on the same path. So
a kind may override anything `common/` provides just by shipping its own copy.

**A kind is a directory under `templates/` that contains a `Sandbox.qml`.**
Nothing lists the kinds — not the Python, not the help text, not the CMake,
not the tests. `common` and `purposes` are the two reserved names.

### Adding a kind

1. `mkdir templates/<kind>` and put a working `Sandbox.qml` in it, plus its
   own `strings.js` and `records/make.sh` (the scenario names in the driver
   have to be the ones the sandbox declares — the test checks that).
2. Nothing else. `lab-new --kind <kind>` works, `python3
   tests/run_lab_new_tests.py` covers it, and the next `cmake` configure
   registers `lab_new_boot_<kind>`.

Write the new sandbox by copying the nearest existing kind rather than from
scratch: the conventions block, the HUD slots and the key map are the same in
every lab, and the checks in `tests/` enforce exactly that.

## The kinds that ship

**`continuous`** — a mass on a damped, optionally driven spring. Nothing is
built or selected, so the left mouse button is free to pan the view; the plot
sits bottom-right; the flow's demo step turns a knob (`setParam`). This is the
starting point for anything that runs on its own while you watch it.

**`draw`** — a sheet you drag lines onto, snapped to the grid, with a click
selecting the nearest line and `Del`/`C`/`E` removing them. The left button is
always the sheet's and never the camera's; the gesture lives in named
`pressAt`/`moveAt`/`releaseAt`/`clickAt`/`dragFrom` functions so a flow, a test
or an agent can perform the same drag a hand does. The watch monitor sits
bottom-right. This is the starting point for anything you author by hand.

## How the tests work

Both are registered in `CMakeLists.txt` and run under `ctest`.

**`lab_new`** — `tests/run_lab_new_tests.py`, a stdlib `unittest` suite, no
engine and no build. It generates every *discovered* kind × every *discovered*
purpose into a temp directory and checks the file set, that no `{{` survives,
that the two drivers are executable, that the EN and DE key sets in
`strings.js` are identical, that every key the sandbox looks up is defined,
that the flow id agrees between `Sandbox.qml`, `strings.js` and
`lab-check.json`, that the scenario names in `records/make.sh` exist in the
lab, that `paper.md` opens the way `docs/scripts/import_labs.py` reads it, and
the CLI's exit codes (refuse-to-overwrite, `--force`, `--dry-run`, bad slug,
unknown kind). `strings.js` is read with a brace-matching parser; when `node`
happens to be installed one extra test evaluates the file for real and checks
the parser agrees. `node` is never required.

```sh
python3 tools/lab-new/tests/run_lab_new_tests.py
```

**`lab_new_boot_<kind>`** — `tests/run_boot_test.py`, one per discovered kind.
It generates a lab, boots it in `clayliveloader` offscreen and drives it
through the file-based inspector protocol (`.clay/inspect/`) exactly as
`tools/loader/tests/gym` does: wait for `phase == "ready"`, then `eval`
`scenarios()` and `labInfo()` and require both to answer, then read
`log.jsonl` and require no `qml` warning or error. Exits **77** (the ctest
`SKIP_RETURN_CODE`) when the loader has not been built, because a template
check that fails on a machine without a build says nothing about the template.

```sh
python3 tools/lab-new/tests/run_boot_test.py \
    --loader build/bin/clayliveloader --kind continuous
```

## After generating

```sh
./build/bin/claydojo --sbx labs/<slug>/Sandbox.qml
```

Then, in order: the strings, the model, the scenarios, the flow — and the
paper and the board **last**, out of committed run records
(`labs/<slug>/records/make.sh`). See `skills/clay-lab/SKILL.md` for the full
recipe and `skills/clay-lab/references/pitfalls.md` before writing any 3D code.
