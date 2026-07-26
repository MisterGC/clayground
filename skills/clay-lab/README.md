# clay-lab — agent skill for composing Clayground labs

`SKILL.md` teaches an AI coding agent how to *compose* a Clayground lab:
which blocks exist and when to reach for which, the conventions that make
a lab operable by the inspector and by flows, the paper-and-ink design
language, the determinism contract, and the lab–paper–board triad that
defines "done". The `references/` files carry the depth: the hard-won
pitfall list, the flow-authoring recipe, and the triad conventions.

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
