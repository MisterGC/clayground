# clay-lab — agent skill for composing Clayground labs

`SKILL.md` is the contract an AI coding agent authors a Clayground lab
against: the definition of done by purpose, the conventions that make a lab
operable by the inspector and by flows, the design rules, the key map, the
verification commands — rules only, under 300 lines. The `references/`
files carry the depth: `catalog.md` (every kernel block, **generated** from
the qdoc briefs by `docs/scripts/lab_catalog.py`; ctest `lab_catalog` fails
when it is stale), `pitfalls.md` (the one list of traps), `flows.md` (the
flow-authoring recipe) and `triad.md` (paper, board, records, figures,
studies). The *why* behind the rules is `plugins/clay_lab/README.md`.

Sibling of `skills/clay-crew`, which owns *verification* through the
Dojo's inspector protocol — clay-lab composes, clay-crew proves. Both are
versioned and released with the engine so the skill always matches the
block APIs the checkout actually provides.

## Installation

**Claude Code (per project):**

```bash
./skills/clay-lab/install.sh            # installs into .claude/skills/ of the current repo
./skills/clay-lab/install.sh --user     # installs into ~/.claude/skills/ for all projects
```

**Codex / other agents (AGENTS.md-based):** add one line to your
`AGENTS.md`:

```markdown
When building or extending Clayground labs, follow skills/clay-lab/SKILL.md.
```

## Versioning

The skill documents the kernel (`plugins/clay_lab/`) and kit APIs shipped
by this checkout. When in doubt, prefer the copy from the checkout whose
binaries you are running.
