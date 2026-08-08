#!/usr/bin/env bash
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# The study's figures (#203).
#
#     labs/street-network-101/studies/topology-four-houses/figures/make.sh
#
# Illustrations only - every number the study quotes comes out of a record in
# ../records/, never off a picture. What these are for is the one thing a
# table cannot show: that the ring has no queue anywhere and the cross has one
# on every approach.
#
# Stepped, not played, for the same reason the records are: a frame is a
# wall-clock interval, so a lab left to play itself would frame a different
# instant on every machine and the two pictures would stop being comparable.
# 2700 steps is 45 simulated seconds at the study's seed.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../../.." && pwd)"
render="$root/build/bin/clayrender"
lab="labs/street-network-101/Sandbox.qml"

SEED=42
STEPS=2700
HOUSES="[[-70,-45],[70,-45],[-70,45],[70,45]]"

[ -x "$render" ] || { echo "build clayrender first: cmake --build build" >&2; exit 1; }

# $1 name, $2 the roads, as calls to addRoad
shot() {
    local name="$1" roads="$2"
    "$render" "$lab" \
        --out "labs/street-network-101/studies/topology-four-houses/figures/$name.png" \
        --size 1100x720 --frames 3 --prefs isolated \
        --eval "clock._frameTicker.running = false;
                clock.seed = $SEED;
                clearPlan();
                setHouses($HOUSES);
                $roads
                Lab.scenario = 'four-houses/$name';
                clock.reset();
                Lab.set('demand', 0.5);
                framePlan();
                for (var i = 0; i < $STEPS; ++i) clock._advance(1 / 60)"
}

cd "$root"

shot ring "addRoad(-70,-45, 70,-45);
           addRoad(70,-45, 70,45);
           addRoad(70,45, -70,45);
           addRoad(-70,45, -70,-45);"

shot cross "addRoad(-70,-45, 0,0);
            addRoad(70,-45, 0,0);
            addRoad(-70,45, 0,0);
            addRoad(70,45, 0,0);"
