// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Parametric 3D characters with animation, gait and patrol
// @tags 3D, Character, Animation
// @category Plugin Demos

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.GameController

Item {
    id: root
    anchors.fill: parent
    focus: true

    // Camera orbit state
    property real cameraYaw: 180
    property real cameraPitch: 25
    property real cameraDistance: 30
    property bool isDragging: false
    property point lastMousePos: Qt.point(0, 0)

    // All characters for editor
    readonly property var allCharacters: [character, npcThinker, npcEater, npcHero, npcChild, npcStylized]

    // Forward keys to game controller for WASD movement
    Keys.forwardTo: [gameController]

    Keys.onPressed: (event) => {
        // Camera rotation with Q/E
        if (event.key === Qt.Key_Q) {
            cameraYaw -= 5
            event.accepted = true
        } else if (event.key === Qt.Key_E) {
            cameraYaw += 5
            event.accepted = true
        }
        // Camera pitch with R/F
        else if (event.key === Qt.Key_R) {
            cameraPitch = Math.min(85, cameraPitch + 5)
            event.accepted = true
        } else if (event.key === Qt.Key_F) {
            cameraPitch = Math.max(-30, cameraPitch - 5)
            event.accepted = true
        }
        // Camera distance with T/G
        else if (event.key === Qt.Key_T) {
            cameraDistance = Math.max(10, cameraDistance - 5)
            event.accepted = true
        } else if (event.key === Qt.Key_G) {
            cameraDistance = Math.min(100, cameraDistance + 5)
            event.accepted = true
        }
        // Gestures on the plain character standing next to the player
        else if (event.key === Qt.Key_P) {
            gesturer.pointAt(gestureMarker.scenePosition)
            event.accepted = true
        } else if (event.key === Qt.Key_O) {
            gesturer.thumbsUp()
            event.accepted = true
        } else if (event.key === Qt.Key_I) {
            gesturer.gesticulate()
            event.accepted = true
        } else if (event.key === Qt.Key_X) {
            gesturer.stopGesture()
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            // Address the reader while the arm keeps holding the point
            gesturer.lookAt(charCamera.scenePosition)
            event.accepted = true
        } else if (event.key === Qt.Key_K) {
            gesturer.lookAt(null)
            event.accepted = true
        } else if (event.key === Qt.Key_Y) {
            gesturer.turnTo(gestureMarker.scenePosition)
            event.accepted = true
        } else if (event.key === Qt.Key_H) {
            gesturer.detail = gesturer.detailedHands ? Character.Detail.Low
                                                     : Character.Detail.High
            event.accepted = true
        } else if (event.key === Qt.Key_N) {
            // A gesture is Idle-only: this drops it and starts a walk cycle
            gesturer.activity = gesturer.activity === Character.Activity.Idle
                              ? Character.Activity.Walking
                              : Character.Activity.Idle
            event.accepted = true
        } else if (event.key === Qt.Key_1) {
            gesturer.setEmotion("happy")
            event.accepted = true
        } else if (event.key === Qt.Key_2) {
            gesturer.setEmotion("sad")
            event.accepted = true
        } else if (event.key === Qt.Key_3) {
            gesturer.setEmotion("angry")
            event.accepted = true
        } else if (event.key === Qt.Key_0) {
            gesturer.setEmotion("")
            event.accepted = true
        }
        // Let other keys pass through to forwardTo targets
    }
    
    View3D {
        id: view3d
        anchors.fill: parent
        
        environment: SceneEnvironment {
            clearColor: "#f2eee7"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            
            // Enable toon shading
            tonemapMode: SceneEnvironment.TonemapModeNone
        }

        // The lab stage's rig (plugins/clay_lab/LabStage3D.qml): a key that
        // casts, a side fill and a low camera-side fill, values from the
        // light palette. Five lights used to be here, which is one over
        // Quick3D's cap of four and flattened everything into the same tone.
        DirectionalLight {
            id: mainLight
            eulerRotation.x: -36
            eulerRotation.y: -26
            brightness: 0.9
            ambientColor: "#737380"
            castsShadow: true
            shadowFactor: 58
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
            shadowMapFar: 250
            csmNumSplits: 2
            shadowBias: 3
            softShadowQuality: Light.PCF4
            pcfFactor: 1
        }
        DirectionalLight {
            eulerRotation.x: -60
            eulerRotation.y: 142
            brightness: 0.35
        }
        DirectionalLight {
            eulerRotation.x: -24
            eulerRotation.y: 19
            brightness: 0.27
        }

        // Character camera that follows the editor's target (or player when nothing selected)
        CharacterCamera {
            id: charCamera
            character: charEditor.editTarget ?? character
            orbitDistance: root.cameraDistance
            orbitPitch: root.cameraPitch
            orbitYawOffset: root.cameraYaw

            // A soft fill that travels with the camera, so no orbit angle
            // looks at an unlit side: the key above is fixed (its shadows
            // must not swing with the view) and a fixed rig always has a
            // dark quarter. Aimed a little below the view line so a face
            // read from above still has its lit and its shaded planes.
            DirectionalLight {
                eulerRotation.x: -12
                brightness: 0.45
                castsShadow: false
            }
        }

        // Mouse area for camera drag rotation
        MouseArea {
            id: cameraMouseArea
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onPressed: (mouse) => {
                root.isDragging = true
                root.lastMousePos = Qt.point(mouse.x, mouse.y)
            }
            onReleased: {
                root.isDragging = false
            }
            onPositionChanged: (mouse) => {
                if (root.isDragging) {
                    var dx = mouse.x - root.lastMousePos.x
                    var dy = mouse.y - root.lastMousePos.y
                    root.cameraYaw += dx * 0.5
                    root.cameraPitch = Math.max(-30, Math.min(85, root.cameraPitch + dy * 0.3))
                    root.lastMousePos = Qt.point(mouse.x, mouse.y)
                }
            }
            onWheel: (wheel) => {
                root.cameraDistance = Math.max(10, Math.min(100, root.cameraDistance - wheel.angleDelta.y * 0.05))
            }
        }
        
        // Ground plane using VoxelMap for better toon shading
        // Bottom-aligned: surface = y + (voxelCountY * voxelSize) = -4 + (2 * 2.0) = 0
        StaticVoxelMap {
            id: ground
            visible: true
            y: -4
            voxelCountX: 100
            voxelCountY: 2
            voxelCountZ: 100
            voxelSize: 2.0  // Large voxels for ground
            spacing: 0.0

            showEdges: true
            edgeColorFactor: 0.6
            edgeThickness: 0.02

            Component.onCompleted: {
                // Fill with a simple green ground
                fill([{
                    box: {
                        pos: Qt.vector3d(0, 0, 0),
                        width: 100,
                        height: 2,
                        depth: 100,
                        colors: [
                            { color: "#5cb85c", weight: 0.6 },  // Main green
                            { color: "#4cae4c", weight: 0.3 },  // Darker green
                            { color: "#6ec06e", weight: 0.1 }   // Lighter green
                        ],
                        noise: 0.2  // Add some variation
                    }
                }]);
            }
        }
        
        // Main controllable character using ParametricCharacter
        ParametricCharacter {
            id: character
            name: "Player"
            roundness: 0.15
            position: Qt.vector3d(0, 0, 0)

            // Body parameters
            bodyHeight: 10.0
            realism: 0.3
            maturity: 0.5
            femininity: 0.4
            mass: 0.5
            muscle: 0.6

            // Face parameters
            faceShape: 0.5
            eyes: 1.1
            hair: 0.8

            // Colors
            skin: "#fdbcb4"
            hairTone: "#8b4513"
            topClothing: "#4169e1"
            bottomClothing: "#2c3e50"

            activity: Character.Idle
        }

        // Showcase: different character archetypes with patrol behavior
        // Thin Thinker
        ParametricCharacter {
            id: npcThinker
            position: Qt.vector3d(-25, 0, -30)
            name: "Thinker"
            roundness: 0.15
            bodyHeight: 9.0
            realism: 0.6
            maturity: 0.7
            femininity: 0.5
            mass: 0.2
            muscle: 0.2
            faceShape: 0.7
            eyes: 1.3
            hair: 0.3
            skin: "#e8beac"
            hairTone: "#3d3d3d"
            topClothing: "#5d4e37"
            bottomClothing: "#3d3d3d"
            // Explicit factors: a slow, head-down walk with quiet arms.
            gait: Gait { tempo: 0.85; headPitch: 10; armSwing: 0.7 }
        }
        PatrolController {
            character: npcThinker
            enabled: charEditor.selectedCharacter !== npcThinker
            minX: -80; maxX: 80
            minZ: -80; maxZ: 80
        }

        // Big Eater
        ParametricCharacter {
            id: npcEater
            position: Qt.vector3d(-12, 0, -30)
            name: "Eater"
            roundness: 0.15
            bodyHeight: 10.0
            realism: 0.2
            maturity: 0.5
            femininity: 0.4
            mass: 0.9
            muscle: 0.2
            faceShape: 0.2
            chinForm: 0.3
            eyes: 1.0
            hair: 0.5
            skin: "#fdbcb4"
            hairTone: "#8b4513"
            topClothing: "#e74c3c"
            bottomClothing: "#8b4513"
        }
        PatrolController {
            character: npcEater
            enabled: charEditor.selectedCharacter !== npcEater
            minX: -80; maxX: 80
            minZ: -80; maxZ: 80
        }

        // Athletic Hero
        ParametricCharacter {
            id: npcHero
            position: Qt.vector3d(0, 0, -30)
            name: "Hero"
            roundness: 0.15
            bodyHeight: 11.0
            realism: 0.3
            maturity: 0.5
            femininity: 0.2
            mass: 0.4
            muscle: 0.9
            faceShape: 0.6
            chinForm: 0.7
            eyes: 0.9
            hair: 0.6
            skin: "#d4a574"
            hairTone: "#1a1a1a"
            topClothing: "#3498db"
            bottomClothing: "#2c3e50"
            // A preset by name; the athletic build (muscle 0.9) composes on top.
            gait: Gait { preset: "proud" }
        }
        PatrolController {
            character: npcHero
            enabled: charEditor.selectedCharacter !== npcHero
            minX: -80; maxX: 80
            minZ: -80; maxZ: 80
        }

        // Cartoon Child
        ParametricCharacter {
            id: npcChild
            position: Qt.vector3d(12, 0, -30)
            name: "Child"
            roundness: 0.15
            bodyHeight: 6.0
            realism: 0.0
            maturity: 0.0
            femininity: 0.5
            mass: 0.5
            muscle: 0.3
            faceShape: 0.2
            eyes: 1.5
            hair: 1.0
            skin: "#ffe0bd"
            hairTone: "#ff6b35"
            topClothing: "#9b59b6"
            bottomClothing: "#3498db"
        }
        PatrolController {
            character: npcChild
            enabled: charEditor.selectedCharacter !== npcChild
            minX: -80; maxX: 80
            minZ: -80; maxZ: 80
        }

        // Stylized Woman
        ParametricCharacter {
            id: npcStylized
            position: Qt.vector3d(25, 0, -30)
            name: "Stylized"
            roundness: 0.15
            bodyHeight: 9.5
            realism: 0.5
            maturity: 0.5
            femininity: 0.85
            mass: 0.35
            muscle: 0.4
            faceShape: 0.4
            chinForm: 0.6
            eyes: 1.2
            nose: 0.8
            hair: 1.2
            skin: "#e8beac"
            hairTone: "#2c1810"
            topClothing: "#e91e63"
            bottomClothing: "#37474f"
        }
        PatrolController {
            character: npcStylized
            enabled: charEditor.selectedCharacter !== npcStylized
            minX: -80; maxX: 80
            minZ: -80; maxZ: 80
        }

        // Gesture demo: a plain Character, nothing parametric about it, and
        // something in the scene worth pointing at.
        Character {
            id: gesturer
            name: "Gesturer"
            roundness: 0.15
            position: Qt.vector3d(-14, 0, 6)
            // Fingers, so a point reads as a point rather than as a stub
            detail: Character.Detail.High
            torsoColor: "#0f9d9a"
            hipColor: "#2c3e50"
            legColor: "#2c3e50"
            activity: Character.Activity.Idle
        }

        Box3D {
            id: gestureMarker
            position: Qt.vector3d(-14, 9, 18)
            width: 1.6
            height: 1.6
            depth: 1.6
            color: "#ff3366"
            showEdges: true
            edgeColorFactor: 0.7
        }

        // Character controller - disabled when editor takes over
        CharacterController {
            id: charController
            character: character
            enabled: !charEditor.hasSelection
            turnSpeed: 3.0
            axisX: gameController.axisX
            axisY: gameController.axisY
            sprinting: gameController.buttonAPressed
        }
        
        // Add some objects for reference
        Repeater3D {
            model: 5
            Box3D {
                x: Math.cos(index * 72 * Math.PI / 180) * 20
                y: 2.5
                z: Math.sin(index * 72 * Math.PI / 180) * 20
                width: 3
                height: 5
                depth: 3
                color: Qt.hsla((index * 0.2) % 1, 0.7, 0.5, 1)
                showEdges: true
                edgeColorFactor: 0.7
            }
        }
    }

    // Game controller for WASD input
    GameController {
        id: gameController
        width: parent.width * .15
        height: parent.height * .15
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 10
        showDebugOverlay: true

        Component.onCompleted: {
            selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D, Qt.Key_Space, Qt.Key_Shift)
        }
    }

    // Character Editor - optional overlay for editing any character
    // Can be removed entirely for zero overhead in game mode
    CharacterEditor {
        id: charEditor
        anchors.fill: parent
        enabled: true
        characters: root.allCharacters
        view3d: view3d
        gameController: gameController
    }

    // Gait panel: preset and emotion for the edited character (or the
    // player), so face and walk can be put together. The other archetypes
    // need nothing here - Eater's mass, Child's maturity and Stylized's
    // femininity already shape their patrol walks through the build.
    Rectangle {
        id: gaitPanel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        width: 300
        height: gaitColumn.height + 16
        color: _gaitPal.window
        opacity: 0.92
        radius: 8
        border.color: Qt.alpha(_gaitPal.windowText, 0.2)

        SystemPalette { id: _gaitPal }

        readonly property var target: charEditor.editTarget ?? character
        readonly property var gait: target ? target.gait : null

        Column {
            id: gaitColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            spacing: 4

            Text {
                text: "Gait: " + (gaitPanel.target ? gaitPanel.target.name : "-")
                font.bold: true
                color: _gaitPal.windowText
            }
            Text {
                text: "Emotion (face + walk)"
                font.pixelSize: 10
                color: Qt.alpha(_gaitPal.windowText, 0.6)
            }
            // One of each row is on and "neutral" is the off. Drawn by hand
            // rather than as Buttons: under the native macOS style the loader
            // runs with, a Button's highlighted and checked looks do not
            // repaint when the state leaves them, so a row of them shows every
            // choice ever clicked.
            component Chip: Rectangle {
                id: chip
                required property string modelData
                property bool active: false
                signal picked(string name)
                width: chipLabel.implicitWidth + 16
                height: chipLabel.implicitHeight + 8
                radius: 5
                color: active ? _gaitPal.highlight : Qt.alpha(_gaitPal.windowText, 0.08)
                border.color: Qt.alpha(_gaitPal.windowText, active ? 0 : 0.25)
                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: chip.modelData
                    font.pixelSize: 11
                    color: chip.active ? _gaitPal.highlightedText : _gaitPal.windowText
                }
                MouseArea { anchors.fill: parent; onClicked: chip.picked(chip.modelData) }
            }
            Flow {
                width: parent.width
                spacing: 4
                Repeater {
                    model: ["neutral", "happy", "sad", "angry"]
                    Chip {
                        active: gaitPanel.target !== null
                                && (gaitPanel.target.emotion === modelData
                                    || (modelData === "neutral" && gaitPanel.target.emotion === ""))
                        onPicked: (name) => { if (gaitPanel.target) gaitPanel.target.setEmotion(name) }
                    }
                }
            }
            Text {
                text: "Preset"
                font.pixelSize: 10
                color: Qt.alpha(_gaitPal.windowText, 0.6)
            }
            Flow {
                width: parent.width
                spacing: 4
                Repeater {
                    model: gaitPanel.gait ? gaitPanel.gait.presetNames : []
                    Chip {
                        active: gaitPanel.gait !== null
                                && (gaitPanel.gait.preset === modelData
                                    || (modelData === "neutral" && gaitPanel.gait.preset === ""))
                        onPicked: (name) => { if (gaitPanel.gait) gaitPanel.gait.preset = name }
                    }
                }
            }
            Row {
                spacing: 8
                CheckBox {
                    text: "from build"
                    font.pixelSize: 10
                    checked: gaitPanel.target ? gaitPanel.target.gaitFromBuild : true
                    onToggled: if (gaitPanel.target) gaitPanel.target.gaitFromBuild = checked
                }
                CheckBox {
                    text: "from emotion"
                    font.pixelSize: 10
                    checked: gaitPanel.target ? gaitPanel.target.gaitFromEmotion : true
                    onToggled: if (gaitPanel.target) gaitPanel.target.gaitFromEmotion = checked
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: _gaitPal.windowText
                text: {
                    const c = gaitPanel.target
                    if (!c) return ""
                    const f = c.gaitFactors
                    const mul = ["tempo", "stride", "armSwing", "kneeLift"]
                    let parts = []
                    for (const k in f) {
                        const n = mul.indexOf(k) >= 0 ? 1 : 0
                        if (Math.abs(f[k] - n) > 1e-9) parts.push(k + " " + (+f[k].toFixed(2)))
                    }
                    return "factors: " + (parts.length ? parts.join("  ") : "neutral")
                         + "\nwalk " + c.walkSpeed.toFixed(1) + "  run " + c.runSpeed.toFixed(1)
                         + "   (walk: WASD, or the editor's Walk/Run)"
                }
            }
        }
    }

    // Gesture keys, and what the layer says it is doing - the state a test
    // asserts on rather than watching the arm.
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: gestureHelp.width + 20
        height: gestureHelp.height + 16
        color: _gesturePal.window
        opacity: 0.9
        radius: 8
        border.color: Qt.alpha(_gesturePal.windowText, 0.2)

        SystemPalette { id: _gesturePal }

        Column {
            id: gestureHelp
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: "Gesturer (plain Character)"
                font.bold: true
                color: _gesturePal.windowText
            }
            Text {
                text: "P point   O thumbs up   I gesticulate   X stop\n"
                      + "L look at camera   K release look   Y turn to marker\n"
                      + "H fingers on/off   N walk/idle   1/2/3/0 emotion"
                color: _gesturePal.windowText
            }
            Text {
                text: "gesture: \"" + gesturer.gesture + "\""
                      + "   hand: \"" + gesturer.gestureHand + "\""
                      + "   settled: " + gesturer.gestureSettled
                      + "   emotion: \"" + gesturer.emotion + "\""
                color: _gesturePal.windowText
            }
        }
    }

    // Speech demo - the edited character (or player) speaks with lip-sync
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: speechRow.width + 20
        height: speechRow.height + 12
        // Follow the system light/dark theme like the native buttons do
        color: _speechPanelPal.window
        opacity: 0.95
        radius: 8
        border.color: Qt.alpha(_speechPanelPal.windowText, 0.2)

        SystemPalette { id: _speechPanelPal }

        readonly property var speaker: charEditor.editTarget ?? character
        readonly property var phrases: [
            "Hello! Welcome to Clayground.",
            "What a wonderful day for a walk.",
            "I can talk, walk, run and fight!",
            "Procedural characters are fun."
        ]
        property int nextPhrase: 0

        Row {
            id: speechRow
            anchors.centerIn: parent
            spacing: 6
            Button {
                text: "Say text"
                onClicked: {
                    const p = parent.parent
                    p.speaker.say(p.phrases[p.nextPhrase])
                    p.nextPhrase = (p.nextPhrase + 1) % p.phrases.length
                }
            }
            Button {
                text: "Play hello.wav"
                onClicked: parent.parent.speaker.say(Qt.resolvedUrl("hello.wav"))
            }
            Button {
                text: "Sing"
                onClicked: parent.parent.speaker.say(Qt.resolvedUrl("sing.wav"))
            }
            Button {
                text: "Stop"
                enabled: parent.parent.speaker.speaking
                onClicked: parent.parent.speaker.stopSpeaking()
            }
        }
    }
}
