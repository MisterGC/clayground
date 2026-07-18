// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Picture-in-picture lidar inspector. A self-contained second View3D shows the
// selected car's point cloud in the CAR-LOCAL frame: a dark scanner stage with
// a subtle ring/spoke floor, a small car glyph at the origin (heading = +Z),
// and the live point cloud rendered as screen-space dots by ONE LineBatch3D
// (zero-length segments with round caps). The parent (CityView3D) owns the
// scan simulation and feeds fresh point buffers via updateCloud().

import QtQuick
import QtQuick.Controls
import QtQuick3D
import Clayground.Canvas3D

Item {
    id: panel

    // ---- inputs from the controller ----
    property real carW: 1.7
    property real carL: 3.9
    property real carH: 1.4
    property int carLabel: 0
    property string statsText: ""

    signal closeRequested()

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                                       Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // The point cloud uses a FIXED line layout: initCloud() establishes all
    // channels*azSteps lines once (zero-length segments = screen-space dots,
    // colors baked per elevation channel). patchCloud() then rewrites only the
    // endpoints each frame via LineBatch3D's no-rebuild fast path - misses park
    // far below the frustum and cull away, so nothing needs re-adding/removing.
    function initCloud(positions, starts, colors, widths) {
        cloud.setBulk(positions, starts, colors, widths)
    }
    function patchCloud(positions) {
        cloud.updateEndpointsBulk(positions)
    }
    function clearCloud() {
        cloud.setBulk(new Float32Array(0).buffer, new Uint32Array(1).buffer,
                      new Uint8Array(0).buffer, new Float32Array(0).buffer)
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Qt.rgba(0.02, 0.03, 0.05, 0.95)
        border.color: "#0f9d9a"
        border.width: 1

        // ---- header ----
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 26

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "LIDAR // car #" + panel.carLabel
                color: "#00d9ff"
                font.family: panel.monoFont
                font.pixelSize: 12
                font.bold: true
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 18; radius: 4
                color: closeArea.containsMouse ? "#ff3366" : Qt.rgba(0.12, 0.13, 0.18, 0.9)
                border.color: "#ff3366"; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "x"
                    color: closeArea.containsMouse ? "#04121a" : "#ff6688"
                    font.family: panel.monoFont
                    font.pixelSize: 12
                    font.bold: true
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: panel.closeRequested()
                }
            }
        }

        // ---- inner 3D scanner stage ----
        Rectangle {
            id: stageFrame
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 6
            radius: 6
            clip: true
            color: "#05060a"

            View3D {
                id: pipView
                anchors.fill: parent

                environment: SceneEnvironment {
                    backgroundMode: SceneEnvironment.Color
                    clearColor: "#05060a"
                    antialiasingMode: SceneEnvironment.MSAA
                    antialiasingQuality: SceneEnvironment.Medium
                }

                PerspectiveCamera {
                    id: pipCam
                    position: Qt.vector3d(0, 36, -64)
                    eulerRotation: Qt.vector3d(-20, 180, 0)
                    fieldOfView: 55
                    clipNear: 1
                    clipFar: 4000
                }

                DirectionalLight {
                    eulerRotation.x: -40
                    brightness: 0.7
                    ambientColor: Qt.rgba(0.15, 0.16, 0.22, 1.0)
                }

                // ---- ring / spoke floor (built once) ----
                LineBatch3D {
                    id: floor
                    widthUnits: LineBatch3D.Pixel
                    viewportSize: Qt.vector2d(pipView.width, pipView.height)
                    depthBias: 1
                }

                // ---- car glyph at the origin (heading = +Z) ----
                Model {
                    source: "#Cube"
                    position: Qt.vector3d(0, panel.carH * 0.5, 0)
                    scale: Qt.vector3d(panel.carW / 100, panel.carH / 100, panel.carL / 100)
                    opacity: 0.55
                    materials: PrincipledMaterial {
                        lighting: PrincipledMaterial.NoLighting
                        baseColor: "#ffd93d"
                    }
                }
                // forward nose marker (cyan), shows which way the car faces
                Model {
                    source: "#Cube"
                    position: Qt.vector3d(0, panel.carH * 0.5, panel.carL * 0.55)
                    scale: Qt.vector3d(panel.carW * 0.3 / 100, panel.carH * 0.3 / 100, panel.carL * 0.12 / 100)
                    materials: PrincipledMaterial {
                        lighting: PrincipledMaterial.NoLighting
                        baseColor: "#00d9ff"
                    }
                }

                // ---- the point cloud: one instanced draw call ----
                LineBatch3D {
                    id: cloud
                    widthUnits: LineBatch3D.Pixel
                    viewportSize: Qt.vector2d(pipView.width, pipView.height)
                    depthBias: 0
                }
            }

            // ---- stats overlay ----
            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 6
                text: panel.statsText
                color: "#8a8a9a"
                font.family: panel.monoFont
                font.pixelSize: 10
            }
        }
    }

    Component.onCompleted: floor.lines = _buildFloor()

    // Concentric rings + radial spokes on the ground plane (y just above 0).
    function _buildFloor() {
        var arr = []
        var radii = [15, 30, 45, 60]
        var segs = 48
        for (var r = 0; r < radii.length; ++r) {
            var pts = []
            for (var i = 0; i <= segs; ++i) {
                var a = (i / segs) * Math.PI * 2
                pts.push(Qt.vector3d(Math.cos(a) * radii[r], 0.05, Math.sin(a) * radii[r]))
            }
            arr.push({ points: pts, color: "#0f6b66", width: 1.0, styleId: 0 })
        }
        var spokes = 8, maxR = radii[radii.length - 1]
        for (var s = 0; s < spokes; ++s) {
            var sa = (s / spokes) * Math.PI * 2
            arr.push({ points: [Qt.vector3d(0, 0.05, 0),
                                 Qt.vector3d(Math.cos(sa) * maxR, 0.05, Math.sin(sa) * maxR)],
                       color: "#0a4f4b", width: 1.0, styleId: 0 })
        }
        return arr
    }
}
