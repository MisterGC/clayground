// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ScreenFx2d costs nothing at rest: which pass runs follows from the knobs,
// and flash/pulse hand the world back when they have faded.

import QtQuick
import QtTest
import Clayground.World

Item {
    id: root
    width: 400; height: 300

    ClayWorld2d {
        id: world
        components: new Map()
        anchors.fill: parent

        ScreenFx2d { id: fx; world: world }
    }

    TestCase {
        name: "ScreenFx2d"
        when: windowShown

        function test_restIsFree() {
            compare(fx.sourceItem, world.canvas);
            verify(!fx.gradeActive);
            verify(!fx.overlayActive);
        }

        function test_gradeKnobs() {
            fx.saturation = 0.5;
            verify(fx.gradeActive);
            verify(!fx.overlayActive);
            fx.saturation = 1;
            verify(!fx.gradeActive);
            fx.tint = "#ffe0c0";
            verify(fx.gradeActive);
            fx.tint = "#ffffff";
            verify(!fx.gradeActive);
            fx.colorLevels = 6;
            verify(fx.gradeActive);
            fx.colorLevels = 0;
        }

        function test_overlayKnobs() {
            fx.vignette = 0.5;
            verify(fx.overlayActive);
            verify(!fx.gradeActive);
            fx.vignette = 0;
            verify(!fx.overlayActive);
        }

        function test_lowHealthUsesBoth() {
            fx.lowHealth = 0.5;
            verify(fx.gradeActive);
            verify(fx.overlayActive);
            fx.lowHealth = 0;
            verify(!fx.gradeActive);
            verify(!fx.overlayActive);
        }

        function test_flashFades() {
            fx.flash("red", 100, 0.9);
            verify(fx.overlayActive);
            compare(fx.clayInspect().flashColor, "#ff0000");
            tryCompare(fx, "overlayActive", false, 2000);
        }

        function test_weakerFlashDoesNotCutAStrongOne() {
            fx.flash("white", 400, 0.9);
            fx.flash("red", 50, 0.1);
            compare(fx.clayInspect().flashColor, "#ffffff");
            tryCompare(fx, "overlayActive", false, 2000);
        }

        function test_pulseFades() {
            fx.pulse(0.8, 100);
            verify(fx.gradeActive);
            tryCompare(fx, "gradeActive", false, 2000);
        }
    }
}
