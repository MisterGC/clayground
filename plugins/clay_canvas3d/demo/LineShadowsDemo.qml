// LineBatch3D shadow casting - what it takes, and why it is restricted.
//
// Three batches of identical ribbons float at the same height over a
// shadow-receiving ground, with a real mesh as the control. Only the flat,
// world-width batch that opts in drops a shadow; the other two are the two
// ways of not qualifying.

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

Item {
    id: rootItem
    anchors.fill: parent

    // Verification helper: which batch is actually casting.
    function stats() {
        return { optedIn: casting.castsShadows,
                 offByDefault: offBatch.castsShadows,
                 billboardIgnored: billboard.castsShadows }
    }

    View3D {
        id: view
        anchors.fill: parent
        environment: SceneEnvironment {
            clearColor: "#e8e4dd"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 165, 205)
            eulerRotation.x: -40
        }

        WasdController { controlledObject: camera; speed: 1.2 }

        DirectionalLight {
            eulerRotation.x: -50
            eulerRotation.y: -25
            castsShadow: true
            shadowFactor: 85
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
        }

        Model {
            source: "#Rectangle"
            scale: Qt.vector3d(7, 7, 1)
            eulerRotation.x: -90
            receivesShadows: true
            castsShadows: false
            materials: PrincipledMaterial { baseColor: "#f2eee7" }
        }

        // The control: ordinary mesh geometry has always cast.
        Model {
            source: "#Cube"
            position: Qt.vector3d(-130, 12, 0)
            scale: Qt.vector3d(0.2, 0.06, 1.4)
            castsShadows: true
            materials: PrincipledMaterial { baseColor: "#0f9d9a" }
        }

        function ribbons(x0, y, color) {
            const out = []
            for (let i = 0; i < 5; ++i)
                out.push({ points: [Qt.vector3d(x0, y, -55 + i * 26),
                                    Qt.vector3d(x0 + 75, y, -55 + i * 26)],
                           color: color, width: 10, styleId: 0 })
            return out
        }

        // Qualifies: world width, flat, opted in.
        LineBatch3D {
            id: casting
            viewportSize: Qt.vector2d(view.width, view.height)
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Flat
            castsShadows: true
            lines: view.ribbons(-90, 12, "#ff3366")
        }

        // Qualifies but never asked: the default, and the right choice for
        // anything that should read as paint on the surface.
        LineBatch3D {
            id: offBatch
            viewportSize: Qt.vector2d(view.width, view.height)
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Flat
            lines: view.ribbons(0, 12, "#0189f3")
        }

        // Cannot qualify: a billboarded ribbon turns to face whatever is
        // looking, and in the shadow pass that is the light - so its shadow
        // would be of a differently-turned ribbon. Warns once and stays off.
        LineBatch3D {
            id: billboard
            viewportSize: Qt.vector2d(view.width, view.height)
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Billboard
            castsShadows: true
            lines: view.ribbons(90, 12, "#ffd93d")
        }
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; margins: 12 }
        width: legend.implicitWidth + 24
        height: legend.implicitHeight + 20
        color: "#f2f0ebe6"
        border.color: "#cdc8bf"
        radius: 6

        Column {
            id: legend
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: "LineBatch3D shadows"
                color: "#2f3437"
                font.pixelSize: 15
                font.bold: true
            }
            Text {
                text: "<font color='#ff3366'>pink</font>  World + Flat, castsShadows - casts"
                    + "<br><font color='#0189f3'>blue</font>  World + Flat, default off - no shadow"
                    + "<br><font color='#b8860b'>gold</font>  Billboard - ignored, warns once"
                    + "<br><font color='#0f9d9a'>teal</font>  mesh control"
                color: "#403a30"
                font.pixelSize: 12
                lineHeight: 1.3
                textFormat: Text.RichText
            }
        }
    }
}
