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
# FULL RESOLUTION, NEVER PRE-SHRUNK. textli scales an over-wide picture down
# to the prose column by itself, and pressing Enter on one fills the window
# from the FILE rather than from the scaled page copy - so a screenshot
# downscaled before it is written out has thrown away the only detail that
# view exists to show, and bought nothing.
#
# Each shot is therefore captured at the window size the lab is really used
# at and written at that size. What is tuned here is the FRAMING, not the
# pixel count: a figure hides the panels it is not about, because chrome the
# reader has to look past is chrome at any resolution.
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

# What a figure about the circuit does not need. Chrome the reader has to
# look past costs the figure whatever its resolution.
#
# Hide panels rather than shrinking the window to crop them out: this lab's
# layout is RESPONSIVE, so a narrow render reflows the palette into a shape
# nobody using the lab has ever seen, and elides panel text into "the
# current...". A figure has to be a picture of the real thing.
bare_js='palette.visible = false; monitor.visible = false; hintBar.visible = false; hands.visible = false; topSwitches.visible = false; transport.visible = false'

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
# The one shot that keeps the whole window: it is the figure that answers
# "what does this lab look like", so the palette and the plot belong in it.
shot board --size 1400x900 \
    --eval 'applyScenario("led-basic")' \
    --eval 'elements.filter(e => e.type === "switch").forEach(e => toggleSwitch(e.id))' \
    --eval 'showValues = true; showPlan = false'

# The palette, cropped to itself: the claim that a kit can teach "this lump is
# that squiggle" for free is a claim about a picture. Small enough already, so
# it goes into the paper at its own size and stays sharp.
shot palette --size 1400x900 --crop palette --crop-pad 8 \
    --eval 'applyScenario("led-basic")'

# --- the headline contrast --------------------------------------------------
# Same two bulbs, same 4.5 V cell, only the wiring differs - the pair the
# paper's measured-results table is about. Panels off and the rig pulled in,
# so the wiring and its labels own the frame.
for wiring in series parallel; do
    shot "$wiring" --size 1400x900 \
        --eval "applyScenario(\"$wiring\")" \
        --eval 'elements.filter(e => e.type === "switch").forEach(e => toggleSwitch(e.id))' \
        --eval 'elements.filter(e => e.type === "battery").forEach(e => setBatteryVolts(e.id, 4.5))' \
        --eval 'showValues = true; showPlan = false' \
        --eval "$bare_js" \
        --eval 'rig.zoomBy(0.85)'
done

# The same parallel board with its schematic beside it: what you assembled and
# what it IS, which is the pair the paper argues you should watch at once.
# The schematic panel is anchored to step out from under the palette, so
# hiding the palette drops the panel on top of the board.
shot schematic --size 1400x900 \
    --eval 'applyScenario("parallel")' \
    --eval 'elements.filter(e => e.type === "switch").forEach(e => toggleSwitch(e.id))' \
    --eval 'showValues = false; showPlan = true' \
    --eval 'monitor.visible = false; hintBar.visible = false; hands.visible = false' \
    --eval 'topSwitches.visible = false; transport.visible = false'

# --- the fault --------------------------------------------------------------
# One wire from + to -. The banner drops, the wire goes to alarm colour, and
# the cell's own budget bar goes entirely red.
#
# These two are the only shots where --settle reports "still moving" and
# captures anyway: a fault pulses on purpose, so there is no still frame to
# wait for. The content is fixed, the animation phase is not, which is why
# these two can come back with a different diff on an unchanged lab.
short_js='clearBoard(); var b = addElement("battery", 8, 5); addWire([b, 0], [b, 1]); selectedId = b'
# Wide enough that the banner is not elided to "the current...", and with
# nothing selected because the card is the NEXT figure - the subject here is
# the banner and the wire carrying everything.
shot short --size 1400x900 \
    --eval "$short_js" --eval 'frameSelection(); selectedId = -1' \
    --eval 'showValues = true; showPlan = false' \
    --eval "$bare_js" --eval 'transport.visible = true'

# And the bar on its own, because that is the part the prose cannot draw.
shot budget --size 1400x900 --crop partCard --crop-pad 8 \
    --eval "$short_js"

# --- the transistor ---------------------------------------------------------
# One NPN switched on: the meter in the base lead and the lamp branch in one
# frame, because the figure's whole job is to make those two numbers
# comparable at a glance. Values on, so both readings are printed.
shot transistor --size 1400x900 \
    --eval 'applyScenario("transistor"); setLogicInputs(1)' \
    --eval 'showValues = true; showPlan = false' \
    --eval "$bare_js" \
    --eval 'rig.zoomBy(0.9)'

# One transistor alone, unrotated, close up: a picture of the PART rather than
# of a circuit, because which leg is which is the one thing about it a reader
# cannot deduce from the shape. On a board it is normally turned a quarter and
# the print turns with it, the way silkscreen does - which is exactly why the
# figure that has to be legible puts it back the right way up.
shot pinout --size 900x700 \
    --eval 'clearBoard(); addElement("transistor", 14, 8)' \
    --eval 'showPlan = false' --eval "$bare_js" \
    --eval 'rig.applyState({px: 2.5, py: 2, pz: 2.5, distance: 17}); rig.pitch = 66'

