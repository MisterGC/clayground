# clay-lab — agent skill for composing Clayground labs

`SKILL.md` is the contract an AI coding agent authors a Clayground lab
against: the definition of done by purpose, the conventions that make a lab
operable by the inspector and by flows, the design rules, the key map, the
verification commands — rules only, under 300 lines. The `references/`
files carry the depth: `catalog.md` (every kernel block, **generated** from
the qdoc briefs by `docs/scripts/lab_catalog.py`; ctest `lab_catalog` fails
when it is stale), `pitfalls.md` (the one list of traps), `flows.md` (the
flow-authoring recipe), `teaching.md` (what makes a lesson explain, the
German, the narration audio, the checklist before handover),
`triad.md` (paper, board, records, figures, studies),
`check-failures.md` (every line `lab-check` can fail with, and what to
do) and `kits.md` (each kit's README, the professor, adding a part to a
kit). The *why* behind the rules is `plugins/clay_lab/README.md`.

Sibling of `skills/clay-crew`, which owns *verification* through the
Dojo's inspector protocol — clay-lab composes, clay-crew proves. Both are
versioned and released with the engine so the skill always matches the
block APIs the checkout actually provides.

## Installation

**Claude Code (per project):**

```bash
./skills/clay-lab/install.sh            # .claude/skills/ at the root of the repo you are in
./skills/clay-lab/install.sh --user     # ~/.claude/skills/ for all projects
```

Both link clay-crew beside clay-lab, which hands every verification step
to it. Run from any folder of a repository, the project install lands at
its root; outside one, at the root of this checkout. Any other argument
is refused (exit 2).

**Codex / other agents (AGENTS.md-based):** add one line to your
`AGENTS.md`:

```markdown
When building or extending Clayground labs, follow skills/clay-lab/SKILL.md.
```

## Versioning

The skill documents the kernel (`plugins/clay_lab/`) and kit APIs shipped
by this checkout. When in doubt, prefer the copy from the checkout whose
binaries you are running.
