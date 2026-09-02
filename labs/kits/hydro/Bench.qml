// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Bench - the kit's own visual test. Every part type laid out on the lab's
// board in a row, wired to nothing, with the solver's numbers faked to a
// plausible working point so the meters have needles and the wheel a speed.
// It is what you look at after touching HydroElement3D.
//
//   clayrender labs/kits/hydro/Bench.qml --out /tmp/hydro-bench.png \
//       --size 1400x900 --settle
//
// --eval targets: shut(), open(), fault("short"|"over"|"none"), spin(deg).

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "strings.js" as HydroStrings

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent

    readonly property real cell: 5
    // the palette's order plus the T-piece, which is never placed by hand
    readonly property var types: ["pump", "valve", "pipe", "wheel",
                                  "flowmeter", "gauge", "junction"]

    property bool valveOpen: true
    property string fault: "none"
    property real phase: 0

    /*! Shut every valve on the bench. */
    function shut() { root.valveOpen = false }
    /*! Open them again. */
    function open() { root.valveOpen = true }
    /*! Put the pump into "none", "short" or "over". */
    function fault_(kind) { root.fault = kind }
    /*! Turn the water wheel to a fixed angle, in degrees. */
    function spin(deg) { root.phase = deg }
    /*! Move the camera in on one part, by its name in `types`. */
    function closeUp(name, dist) {
        const i = root.types.indexOf(name)
        if (i < 0) return
        rig.pivot = Qt.vector3d((i - (root.types.length - 1) / 2)
                                * root.cell * 2.4, 2, 0)
        rig.distance = dist === undefined ? 18 : dist
    }

    Component.onCompleted: LabLang.register(HydroStrings.dict)

    View3D {
        id: view
        anchors.fill: parent
        camera: rig.camera
        environment: stage.environment

        LabStage3D {
            id: stage
            cellSize: root.cell
            majorEvery: 4
            workExtent: Qt.vector2d(90, 40)
            shadowMapFar: 200
        }

        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, 2, 0)
            yaw: 0
            pitch: 30
            distance: 52
        }

        Repeater3D {
            model: root.types
            HydroElement3D {
                id: part
                required property int index
                required property var modelData
                type: part.modelData
                x: (part.index - (root.types.length - 1) / 2) * root.cell * 2.4
                value: part.modelData === "pump" ? 40 : 8
                switchOn: root.valveOpen
                // a plausible working point rather than a solved one: this is
                // a picture of the parts, not of a circuit
                simQ: 1.18
                simDp: part.modelData === "gauge" ? 28.2 : 9.4
                simPower: 33.2
                turning: true
                speed: 70
                phase: root.phase
                shorted: root.fault === "short" && part.modelData === "pump"
                overloaded: root.fault === "over" && part.modelData === "pump"
                selected: part.modelData === "wheel"
                hovered: part.modelData === "pipe"
                actuatorHovered: part.modelData === "valve"
                wiringTerminal: part.modelData === "flowmeter" ? 1 : -1
            }
        }
    }

    // The palette symbols under the parts they stand for, so the schematic
    // glyph and the body can be judged against each other in one picture.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.spaceXl
        spacing: LabTheme.spaceXl
        Repeater {
            model: root.types
            Column {
                id: chip
                required property var modelData
                spacing: LabTheme.spaceXs
                SymbolIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: LabTheme.px(46); height: LabTheme.px(32)
                    type: chip.modelData
                    on: root.valveOpen
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: LabLang.t("part." + chip.modelData)
                    color: LabTheme.inkSoft
                    font.pixelSize: LabTheme.fontSmall
                    font.family: LabTheme.monoFont
                }
            }
        }
    }
}