# --- the gates --------------------------------------------------------------
# AND and OR as a PAIR on one input row: same two transistors, same lamp, only
# the wiring differs - which is the argument, and it is the same argument the
# series/parallel pair above makes with bulbs. The truth table stays in frame
# on purpose: it is the part of the claim a picture can actually carry.
gate_js='monitor.visible = false; hintBar.visible = false; hands.visible = false; topSwitches.visible = false; transport.visible = false; palette.visible = false'
for gate in and or; do
    shot "logic-$gate" --size 1400x900 \
        --eval "applyScenario(\"logic-$gate\"); setLogicInputs(2)" \
        --eval 'showPlan = false' --eval "$gate_js" \
        --eval 'rig.zoomBy(0.74); rig.panBy(-6, 0)'
done

# XOR twice on one seed, the pair the section is about: exactly one input on
# and the lamp lit, then both on and the lamp dark with more current available
# than before. Same board, same everything, one switch moved.
for row in 1 3; do
    shot "logic-xor-$row" --size 1400x900 \
        --eval "applyScenario(\"logic-xor\"); setLogicInputs($row)" \
        --eval 'showPlan = false' --eval "$gate_js" \
        --eval 'rig.zoomBy(0.78); rig.panBy(-6, 0)'
done

# The XOR from as far overhead as the rig goes (84 degrees, its maxPitch),
# which is the view that shows the ROUTING rather than the circuit. Overhead
# on purpose: the picture's claim is that every wire runs along one of two
# board directions, and from a low angle a vertical run and a slanted one
# look alike. The board still shears a little at 84 - what stays checkable is
# that the wires are PARALLEL, in two families and no third.
shot routing --size 1500x1000 \
    --eval 'applyScenario("logic-xor"); setLogicInputs(1)' \
    --eval 'showPlan = false' --eval "$bare_js" --eval 'truth.visible = false' \
    --eval 'rig.applyState({yaw: 0, pitch: 84, distance: 105, px: 0, py: 2, pz: 0})'

# The same argument at the other end of the scale: a voltmeter wired ACROSS an
# LED sits in the LED's own row, where a straight lead would be drawn on top of
# the wire already there. Its leads loop round instead, which is how a diagram
# draws a meter across a part.
shot across --size 1100x750 \
    --eval 'applyScenario("metering")' \
    --eval 'elements.filter(e => e.type === "switch").forEach(e => toggleSwitch(e.id))' \
    --eval 'showPlan = false' --eval "$bare_js" \
    --eval 'rig.applyState({yaw: 0, pitch: 84, distance: 58, px: -4, py: 2, pz: -6})'

# The XOR as a diagram: thirty-eight parts is where the schematic view stops
# being a nicety and starts being the only readable form of the circuit.
shot logic-xor-plan --size 1400x900 --crop schematic --crop-pad 8 \
    --eval 'applyScenario("logic-xor"); setLogicInputs(1)' \
    --eval 'showPlan = true; palette.visible = false'

# The truth table on its own, because "measured, not printed" is a claim about
# a panel and the prose cannot draw it.
shot truthtable --size 1400x900 --crop truthTable --crop-pad 8 \
    --eval 'applyScenario("logic-xor"); setLogicInputs(1)'

# --- the gate as a package --------------------------------------------------
# One chip, close enough that the five pin names and the printed function are
# legible: the claim that the board says which pin is which is a claim about a
# picture. Both inputs high, so the state pip beside the output is lit.
shot gate --size 900x700 \
    --eval 'applyScenario("gates"); setLogicInputs(3)' \
    --eval 'showPlan = false' --eval "$bare_js" \
    --eval 'rig.applyState({px: 32.5, py: 2, pz: 0, distance: 26}); rig.pitch = 60'

# The half adder: two packages, two lamps, and the truth table grown a second
# column. Kept whole rather than cropped, because the argument is that both
# answers come off one board at once.
shot half-adder --size 1400x900 \
    --eval 'applyScenario("half-adder"); setLogicInputs(3)' \
    --eval 'showPlan = false' --eval "$gate_js" \
    --eval 'rig.zoomBy(0.8); rig.panBy(-6, 0)'

# And its schematic, where the ANSI gate shapes do the work the 3D packages
# cannot: the D, the shield and the double curve say which gate is which
# without a word printed on anything.
shot half-adder-plan --size 1400x900 --crop schematic --crop-pad 8 \
    --eval 'applyScenario("half-adder"); setLogicInputs(3)' \
    --eval 'showPlan = true; palette.visible = false'

# --- an instrument in hand --------------------------------------------------
# The belt with the kit's voltmeter taken out: what "instruments you hold"
# looks like, next to the line telling you what a click will do.
shot belt --size 1400x900 --crop belt --crop-pad 6 \
    --eval 'applyScenario("led-basic")' \
    --eval 'hands.takeNamed("volts")'

echo "wrote $(ls "$here"/*.png | wc -l | tr -d ' ') figures in $here"
