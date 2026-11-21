#!/bin/sh
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Symlink the clay-lab skill, and its companion clay-crew, into a Claude Code
# skills directory.
#
#   install.sh           .claude/skills/ at the root of the git repository the
#                        current directory is in, from any folder inside it;
#                        outside a repository, the root of this checkout
#   install.sh --user    ~/.claude/skills/ (all projects)
#
# clay-crew comes along because clay-lab sends every verification step to it:
# a lab skill without the inspector protocol names commands it cannot explain.
set -e

usage() {
    echo "usage: $0 [--user]" >&2
}

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CREW_DIR="$(cd "$SKILL_DIR/../clay-crew" && pwd)"

MODE=project
case "$#:$1" in
    0:) ;;
    1:--user) MODE=user ;;
    1:-h|1:--help) usage; exit 0 ;;
    *) echo "install.sh: unknown argument(s): $*" >&2; usage; exit 2 ;;
esac

if [ "$MODE" = user ]; then
    TARGET="$HOME/.claude/skills"
else
    # The repository's root, not the current directory: run from labs/ or
    # skills/clay-lab/ the skill would otherwise land in a .claude/ that
    # Claude Code never reads.
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
        || ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel)"
    TARGET="$ROOT/.claude/skills"
fi

mkdir -p "$TARGET"
ln -sfn "$SKILL_DIR" "$TARGET/clay-lab"
echo "clay-lab skill linked: $TARGET/clay-lab -> $SKILL_DIR"
ln -sfn "$CREW_DIR" "$TARGET/clay-crew"
echo "clay-crew skill linked: $TARGET/clay-crew -> $CREW_DIR"
