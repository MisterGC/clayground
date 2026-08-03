// Edge rendering - absolute edgeColor, and thickness that means pixels
//
// Two changes shown side by side. Left column: edgeColorFactor can only
// darken the fill, so on a light surface the edges wash out; edgeColor names
// the colour outright. Right column: edgeThickness is now a count of pixels
// via fwidth, so it holds still when the view resizes, the camera pulls back
// or the surface turns away - resize this window and watch the lines.

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent

    // Passed down by the plugin sandbox; null when this scene runs on its own.
    property var cameraStore: parent ? parent.cameraStore : null

    // One knob drives every edge in the scene so the comparison stays honest.
    property real thickness: thicknessSlider.value

    environment: SceneEnvironment {
        clearColor: "#101820"
        backgroundMode: SceneEnvironment.Color
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.High
    }

    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 190, 300)
        eulerRotation.x: -28

        Component.onCompleted: {
            if (cameraStore && cameraStore.has("edgecolor_camPos"))
                position = JSON.parse(cameraStore.get("edgecolor_camPos"))
            if (cameraStore && cameraStore.has("edgecolor_camRot"))
                eulerRotation = JSON.parse(cameraStore.get("edgecolor_camRot"))
        }

        Component.onDestruction: {
            if (cameraStore) {
                cameraStore.set("edgecolor_camPos", JSON.stringify(position))
                cameraStore.set("edgecolor_camRot", JSON.stringify(eulerRotation))
            }
        }
    }

    WasdController {
        controlledObject: camera
        mouseEnabled: true
        keysEnabled: true
    }

    DirectionalLight {
        eulerRotation.x: -40
        eulerRotation.y: -60
        brightness: 1.0
    }

    // Fill from the opposite side - without it the away-facing box sides go
    // black and the edges on them cannot be judged at all.
    DirectionalLight {
        eulerRotation.x: -20
        eulerRotation.y: 130
        brightness: 0.5
    }

    // --- edgeColor: the same pale box, twice ------------------------------
    //
    // boxEdgeScale is the honest part of this demo: Box3D and VoxelMap both
    // call the knob edgeThickness and both feed it through fwidth, but they do
    // not yet produce the same width. VoxelMap draws a solid line of that many
    // pixels; Box3D smoothsteps its border over that distance in UV space, so
    // the visible line comes out several times thinner. One slider drives both
    // here, and the boxes take a factor so the pair can actually be compared.
    property real boxEdgeScale: 4.0

    // Only edgeColorFactor available: it scales the fill, so a light fill can
    // only ever produce light edges.
    Box3D {
        position: Qt.vector3d(-150, -36, 0)
        width: 70; height: 70; depth: 70
        color: "#e6d2f2"
        showEdges: true
        edgeThickness: view3D.thickness * view3D.boxEdgeScale
        edgeColorFactor: 0.4
    }

    // edgeColor names the colour outright and wins over the factor.
    Box3D {
        position: Qt.vector3d(-60, -36, 0)
        width: 70; height: 70; depth: 70
        color: "#e6d2f2"
        showEdges: true
        edgeThickness: view3D.thickness * view3D.boxEdgeScale
        edgeColor: "#2f3437"
    }

    // --- the same pair, on a voxel map ------------------------------------

    StaticVoxelMap {
        position: Qt.vector3d(60, -36, 0)
        voxelSize: 12
        voxelCountX: 5; voxelCountY: 5; voxelCountZ: 5
        showEdges: true
        edgeThickness: view3D.thickness
        edgeColorFactor: 0.4
        Component.onCompleted: fill([["box", [0, 0, 0, 5, 5, 5, "#e6d2f2"]]])
    }

    StaticVoxelMap {
        position: Qt.vector3d(150, -36, 0)
        voxelSize: 12
        voxelCountX: 5; voxelCountY: 5; voxelCountZ: 5
        showEdges: true
        edgeThickness: view3D.thickness
        edgeColor: "#2f3437"
        Component.onCompleted: fill([["box", [0, 0, 0, 5, 5, 5, "#e6d2f2"]]])
    }

    // --- the grazing floor: where the old thickness math fell apart -------
    //
    // Lines used to run several times wider near the camera than further out
    // and dissolve into moiré at the horizon, because the conversion ignored
    // both the real viewport and how far the surface turns away. They now hold
    // one width the whole way back.
    StaticVoxelMap {
        position: Qt.vector3d(0, -60, -260)
        voxelSize: 24
        voxelCountX: 30; voxelCountY: 1; voxelCountZ: 30
        showEdges: true
        edgeThickness: view3D.thickness
        edgeColor: "#5a4a6a"
        Component.onCompleted: fill([["box", [0, 0, 0, 30, 1, 30, "#e0dae8"]]])
    }

    // --- readout ----------------------------------------------------------

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 16
        width: 330
        height: content.implicitHeight + 24
        radius: 8
        color: "#cc16213e"
        border.color: "#0f9d9a"
        border.width: 2

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: "edgeThickness: " + view3D.thickness.toFixed(2) + " px"
                color: "#eaeaea"
                font.family: Qt.platform.os === "osx" ? "Menlo" : "monospace"
                font.pixelSize: 13
                font.bold: true
            }

            Slider {
                id: thicknessSlider
                width: parent.width - 8
                from: 0.0
                to: 6.0
                value: 1.5
            }

            Text {
                width: parent.width - 8
                wrapMode: Text.WordWrap
                text: "Left of each pair: edgeColorFactor 0.4 - the fill, " +
                      "darkened, which a light surface cannot make dark. " +
                      "Right: edgeColor \"#2f3437\" - an actual colour.\n\n" +
                      "Resize the window: the line width in pixels does not " +
                      "move. Below 1 px lines start dropping out, which is " +
                      "why 1.0 is the VoxelMap default.\n\nKnown gap: the " +
                      "boxes multiply this value by " + view3D.boxEdgeScale +
                      " to match the voxel maps. Box3D and VoxelMap share " +
                      "the property name but not yet the resulting width."
                color: "#8a8a8a"
                font.family: Qt.platform.os === "osx" ? "Menlo" : "monospace"
                font.pixelSize: 11
                lineHeight: 1.3
            }
        }
    }
}
