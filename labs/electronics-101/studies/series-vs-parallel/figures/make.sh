#!/bin/sh
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# The two pictures in the study, regenerated. Both boards are built by the
# lab's own presets and driven to the same cell voltage the sweep used, so a
# figure and a record cannot disagree: 6 V is the level where the two wirings
# differ in KIND and not only in size - the series pair is well inside the
# cell's rating, the parallel pair is past it.
#
# The clock is stepped by hand, exactly as tools/lab-sweep does it, because a
# frame is a wall-clock interval and a lab left to play itself is not
# reproducible.
#
# Usage: labs/electronics-101/studies/series-vs-parallel/figures/make.sh
set -e

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../../.." && pwd)
render="$root/build/bin/clayrender"
sandbox="$root/labs/electronics-101/Sandbox.qml"

[ -x "$render" ] || {
    echo "clayrender not found at $render - build it first" >&2
    echo "  cmake --build build --target clayrender" >&2
    exit 1
}

shot() {
    wiring=$1
    "$render" "$sandbox" \
        --eval 'clock._frameTicker.running = false' \
        --eval "applyScenario(\"$wiring\")" \
        --eval 'elements.filter(e => e.type === "switch").forEach(e => { if (!e.on) toggleSwitch(e.id) })' \
        --eval 'elements.filter(e => e.type === "battery").forEach(e => setBatteryVolts(e.id, 6))' \
        --eval 'showValues = true; showPlan = false; selectedId = -1' \
        --eval 'clock.reset(); for (var i = 0; i < 60; ++i) clock._advance(1/60)' \
        --wait-for 'labInfo().circuit.nets > 0' \
        --settle \
        --size 1400x900 --scale 0.7 \
        --out "$here/$wiring.png"
}

shot series
shot parallel

echo "wrote $here/series.png and $here/parallel.png"
