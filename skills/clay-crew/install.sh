#!/bin/sh
# Symlink the clay-crew skill into a Claude Code skills directory.
# Default: .claude/skills/ of the current working directory (project scope).
# --user: ~/.claude/skills/ (all projects).
set -e

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$1" = "--user" ]; then
    TARGET="$HOME/.claude/skills"
else
    TARGET="$(pwd)/.claude/skills"
fi

mkdir -p "$TARGET"
ln -sfn "$SKILL_DIR" "$TARGET/clay-crew"
echo "clay-crew skill linked: $TARGET/clay-crew -> $SKILL_DIR"
