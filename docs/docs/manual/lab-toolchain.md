---
layout: docs
title: Building a lab
permalink: /docs/manual/building-a-lab/
---

A lab is a deterministic teaching or experiment space: a `Sandbox.qml` built
from the [Lab plugin]({{ site.baseurl }}/docs/plugins/lab/) and the domain kits
under `labs/kits/`, plus its strings, its paper and its board. Three tools take
a lab from nothing to a published claim, and one agent skill says how to write
it:

| Tool | What it does | Its README |
|---|---|---|
| `lab-new` | generates a new lab that loads and passes the check from its first commit | [tools/lab-new/README.md](https://github.com/MisterGC/clayground/blob/main/tools/lab-new/README.md) |
| `lab-check` | checks a lab's contract: loads clean, deterministic runs, flows, strings, records, tables | [tools/lab-check/README.md](https://github.com/MisterGC/clayground/blob/main/tools/lab-check/README.md) |
| `lab-sweep` | runs a study's matrix of runs and writes one record per run | [tools/lab-sweep/README.md](https://github.com/MisterGC/clayground/blob/main/tools/lab-sweep/README.md) |
| `lab-table` | renders the tables in a paper or study from those records | [tools/lab-sweep/README.md](https://github.com/MisterGC/clayground/blob/main/tools/lab-sweep/README.md#tables-a-number-enters-a-paper-only-through-a-record) |

The authoring contract - definition of done by purpose, conventions, key map,
verification commands - is the `clay-lab` skill,
[skills/clay-lab/SKILL.md](https://github.com/MisterGC/clayground/blob/main/skills/clay-lab/SKILL.md).
It is written for an AI coding agent and reads just as well for a person.

This page walks one lab, `heat-101`, through the whole path. Every command runs
from the root of a clayground checkout with a build in `build/` (see
[Installation]({{ site.baseurl }}/docs/getting-started/installation/)). The
options of each tool are in its README; this page shows the order you use them
in.

## 1. Generate the lab

```bash
tools/lab-new/lab-new heat-101 --dry-run
tools/lab-new/lab-new heat-101 --kind continuous --purpose teaching
```

The first line lists what would be written and writes nothing. The second
creates `labs/heat-101/` with a `Sandbox.qml`, a bilingual `strings.js`, a
records driver, a figures driver, a `lab-check.json`, and the `paper.md` and
`overview.grafli` skeletons for the purpose.

Two choices are made here:

- `--kind` is the template the lab starts from: `continuous` (something that
  runs on its own while you watch), `draw` (something you author by hand on
  a sheet) or `build` (parts placed on a board, wired together and solved).
  The kinds are the directories under `tools/lab-new/templates/` that hold a
  `Sandbox.qml`.
- `--purpose` is what the lab is for: `learning`, `teaching` or `research`.
  It decides what `lab-check` demands of the lab later, and is kept in
  `labs/heat-101/lab-check.json`.

## 2. Open it and make it yours

```bash
./build/bin/claydojo --sbx labs/heat-101/Sandbox.qml
```

The dojo reloads the lab on every save. The generated lab already has
scenarios, a flow, probes, a key map and two languages, so the work is
replacing them, in this order: the strings, the model, the scenarios, the
flow. The paper and the board come last, written from committed run records
(`labs/heat-101/records/make.sh`).

Before you write the model, read the skill:
[skills/clay-lab/SKILL.md](https://github.com/MisterGC/clayground/blob/main/skills/clay-lab/SKILL.md),
and [references/pitfalls.md](https://github.com/MisterGC/clayground/blob/main/skills/clay-lab/references/pitfalls.md)
before any 3D code. To have an agent such as Claude Code work by it, install
it once:

```bash
./skills/clay-lab/install.sh            # for the repository you are in
./skills/clay-lab/install.sh --user     # for all your projects
```

The skill's [README](https://github.com/MisterGC/clayground/blob/main/skills/clay-lab/README.md)
lists its reference files.

## 3. Check it

```bash
tools/lab-check/lab-check labs/heat-101
```

Each check prints a `PASS` or `FAIL` line; any `FAIL` is exit code 1. To
repeat only the part you are working on:

```bash
tools/lab-check/lab-check labs/heat-101 --only flows
tools/lab-check/lab-check labs/heat-101 --only determinism --keep
```

Every directory under `labs/` with a `Sandbox.qml` also gets a CTest gate,
`lab_check_<lab>`, at the next configure:

```bash
cmake --preset default
ctest --preset default -R lab_check_heat-101    # this lab
ctest --preset default -R lab_check             # every lab
```

What each check asserts, and what each purpose adds, is in
[tools/lab-check/README.md](https://github.com/MisterGC/clayground/blob/main/tools/lab-check/README.md);
what to do about each failure line is in the skill's
[references/check-failures.md](https://github.com/MisterGC/clayground/blob/main/skills/clay-lab/references/check-failures.md).

## 4. Ask a question: a study

A study is one question asked of the lab: an objective, what is held fixed,
what is varied, how many seeds, and a cap on the number of runs. It is a
`study.md` under the lab's `studies/`, prose first, with one JSON block (the
manifest) inside it. Any lab may have one. A research lab must, and for it
`lab-check`'s `study` check requires at least one study whose manifest
parses, with committed records (`records/*.labrec`) and an `## Answerability`
section: the argument that the lab's model holds for the question. For a
learning or teaching lab the `study` check asks for nothing. The worked
example is
[labs/street-network-101/studies/topology-four-houses/](https://github.com/MisterGC/clayground/tree/main/labs/street-network-101/studies/topology-four-houses);
the manifest's keys are in
[tools/lab-sweep/README.md](https://github.com/MisterGC/clayground/blob/main/tools/lab-sweep/README.md#the-manifest).

With the study at `labs/heat-101/studies/insulation/study.md`:

```bash
tools/lab-sweep/lab-sweep labs/heat-101/studies/insulation --check     # every probe and parameter it names exists
tools/lab-sweep/lab-sweep labs/heat-101/studies/insulation --dry-run   # print the matrix, run nothing
tools/lab-sweep/lab-sweep labs/heat-101/studies/insulation             # run it
```

The run writes one `.labrec` per run into the study's `records/` and the
results table into its `results.md`. A run filtered with `--only` or `--seed`
rewrites its records and leaves `results.md` alone.

## 5. Put the numbers in the paper

A number enters a paper only through a record. A study's manifest declares
`tables`; the paper marks where one goes:

```
<!-- table: insulation/losses -->
<!-- /table -->
```

and `lab-table` fills it from the records:

```bash
tools/lab-sweep/lab-table labs/heat-101            # render the paper's tables
tools/lab-sweep/lab-table labs/heat-101 --check    # exit 1 if one is stale
```

## 6. Check it again

```bash
tools/lab-check/lab-check labs/heat-101
```

With a study and a paper in place, the `records` and `tables` checks now have
something to compare: the committed records must regenerate to the same
bytes, and every table in `paper.md` and `study.md` must render to what is
committed. For a research lab the `study` check also runs on each study: its
manifest parses, its records are committed and it has an `## Answerability`
section (step 4). Commit the records and the rendered tables together with
the change that produced them.

## Labs to read

- `labs/electronics-101/` - a teaching lab on the board layer, with the study
  `studies/series-vs-parallel/` whose tables its paper quotes.
- `labs/street-network-101/` - a research lab with three studies.
- The [labs gallery]({{ site.baseurl }}/labs/) - the published labs, running
  in the browser.
