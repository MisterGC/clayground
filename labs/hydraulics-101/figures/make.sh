#!/bin/sh
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Every picture in paper.md, regenerated. A figure nobody can remake is a
# screenshot: it rots the first time the lab changes and nothing says so. One
# run of this script rewrites all of them, so "does the paper still look like
# the lab?" is a re-run and a git diff.
#
# Each shot stops the frame ticker and steps the clock by hand, because a frame
# is a wall-clock interval and a lab left to play itself photographs a
# different instant every time.
#
# Renders never inherit your dojo settings - clayrender persists to a throwaway
# store - so these come out at the default theme, language and UI scale
# whatever your session currently looks like.
#
# FULL RESOLUTION, NEVER PRE-SHRUNK. textli scales an over-wide picture down to
# the prose column by itself and opens the FILE at full size on Enter, so a
# figure downscaled before it is written out has thrown away the only detail
# that view exists to show. Tune the FRAMING (--crop <objectName>), not the
# pixel count.
#
# Usage: labs/hydraulics-101/figures/make.sh
set -e

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
render="$root/build/bin/clayrender"
sandbox="$root/labs/hydraulics-101/Sandbox.qml"

[ -x "$render" ] || {
    echo "clayrender not found at $render - build it first" >&2
    echo "  cmake --build build --target clayrender" >&2
    exit 1
}

# Hold the clock still, then advance it by a fixed number of steps: enough for
# the lab to have answered and the rig to have arrived, never enough to depend
# on how fast the machine is.
settle_js='clock.reset(); for (var i = 0; i < 90; ++i) clock._advance(1/60)'

shot() {
    name=$1; shift
    "$render" "$sandbox" \
        --eval 'clock._frameTicker.running = false' \
        "$@" \
        --eval "$settle_js" \
        --settle \
        --out "$here/$name.png"
}

# --- the lab itself ---------------------------------------------------------
# The one shot that keeps the WHOLE window: it answers "what does this lab look
# like", so the palette, the parameters and the monitor belong in it. Every
# other figure crops to the thing it is about - add them below as the paper
# grows, one shot per claim.
shot board --size 1400x900 \
    --eval 'applyScenario("intro")'

echo "wrote $(ls "$here"/*.png | wc -l | tr -d ' ') figures in $here"
