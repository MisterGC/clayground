#!/usr/bin/env bash
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Produces the committed run records for sensor-fusion-101 (#203).
#
#     labs/sensor-fusion-101/records/make.sh              # all scenarios
#     labs/sensor-fusion-101/records/make.sh open-sky     # one of them
#     labs/sensor-fusion-101/records/make.sh --verify     # determinism check
#
# Each record's "command" field is this script plus the scenario name, built
# here from $0 - so what a record says about how to regenerate it cannot drift
# from what actually regenerates it.
#
# WHY THE RUN IS STEPPED RATHER THAN PLAYED. Left to itself the lab advances on
# a FrameAnimation, and a frame is a wall-clock interval, so two runs of one
# seed sample the truth pose at different instants and diverge from the first
# tick (the caveat the paper carried until this landed). Stopping the ticker and
# calling clock._advance(1/60) by hand makes sim time a pure function of the
# step count, which is what the determinism contract always meant and what makes
# a record worth committing: same seed, same bytes.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
lab="sensor-fusion-101"
render="$root/build/bin/clayrender"
# how this script is spelled inside a record - repo-relative, so it reads the
# same on any machine
self="labs/$lab/records/make.sh"

SEED=42
STEPS=3600          # 60 simulated seconds at 1/60 s, sampled every 0.05 s
SCENARIOS=(open-sky tunnel lidar-out)

[ -x "$render" ] || { echo "build clayrender first: cmake --build build" >&2; exit 1; }

# $1 scenario, $2 destination (repo-relative), $3 record id
run_one() {
    local scenario="$1" out="$2" id="$3"
    "$render" "labs/$lab/Sandbox.qml" \
        --out "${TMPDIR:-/tmp}/${lab}-${scenario}.png" --size 800x500 --frames 1 \
        --eval "clock._frameTicker.running = false;
                clock.seed = $SEED;
                applyScenario('$scenario');
                recorder.lab = '$lab';
                recorder.destination = '$out';
                recorder.recordId = '$id';
                recorder.command = '$self $scenario';
                recorder.steps = $STEPS;
                recorder.stepSize = 1 / 60;
                recorder.recording = true;
                for (var i = 0; i < $STEPS; ++i) clock._advance(1 / 60);
                recorder.recording = false"
}

cd "$root"

if [ "${1:-}" = "--verify" ]; then
    # The determinism claim, as a command anyone can re-run: the same scenario
    # and seed twice, into two files, byte-compared.
    status=0
    for scenario in "${SCENARIOS[@]}"; do
        a="${TMPDIR:-/tmp}/${scenario}-a.labrec"
        b="${TMPDIR:-/tmp}/${scenario}-b.labrec"
        run_one "$scenario" "$a" "$scenario-$SEED" > /dev/null
        run_one "$scenario" "$b" "$scenario-$SEED" > /dev/null
        if cmp -s "$a" "$b"; then
            echo "deterministic: $scenario ($(wc -c < "$a" | tr -d ' ') bytes)"
        else
            echo "NOT deterministic: $scenario"; status=1
        fi
    done
    exit $status
fi

for scenario in "${@:-${SCENARIOS[@]}}"; do
    out="labs/$lab/records/$scenario-$SEED.labrec"
    run_one "$scenario" "$out" "$scenario-$SEED"
    echo "wrote $out ($(wc -c < "$out" | tr -d ' ') bytes)"
done
