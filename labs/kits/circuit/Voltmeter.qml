// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

/*!
    \qmltype Voltmeter
    \inqmlmodule Clayground.Lab
    \inherits HandheldInstrument
    \brief Touch a part and read the volts across it.

    The kit's own instrument, and the proof that the handheld contract carries:
    it is one file that says what a click contributes (\c "object"), how many
    (one), and what the reading means. There is no gesture code in it, no
    camera code, and nothing was added to the input layer to make it work - the
    same click that gives the tape measure a place gives this a thing, because
    \c {OrbitInput3D::picked} reports both.

    A lab gets it by declaring it inside the belt:

    \qml
    InstrumentBelt {
        pointer: nav
        Voltmeter {}
    }
    \endqml

    Pinning it keeps reading: unlike a tape measure between two fixed points, a
    part's voltage changes when the circuit does, so \l sampler closes over the
    part itself. That is what makes a pinned probe worth having - it is an
    instrument now, sampled on the clock grid and carried by the run record.

    \note NOT ON A BELT YET, and not for want of a contract. Everything above
    is written and unit-tested against object picks; what is missing is the
    pick itself. In electronics-101 \c {View3D.pick} reports a hit on
    \l LabStage3D's ground and on nothing else - not on the parts, not on a
    \c pickable \c Model added over a part, not even on one created at that
    exact world position at runtime. Until that is understood, wiring this into
    the lab would put a chip on the belt whose click does nothing, which is
    worse than not offering it.

    \note It also reads the voltage \e across a part rather than between two
    arbitrary points on the board. Probing two points needs the solver's node
    potentials, which \c circuit.js computes but does not return; exposing them
    is the step after the picking one.

    \sa HandheldInstrument, InstrumentBelt, CircuitElement3D
*/
HandheldInstrument {
    id: root

    name: "volts"
    label: LabLang.t("hand.volts")
    glyph: "⚡"
    pickKind: "object"
    maxPicks: 1
    unit: "V"
    tone: LabTheme.highlight

    /*! \qmlproperty var Voltmeter::part \readonly \brief The part being probed, or null. */
    readonly property var part: count > 0 ? _partOf(picks[0]) : null

    value: part ? Math.abs(part.simV) : 0
    valueText: part ? LabLang.qty(value, unit) : ""

    // The pick lands on whichever model the ray hit - a lead, a cap, the pick
    // volume - so the part is found by walking up from it. Duck-typed on the
    // reading rather than on the type name: what makes something probeable is
    // that it HAS a voltage across it.
    function _partOf(hit) {
        var n = hit
        for (var i = 0; i < 12 && n; ++i) {
            if (n.simV !== undefined) return n
            n = n.parent
        }
        return null
    }

    // A probe left clipped on goes on reading, which is the whole difference
    // between a measurement and an instrument.
    function sampler(snapshot) {
        const p = snapshot.length > 0 ? _partOf(snapshot[0]) : null
        return () => (p ? Math.abs(p.simV) : 0)
    }

    function info() {
        return { name: name, kind: pickKind, count: count, unit: unit,
                 value: value, text: valueText,
                 part: part ? (part.type + " " + part.value) : null,
                 pinned: pinnedReadings.map(p => p.name) }
    }

    // --- the reading --------------------------------------------------------
    // Over the part it is clipped to, in screen space for the same reason the
    // tape measure is: a reading that disappears inside the board is useless.
    Item {
        readonly property var scr: {
            const v = root.view
            const p = root.part
            if (!v || !v.camera || !p) return null
            const cam = v.camera
            void cam.scenePosition
            void cam.sceneRotation
            const w = p.scenePosition
            const s = v.mapFrom3DScene(Qt.vector3d(w.x, w.y + 4, w.z))
            return s.z > 0 ? s : null
        }
        visible: scr !== null
        x: scr ? scr.x : 0
        y: scr ? scr.y : 0

        Rectangle {
            x: -width / 2
            y: -height - LabTheme.spaceM
            width: _t.implicitWidth + 2 * LabTheme.spaceL
            height: _t.implicitHeight + LabTheme.spaceM
            radius: LabTheme.radius
            color: root.tone
            border.color: root.tone
            border.width: LabTheme.borderWidth
            Text {
                id: _t
                anchors.centerIn: parent
                text: root.valueText
                color: LabTheme.inkOn(root.tone)
                font.pixelSize: LabTheme.fontLabel
                font.bold: true
                font.family: LabTheme.monoFont
            }
        }
    }
}
