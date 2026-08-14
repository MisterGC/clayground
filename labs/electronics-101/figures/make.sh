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
# WIDTH IS A HARD LIMIT, NOT A PREFERENCE. The paper is read as a single
# column - textli's reading view and its PDF export place an image at its own
# pixel size and do NOT scale it down, and there is no width syntax in the
# markdown that either honours (an <img> tag renders as literal text). An A4
# page leaves about 520 px between the text margin and the paper's edge, so
# anything wider is silently CUT OFF at the right. 500 px is the budget here,
# with a little room to spare.
#
# That budget is why several shots hide panels they do not need: at 500 px
# across, every pixel spent on chrome the figure is not about is a pixel of
# circuit nobody can read.
#
# Usage: labs/electronics-101/figures/make.sh
set -e

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
render="$root/build/bin/clayrender"
sandbox="$root/labs/electronics-101/Sandbox.qml"

# The one number the paper's layout allows. See the note above.
PAGE_WIDTH=500

[ -x "$render" ] || {
    echo "clayrender not found at $render - build it first" >&2
    echo "  cmake --build build --target clayrender" >&2
    exit 1
}

# Hold the clock still, then advance it by a fixed number of steps: enough for
# the solver to have answered and the rig to have arrived, never enough to
# depend on how fast the machine is.
settle_js='clock.reset(); for (var i = 0; i < 90; ++i) clock._advance(1/60)'

# What a figure about the circuit does not need. Chrome is not free at this
# width - every pixel it takes is a pixel of circuit nobody can read.
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
shot board --size 1100x700 --width $PAGE_WIDTH \
    --eval 'applyScenario("led-basic")' \
    --eval 'elements.filter(e => e.type === "switch").forEach(e => toggleSwitch(e.id))' \
    --eval 'showValues = true; showPlan = false'

# The palette, cropped to itself: the claim that a kit can teach "this lump is
# that squiggle" for free is a claim about a picture. Small enough already, so
# it goes into the paper at its own size and stays sharp.
# 640 px is the other half of the budget: a figure taller than the text block
# is split across a page break, which cuts a panel in half.
shot palette --size 1400x900 --crop palette --crop-pad 8 --width 200 \
    --eval 'applyScenario("led-basic")'

# --- the headline contrast --------------------------------------------------
# Same two bulbs, same 4.5 V cell, only the wiring differs - the pair the
# paper's measured-results table is about. Panels off: at this width the
# wiring and its labels have to own the frame.
for wiring in series parallel; do
    shot "$wiring" --size 760x480 --width $PAGE_WIDTH \
        --eval "applyScenario(\"$wiring\")" \
        --eval 'elements.filter(e => e.type === "switch").forEach(e => toggleSwitch(e.id))' \
        --eval 'elements.filter(e => e.type === "battery").forEach(e => setBatteryVolts(e.id, 4.5))' \
        --eval 'showValues = true; showPlan = false' \
        --eval "$bare_js" \
        --eval 'rig.zoomBy(0.70)'
done

# The same parallel board with its schematic beside it: what you assembled and
# what it IS, which is the pair the paper argues you should watch at once.
# The schematic panel is anchored to step out from under the palette, so
# hiding the palette drops the panel on top of the board.
shot schematic --size 1400x900 --width $PAGE_WIDTH \
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
shot short --size 1400x900 --width $PAGE_WIDTH \
    --eval "$short_js" --eval 'frameSelection(); selectedId = -1' \
    --eval 'showValues = true; showPlan = false' \
    --eval "$bare_js" --eval 'transport.visible = true'

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
for f in "$here"/*.png; do
    w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    [ -z "$w" ] || [ "$w" -le 520 ] || echo "  WARNING $(basename "$f") is ${w}px wide - wider than the page, it will be cut off" >&2
    [ -z "$h" ] || [ "$h" -le 640 ] || echo "  WARNING $(basename "$f") is ${h}px tall - taller than the text block, it will be split across a page break" >&2
done
