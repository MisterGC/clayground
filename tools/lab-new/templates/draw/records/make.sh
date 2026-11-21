#!/usr/bin/env bash
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Produces the committed run records for {{slug}}.
#
#     labs/{{slug}}/records/make.sh            # every scenario
#     labs/{{slug}}/records/make.sh intro      # one of them
#     labs/{{slug}}/records/make.sh --verify   # determinism check
#     labs/{{slug}}/records/make.sh --out-dir DIR   # regenerate elsewhere
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
#
# A drawing lab records what is ON the sheet, so the drawing has to come from
# the scenario script and never from a hand: add a --eval line below that draws
# the figure you want measured, or put it in a scenario and name it here.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
# The lab itself, found from this script rather than as labs/$lab under the
# checkout: a lab made with `lab-new --dir` elsewhere has no checkout around
# it, and lab-check runs it from there (#535). The run works IN it, so every
# path clayrender sees stays relative - an absolute Git-bash path (/c/...)
# inside the --eval string means nothing to clayrender on Windows.
labdir="$(cd "$here/.." && pwd)"
lab="{{slug}}"
# $CLAYRENDER when it is set - lab-check passes the one it was given, so a
# build folder of another name is the one that renders (#535)
render="${CLAYRENDER:-$root/build/bin/clayrender}"
# how this script is spelled inside a record - repo-relative, so it reads the
# same on any machine
self="labs/$lab/records/make.sh"

SEED=42
STEPS=600           # 10 simulated seconds at 1/60 s, sampled every 0.05 s
SCENARIOS=(intro blank)

# Every scratch file of one run in a directory of its own: under fixed names
# two runs of one lab at once wrote into each other's --verify files (#535)
scratch="$(mktemp -d "${TMPDIR:-/tmp}/${lab}-records.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

[ -x "$render" ] || {
    echo "clayrender not found at $render - build it first" >&2
    echo "  cmake --build build --target clayrender" >&2
    exit 1
}

# $1 scenario, $2 destination (relative to the lab), $3 record id
run_one() {
    local scenario="$1" out="$2" id="$3"
    "$render" Sandbox.qml \
        --out "$scratch/${scenario}.png" --size 800x500 --frames 1 \
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

cd "$labdir"

# Where the records go. Committed location by default; --out-dir sends them
# somewhere else, which is how `tools/lab-check/lab-check` regenerates them and
# compares without ever writing into the tree it is checking. The record's
# `command` field stays the committed spelling either way - it says how to
# reproduce the record, not where this particular copy landed. A relative DIR
# is relative to the lab.
outdir="records"
if [ "${1:-}" = "--out-dir" ]; then
    [ -n "${2:-}" ] || { echo "--out-dir needs a directory" >&2; exit 1; }
    outdir="$2"
    mkdir -p "$outdir"
    shift 2
fi

if [ "${1:-}" = "--verify" ]; then
    # The determinism claim, as a command anyone can re-run: the same scenario
    # and seed twice, into two files, byte-compared.
    status=0
    for scenario in "${SCENARIOS[@]}"; do
        a="$scratch/${scenario}-a.labrec"
        b="$scratch/${scenario}-b.labrec"
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
    out="$outdir/$scenario-$SEED.labrec"
    run_one "$scenario" "$out" "$scenario-$SEED"
    echo "wrote $out ($(wc -c < "$out" | tr -d ' ') bytes)"
done
