#!/bin/sh
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Every picture in paper.md, regenerated. A figure nobody can remake is a
# screenshot: it rots the first time the lab changes and nothing says so. One
# run of this script rewrites all of them, so "does the paper still look like
# the lab?" is a re-run and a git diff.
#
# Each shot holds the clock still (--paused) and waits for the scene to hold
# its pose (sceneReady) rather than for a settle: a sheet is posed 300 ms
# after it is created, and a capture before that shows zeroed joints.
#
# Renders never inherit your dojo settings - clayrender persists to a throwaway
# store - so these come out at the default theme, language and UI scale
# whatever your session currently looks like.
#
# FULL RESOLUTION, NEVER PRE-SHRUNK. textli scales an over-wide picture down to
# the prose column by itself and opens the FILE at full size on Enter, so a
# figure downscaled before it is written out has thrown away the only detail
# that view exists to show. Tune the FRAMING, not the pixel count.
#
# Usage: labs/character-101/figures/make.sh
set -e

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
render="$root/build/bin/clayrender"
sandbox="$root/labs/character-101/Sandbox.qml"

[ -x "$render" ] || {
    echo "clayrender not found at $render - build it first" >&2
    echo "  cmake --build build --target clayrender" >&2
    exit 1
}

# A scene in a state, waited for, then captured. Extra clayrender arguments
# come after the state.
shot() {
    name=$1; state=$2; shift 2
    QT_DISABLE_SHADER_DISK_CACHE=1 "$render" "$sandbox" --size 1400x900 --paused \
        --eval "$state" \
        --wait-for 'sceneReady' --wait-timeout 12000 --settle \
        "$@" \
        --out "$here/$name.png"
}

# The figures of the paper. One per aspect, in the tour's order, each in the
# state the paper's sentence about it describes.
shot lineup   'applyScenario("lineup"); goShot("quarter"); for (var i = 0; i < 20; ++i) clock._advance(1/60)'
shot gait     'applyScenario("gait"); act("preset", ["elderly"]); goShot("side")'
shot gait-top 'applyScenario("gait"); act("preset", ["elderly"]); goShot("top")'
shot gestures 'applyScenario("gestures"); goShot("quarter")'
shot action   'applyScenario("action"); act("action", ["fight"]); for (var i = 0; i < 36; ++i) clock._advance(1/60)'
shot moves    'applyScenario("moves"); goShot("quarter")'
shot hands    'applyScenario("hands"); act("pose", ["point"]); goShot("hand")'
shot faces    'applyScenario("faces"); goShot("face")'
shot heads    'applyScenario("heads"); goShot("face")'
shot speech   'applyScenario("speech"); goShot("face")'
shot conversation 'applyScenario("conversation"); goShot("over")'
shot crowd    'applyScenario("crowd"); goShot("quarter")'

echo "wrote $(ls "$here"/*.png | wc -l | tr -d ' ') figures in $here"
