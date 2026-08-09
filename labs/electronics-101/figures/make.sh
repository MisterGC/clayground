#!/bin/sh
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Every picture in paper.md, regenerated. A figure nobody can remake is a
# screenshot: it rots the first time the lab changes and nothing says so. One
# run of this script rewrites all of them, so "does the paper still look like
# the lab?" is a re-run and a git diff.
#
# Each shot stops the frame ticker and steps the clock by hand, exactly as
# tools/lab-sweep does, because a frame is a wall-clock interval and a lab left
# to play itself photographs a different instant every time.
#
# Renders never inherit your dojo settings - clayrender persists to a throwaway
# store - so these come out at the default theme, language and UI scale
# whatever your session currently looks like.
#
# Usage: labs/electronics-101/figures/make.sh
set -e

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
render="$root/build/bin/clayrender"
sandbox="$root/labs/electronics-101/Sandbox.qml"

[ -x "$render" ] || {
    echo "clayrender not found at $render - build it first" >&2
    echo "  cmake --build build --target clayrender" >&2
    exit 1
}

# Hold the clock still, then advance it by a fixed number of steps: enough for
# the solver to have answered and the rig to have arrived, never enough to
# depend on how fast the machine is.
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
# The circuit the paper opens with, lit, with every part and wire labelled.
shot board --size 1400x900 --width 1000 \
    --eval 'applyScenario("led-basic")' \
    --eval 'elements.filter(e => e.type === "switch").forEach(e => toggleSwitch(e.id))' \
    --eval 'showValues = true; showPlan = false'

# The palette, cropped to itself: the claim that a kit can teach "this lump is
# that squiggle" for free is a claim about a picture.
shot palette --size 1400x900 --crop palette --crop-pad 8 \
    --eval 'applyScenario("led-basic")'

# --- the headline contrast --------------------------------------------------
# Same two bulbs, same 4.5 V cell, only the wiring differs - the pair the
# paper's measured-results table is about.
for wiring in series parallel; do
    shot "$wiring" --size 1400x900 --width 900 \
        --eval "applyScenario(\"$wiring\")" \
        --eval 'elements.filter(e => e.type === "switch").forEach(e => toggleSwitch(e.id))' \
        --eval 'elements.filter(e => e.type === "battery").forEach(e => setBatteryVolts(e.id, 4.5))' \
        --eval 'showValues = true; showPlan = false'
done

# The same parallel board with its schematic beside it: what you assembled and
# what it IS, which is the pair the paper argues you should watch at once.
shot schematic --size 1400x900 --width 1000 \
    --eval 'applyScenario("parallel")' \
    --eval 'elements.filter(e => e.type === "switch").forEach(e => toggleSwitch(e.id))' \
    --eval 'showValues = false; showPlan = true'

# --- the fault --------------------------------------------------------------
# One wire from + to -. The banner drops, the wire goes to alarm colour, and
# the cell's own budget bar goes entirely red.
#
# These two are the only shots where --settle reports "still moving" and
# captures anyway: a fault pulses on purpose, so there is no still frame to
# wait for. The content is fixed, the animation phase is not, which is why
# these two can come back with a different diff on an unchanged lab.
short_js='clearBoard(); var b = addElement("battery", 8, 5); addWire([b, 0], [b, 1]); selectedId = b'
shot short --size 1400x900 --width 1000 \
    --eval "$short_js" --eval 'showValues = true; showPlan = false'

# And the bar on its own, because that is the part the prose cannot draw.
shot budget --size 1400x900 --crop partCard --crop-pad 8 \
    --eval "$short_js"

# --- an instrument in hand --------------------------------------------------
# The belt with the kit's voltmeter taken out: what "instruments you hold"
# looks like, next to the line telling you what a click will do.
shot belt --size 1400x900 --crop belt --crop-pad 6 \
    --eval 'applyScenario("led-basic")' \
    --eval 'hands.takeNamed("volts")'

echo "wrote $(ls "$here"/*.png | wc -l | tr -d ' ') figures in $here"
