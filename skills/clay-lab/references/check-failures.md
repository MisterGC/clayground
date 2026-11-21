# When lab-check is red

`tools/lab-check/lab-check labs/<slug>` prints one `PASS`, `FAIL` or `NOT RUN`
line per check, then `n/m checks passed, k not run` and a `FAILED` or `NOT RUN`
line for each that is not a pass. Exit 0 is green, 1 is any FAIL - or, with
`--strict`, any NOT RUN - 2 is a usage error (no `Sandbox.qml` in that
directory, or an unknown name after `--only`), 77 is a skip: the machine has
no `build/bin/clayliveloader`. The text in brackets after a FAIL line is the
detail; it names what to look at. The checks and the purpose table:
`tools/lab-check/README.md`.

Two flags help with every line below: `--only <check>` reruns just that
check, `--verbose` lets the loader write to the terminal, `--keep` keeps the
temporary directory with the determinism runs' records.

## The lab cannot be judged

| line | what to do |
|---|---|
| `config: lab-check.json parses` | the file is not valid JSON; the detail is the parser's message |
| `config: lab-check.json declares a purpose` | add `"purpose": "learning"`, `"teaching"` or `"research"` — there is no default |
| `SKIP  …/clayliveloader does not exist` (exit 77) | build it: `cmake --build build --target clayliveloader` |

## Load and contract

| line | what to do |
|---|---|
| `load: the lab reaches phase ready` | the scene never finished loading. Open it with `--verbose`, or in the dojo, and read the first QML error |
| `load: a root object exists` | the load ended without a live root; usually the same first error as above |
| `load: the lab logged no qml warning or error` | the detail quotes up to four warnings from files of this lab. Fix each — a binding loop or an undefined property is a warning here, and a warning fails. Lines marked `(environment, not the lab)` do not count |
| `load: the lab came up` | the load failed, so no other check ran. Fix the load first |
| `contract: the lab answers scenarios()/flows()` | the gate evaluates in the root's context: the root needs `id: root` and both functions |
| `contract: scenarios() answers with a non-empty list` | every lab has at least one scenario, and it cold-opens into it |

## Determinism

`determinism: <scenario>` is red with one of two details:

- **a first differing line** of the two records, e.g. `line 41: '…' vs
  '…'`. Something the run reads did not come from `SimClock`: a
  `Math.random()`, a wall-clock time, a decoration that consumes the sim's
  RNG, or state the lab derives from `t` and does not snap on `wasReset`.
  A record is a JSON header, then tab-separated samples whose columns the
  header lists under `samples.columns`. `pitfalls.md`, *Determinism*,
  has every case that has happened so far. `--keep` leaves both records to
  diff in full.
- **an error** (`the lab never reached phase ready`, `no record written`,
  a script error from `applyScenario`): the scenario's `script` throws, or
  the lab does not come back from a reload. Run the scenario by hand:
  `clayrender labs/<slug>/Sandbox.qml --out /tmp/x.png --paused --result -
  --eval 'root.applyScenario("<name>")'`.

## Flows

| detail after `flows: <id>` | what to do |
|---|---|
| `flows: the lab has at least one` | a teaching lab owes a flow: add one and list it in `flows()` |
| `unresolved verb <name>` | a step names a verb that `flowActions()` does not return — a typo, or the verb was renamed |
| `task never satisfied: <step>` | a learner task's condition never became true while the flow drove the lab. Read its condition against what the steps before it built; the flow's own verbs must make it reachable |
| `expect failed: <step>` | the measured value is not the one the step claims. Either the lab changed (fix the narration and the expect together) or the expect reads an interpolant: read a goal (`spread`, `focus`), never a `…Now` value |
| `finished: false` | the flow stopped before its last step — often `maxFlowSteps` in `lab-check.json` (default 20000 sim frames) is shorter than the flow's waits |
| `flows() does not publish this id` | `lab-check.json` lists an id that `flows()` does not return |
| `no step carries an expect` | a teaching flow asserts at least one measured value; add an `expect` to the step that states one |
| `the lab did not come up for this run` | a fresh lab for this flow failed to load; see *Load* |

One flow by hand: `clayrender labs/<slug>/Sandbox.qml --out /tmp/x.png
--paused --result - --eval 'Lab.runFlow("<id>")'` (`flows.md`).

## Strings

| line | what to do |
|---|---|
| `strings: the lab registers EN` | call `LabLang.register` with the lab's EN dictionary before the first `applyScenario` |
| `strings: the lab registers DE` | a teaching lab owes German: add the `de` half of `strings.js` (`teaching.md`) |
| `strings: EN and DE carry the same keys` | the detail lists the first keys only in one language; add the missing translations, never delete a key to pass |
| `strings: every key a FlowStep needs exists in EN and DE` | a step's narration key `flow.<flowId>.<stepKey>` is missing in one dictionary |

## Records, tables, study, board

| line | what to do |
|---|---|
| `records: <driver> regenerates` with `exit <n>` | the driver itself failed. Run it: `labs/<slug>/records/make.sh`, or `tools/lab-sweep/lab-sweep labs/<slug>/studies/<study>` |
| `records: <driver> regenerates to the committed bytes` | the model, a sensor or the RNG use changed. Rerun the driver, commit the new records, and re-read every number the paper quotes from them in the same commit. A note after the line gives the first difference |
| `NOT RUN  records: <driver> regenerates` | `clayrender` is missing or there is no graphics session; the records were not compared. Pass the one you built with `--clayrender <path>`, and run with `--strict` on a machine with a display before you call them current |
| `tables: <file> <study>/<name>` with `differs from the records` | run `tools/lab-sweep/lab-table labs/<slug>` and commit what it writes; the lines between the markers are never typed |
| `study: a research lab has at least one study` | add `studies/<slug>/study.md` (`tools/lab-sweep/README.md`) |
| `study: <name>` | the detail says which part is missing: a manifest that does not parse, no committed `records/*.labrec`, or no `## Answerability` section |
| `triad: paper.md exists` | every lab has a `paper.md` |
| `triad: overview.grafli exists` | a teaching or learning lab owes the board (`triad.md`) |
| `protocol: no response for <action>` | the loader stopped answering the inspector — it crashed or hung. Rerun with `--verbose` and read its last lines |

`remarks` is never red: it counts the open CriticMarkup marks in the paper
and the studies, so you see them before you cite the prose.
