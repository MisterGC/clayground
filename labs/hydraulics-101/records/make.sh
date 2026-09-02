#!/usr/bin/env bash
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Produces the committed run records for hydraulics-101. Every preset starts
# with its valve SHUT, so each run opens the valves first - a record of a
# loop nothing flows through would cite zeros.
#
#     labs/hydraulics-101/records/make.sh            # every scenario
#     labs/hydraulics-101/records/make.sh series     # one of them
#     labs/hydraulics-101/records/make.sh --verify   # determinism check
#
# Each record's "command" field is this script plus the scenario name, built
# here from the script's own path - so what a record says about how to
# regenerate it cannot drift from what actually regenerates it.
#
# WHY THE RUN IS STEPPED RATHER THAN PLAYED. Left to itself the lab advances on
# a FrameAnimation, and a frame is a wall-clock interval, so two runs of one
# seed sample the state at different instants and diverge from the first tick.
# Stopping the ticker and calling clock._advance(1/60) by hand makes sim time a
# pure function of the step count, which is what makes a record worth
# committing: same seed, same bytes.
#
# A paper may quote ONLY what a record holds. A number you cannot get out of
# one of these files is a missing probe, not a licence to read it off the panel.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
lab="hydraulics-101"
render="$root/build/bin/clayrender"
# how this script is spelled inside a record - repo-relative, so it reads the
# same on any machine
self="labs/$lab/records/make.sh"

SEED=42
STEPS=600           # 10 simulated seconds at 1/60 s, sampled every 0.1 s
SCENARIOS=(wheel-basic series parallel metering)

[ -x "$render" ] || {
    echo "clayrender not found at $render - build it first" >&2
    echo "  cmake --build build --target clayrender" >&2
    exit 1
}

# $1 scenario, $2 destination (repo-relative), $3 record id
run_one() {
    local scenario="$1" out="$2" id="$3"
    "$render" "labs/$lab/Sandbox.qml" \
        --out "${TMPDIR:-/tmp}/${lab}-${scenario}.png" --size 800x500 --frames 1 \
        --eval "clock._frameTicker.running = false;
                clock.seed = $SEED;
                applyScenario('$scenario');
                elements.filter(e => e.type === 'valve').forEach(e => setValve(e.id, true));
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
        a="${TMPDIR:-/tmp}/${lab}-${scenario}-a.labrec"
        b="${TMPDIR:-/tmp}/${lab}-${scenario}-b.labrec"
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
