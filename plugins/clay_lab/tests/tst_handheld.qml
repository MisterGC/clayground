// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The handheld contract itself: what a pick contributes, how a subject fills
// up and starts over, and what pinning leaves behind.
//
// The last one is the case worth having. `pin()` is the only path by which a
// measurement someone took by hand becomes a number in a run record, and a
// record is what a paper cites - so "a pinned reading is sampled like any
// other probe, under the name it was given" is a claim about the science, not
// about the UI. It is checked here against Lab's own probe registry rather
// than against anything the overlay draws.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50

    // One of each kind, so the three ways a click can mean something are all
    // exercised against the same base.
    HandheldInstrument {
        id: places
        name: "dist"; unit: "m"; pickKind: "point"
        value: count
    }

    HandheldInstrument {
        id: things
        name: "volts"; unit: "V"; pickKind: "object"; maxPicks: 2
        value: count * 10
    }

    HandheldInstrument {
        id: moments
        name: "time"; unit: "s"; pickKind: "moment"; maxPicks: 2
    }

    // Something to pick: any object will do - what makes it probeable is the
    // instrument's business, not the belt's.
    QtObject { id: aPart }
    QtObject { id: anotherPart }

    SimClock { id: clock; seed: 7 }

    TestCase {
        name: "HandheldInstrument"

        function init() {
            places.clear(); things.clear(); moments.clear()
            places.held = false; things.held = false; moments.held = false
            clock.reset()
        }

        function pickAt(x, z) { return { point: Qt.vector3d(x, 0, z), object: null } }
        function pickOn(o) { return { point: Qt.vector3d(1, 0, 1), object: o } }

        // --- what a pick contributes -----------------------------------------

        function test_a_place_instrument_keeps_the_point() {
            places.add(pickAt(3, 4))
            compare(places.count, 1)
            compare(places.picks[0].x, 3)
            compare(places.picks[0].z, 4)
        }

        function test_a_place_instrument_ignores_a_pick_with_no_place() {
            places.add({ point: null, object: aPart })
            compare(places.count, 0, "an object is not a place")
        }

        function test_a_thing_instrument_keeps_the_object() {
            things.add(pickOn(aPart))
            compare(things.count, 1)
            compare(things.picks[0], aPart, "the object itself, not its position")
        }

        function test_a_thing_instrument_ignores_a_pick_with_no_thing() {
            things.add(pickAt(3, 4))
            compare(things.count, 0, "bare ground is not a thing")
        }

        // The stopwatch's case, and the one that shows the contract is about
        // BINDING rather than pointing: the click's position is not consulted
        // at all, so no gesture, mode or input path had to be added for it.
        function test_a_moment_instrument_stamps_the_sim_clock() {
            clock._advance(2.5)
            moments.add(null)
            compare(moments.count, 1)
            fuzzyCompare(moments.picks[0], 2.5, 1e-9)
            clock._advance(1.5)
            moments.add(pickAt(999, 999))
            fuzzyCompare(moments.picks[1], 4.0, 1e-9, "where the cursor was is irrelevant")
        }

        // --- filling up -------------------------------------------------------

        function test_a_full_instrument_starts_over_rather_than_refusing() {
            things.add(pickOn(aPart))
            things.add(pickOn(anotherPart))
            verify(things.full)
            things.add(pickOn(aPart))
            compare(things.count, 1, "the third click began a new subject")
            compare(things.picks[0], aPart)
        }

        function test_undo_and_clear() {
            places.add(pickAt(0, 0))
            places.add(pickAt(1, 1))
            places.undo()
            compare(places.count, 1)
            places.clear()
            verify(places.empty)
            places.undo()
            compare(places.count, 0, "an empty subject stays empty")
        }

        // --- putting it down --------------------------------------------------

        function test_putting_it_down_ends_the_measurement() {
            places.held = true
            places.add(pickAt(0, 0))
            places.held = false
            verify(places.empty)
        }

        // --- pinning ----------------------------------------------------------

        function test_pinning_registers_a_probe_under_the_name_it_was_given() {
            places.held = true
            places.add(pickAt(0, 0))
            places.add(pickAt(3, 4))
            verify(places.pinnable)
            verify(places.pin("gap_ab"), "it pinned")

            const p = Lab.probe("gap_ab")
            verify(p !== null && p !== undefined, "a probe exists under that name")
            compare(p.unit, "m", "carrying the instrument's unit")

            // and it is a probe like any other: sampled on the clock's grid,
            // which is what puts it in the run record
            clock._advance(0.3)
            verify(p.samples.length > 0, "it is being sampled: " + p.samples.length)
            fuzzyCompare(p.value, 2, 1e-9, "with the reading it was pinned at")
        }

        function test_pinning_ends_the_measurement_it_kept() {
            places.held = true
            places.add(pickAt(0, 0))
            places.add(pickAt(1, 0))
            places.pin("kept_1")
            verify(places.empty, "what was a question is an instrument now")
            // the last one, not the only one: pinned readings accumulate on
            // the instrument by design - that is what "it is mounted now"
            // means - and they outlive the measurement that produced them
            const kept = places.pinnedReadings
            compare(kept[kept.length - 1].name, "kept_1")
        }

        function test_nothing_measured_pins_nothing() {
            verify(!places.pinnable)
            verify(!places.pin("nope"))
            compare(Lab.probe("nope"), null, "and no probe was left behind")
        }

        // The name is asked for, but it is never empty: an unnamed column in a
        // record is a citation nobody can follow.
        function test_an_unnamed_pin_falls_back_to_the_suggestion() {
            places.held = true
            places.add(pickAt(0, 0))
            places.add(pickAt(1, 0))
            const suggested = places.suggestedName()
            compare(suggested, "dist_1", "numbered from the instrument's name")
            places.pin("")
            verify(Lab.probe(suggested) !== null, "pinned under the suggestion")
            places.add(pickAt(0, 0))
            places.add(pickAt(2, 0))
            compare(places.suggestedName(), "dist_2", "and the next one moves on")
        }
    }
}
