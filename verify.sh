#!/usr/bin/env bash
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Builds and runs the tests a change can affect (#384).
#
#   ./verify.sh                 changes against the branch's base
#   ./verify.sh --base <ref>    changes against <ref> instead
#   ./verify.sh --all           the full suite
#   ./verify.sh --list          print what would run, build and run nothing
#   ./verify.sh -- <args>       pass <args> on to ctest
#
# The branch's base is the closest of origin/main and origin/release/* - the
# one HEAD is the fewest commits ahead of. Which tests a change reaches is
# worked out from the build's target graph and the QML imports by
# tools/verify/select_tests.py; a change to a shared build file, or to
# anything it cannot map, runs everything. CI always runs everything.
#
# Uses the "default" presets and ./build. Qt comes from CMAKE_PREFIX_PATH, as
# for `cmake --preset default` (see CLAUDE.md, "Build, run, test").

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build="$root/build"
preset=default
mode=affected
base=""
ctest_args=()

while [ $# -gt 0 ]; do
    case "$1" in
        --all) mode=all ;;
        --list) mode=list ;;
        --base) base="${2:?--base needs a ref}"; shift ;;
        --) shift; ctest_args=("$@"); break ;;
        -h|--help) sed -n '3,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "verify.sh: unknown argument '$1' (see --help)" >&2; exit 2 ;;
    esac
    shift
done

cd "$root"

# A fresh worktree has its submodules uninitialised ('-' in the status), and
# configure fails on the first add_subdirectory(thirdparty/...) (#385)
if git submodule status --recursive | grep '^-' >/dev/null; then
    git submodule update --init --recursive
fi

# The File API query makes every configure write the target graph the
# selection reads; a build dir configured before it existed gets it now.
query="$build/.cmake/api/v1/query/codemodel-v2"
if [ ! -f "$build/CMakeCache.txt" ]; then
    mkdir -p "$(dirname "$query")" && touch "$query"
    cmake --preset "$preset"
elif [ ! -f "$query" ] || ! ls "$build"/.cmake/api/v1/reply/index-*.json >/dev/null 2>&1; then
    mkdir -p "$(dirname "$query")" && touch "$query"
    cmake "$build"
fi

if [ "$mode" != list ]; then
    cmake --build --preset "$preset"
fi

if [ "$mode" = all ]; then
    exec ctest --preset "$preset" "${ctest_args[@]+"${ctest_args[@]}"}"
fi

selection="$(python3 "$root/tools/verify/select_tests.py" \
    --source "$root" --build "$build" ${base:+--base "$base"})"

if [ "$selection" = ALL ]; then
    [ "$mode" = list ] && { echo "all tests"; exit 0; }
    exec ctest --preset "$preset" "${ctest_args[@]+"${ctest_args[@]}"}"
fi
if [ -z "$selection" ]; then
    echo "verify.sh: no test can be affected by this change"
    exit 0
fi
if [ "$mode" = list ]; then
    echo "$selection"
    exit 0
fi

# One anchored alternative per test name; names carry no regex syntax but
# '.' and '+' are escaped all the same.
regex="^($(printf '%s\n' "$selection" | sed 's/[.+]/\\&/g' | paste -sd '|' -))\$"
exec ctest --preset "$preset" -R "$regex" "${ctest_args[@]+"${ctest_args[@]}"}"
