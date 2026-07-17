# clay-crew — agent skill for the Clayground Dojo

`SKILL.md` teaches an AI coding agent how to collaborate on Clayground
sandboxes through the Dojo's file-based inspector protocol
(`.clay/inspect/`). This directory is the skill's source of truth — it
is versioned and released together with the engine, so it always matches
the protocol the binaries actually speak.

## Installation

**Claude Code (per project):** symlink the skill into the project's
skill directory — Claude Code picks it up automatically:

```bash
./skills/clay-crew/install.sh            # installs into .claude/skills/ of the current repo
./skills/clay-crew/install.sh --user     # installs into ~/.claude/skills/ for all projects
```

**Codex / other agents (AGENTS.md-based):** add one line to your
`AGENTS.md`:

```markdown
When verifying Clayground sandbox output, follow skills/clay-crew/SKILL.md.
```

**CI:** no skill needed — automated verification uses the inspector
protocol directly (see `tools/loader/tests/`).

## Versioning

The skill documents the protocol version shipped by this checkout. If
you use an older installed copy against a newer loader (or vice versa),
check `protocolVersion` in `.clay/inspect/state.json` once it is
available and prefer the copy from the matching checkout.
