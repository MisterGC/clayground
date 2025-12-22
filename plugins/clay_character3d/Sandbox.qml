// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import Clayground.GameController
import Clayground.Storage
import "control"
import "bodyparts"

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

    // Persistent storage for character settings
    KeyValueStore {
        id: characterStore
        name: "Character3DSandbox"
    }

    function saveCharacterSettings() {
        let settings = {
            bodyHeight: character.bodyHeight,
            realism: character.realism,
            maturity: character.maturity,
            femininity: character.femininity,
            mass: character.mass,
            muscle: character.muscle,
            faceShape: character.faceShape,
            chinForm: character.chinForm,
            eyes: character.eyes,
            nose: character.nose,
            mouth: character.mouth,
            hair: character.hair,
            skin: character.skin.toString(),
            hairTone: character.hairTone.toString(),
            topClothing: character.topClothing.toString(),
            bottomClothing: character.bottomClothing.toString()
        };
        characterStore.set("playerSettings", JSON.stringify(settings));
        console.log("Character settings saved");
    }

    function loadCharacterSettings() {
        if (characterStore.has("playerSettings")) {
            let settings = JSON.parse(characterStore.get("playerSettings", "{}"));
            if (settings.bodyHeight !== undefined) character.bodyHeight = settings.bodyHeight;
            if (settings.realism !== undefined) character.realism = settings.realism;
            if (settings.maturity !== undefined) character.maturity = settings.maturity;
            if (settings.femininity !== undefined) character.femininity = settings.femininity;
            if (settings.mass !== undefined) character.mass = settings.mass;
            if (settings.muscle !== undefined) character.muscle = settings.muscle;
            if (settings.faceShape !== undefined) character.faceShape = settings.faceShape;
            if (settings.chinForm !== undefined) character.chinForm = settings.chinForm;
            if (settings.eyes !== undefined) character.eyes = settings.eyes;
            if (settings.nose !== undefined) character.nose = settings.nose;
            if (settings.mouth !== undefined) character.mouth = settings.mouth;
            if (settings.hair !== undefined) character.hair = settings.hair;
            if (settings.skin) character.skin = settings.skin;
            if (settings.hairTone) character.hairTone = settings.hairTone;
            if (settings.topClothing) character.topClothing = settings.topClothing;
            if (settings.bottomClothing) character.bottomClothing = settings.bottomClothing;
            console.log("Character settings loaded");
        }
    }

    Component.onCompleted: loadCharacterSettings()

    // Auto-save timer (debounced to avoid saving on every tiny change)
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: saveCharacterSettings()
    }

    function scheduleAutoSave() {
        saveTimer.restart()
    }

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
        // Let other keys pass through to forwardTo targets
    }
    
    View3D {
        id: view3d
        anchors.fill: parent
        
        environment: SceneEnvironment {
            clearColor: "#f0f0f0"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            
            // Enable toon shading
            tonemapMode: SceneEnvironment.TonemapModeNone
        }

        // Lighting setup - high ambient with soft shadows
        // Main key light (primary shadow caster)
        DirectionalLight {
            id: mainLight
            eulerRotation.x: -40
            eulerRotation.y: -45

            castsShadow: true
            shadowFactor: 25
            shadowMapQuality: Light.ShadowMapQualityHigh
            pcfFactor: 12
            shadowBias: 10

            brightness: 0.5
            ambientColor: Qt.rgba(0.55, 0.55, 0.6, 1.0)
        }

        // Front fill light - ensures face is always lit
        DirectionalLight {
            id: frontLight
            eulerRotation.x: -20
            eulerRotation.y: 180

            castsShadow: false
            brightness: 0.5
        }

        // Side fill lights for even coverage
        DirectionalLight {
            id: leftFill
            eulerRotation.x: -25
            eulerRotation.y: 90

            castsShadow: false
            brightness: 0.35
        }

        DirectionalLight {
            id: rightFill
            eulerRotation.x: -25
            eulerRotation.y: -90

            castsShadow: false
            brightness: 0.35
        }

        // Back light for rim
        DirectionalLight {
            id: backLight
            eulerRotation.x: -20
            eulerRotation.y: 0

            castsShadow: false
            brightness: 0.3
        }
        
        // Character camera that follows the character
        CharacterCamera {
            id: charCamera
            character: character
            orbitDistance: root.cameraDistance
            orbitPitch: root.cameraPitch
            orbitYawOffset: root.cameraYaw
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
        // Bottom-aligned: surface = y + (height * voxelSize) = -4 + (2 * 2.0) = 0
        StaticVoxelMap {
            id: ground
            visible: true
            y: -4
            width: 100
            height: 2
            depth: 100
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

        // Showcase row: different character archetypes
        Node {
            id: showcase
            z: -30  // Behind the player

            // Thin Thinker
            ParametricCharacter {
                x: -25
                name: "Thinker"
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
                activity: Character.Idle
            }

            // Big Eater
            ParametricCharacter {
                x: -12
                name: "Eater"
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
                activity: Character.Idle
            }

            // Athletic Hero
            ParametricCharacter {
                x: 0
                name: "Hero"
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
                activity: Character.Walking
            }

            // Cartoon Child
            ParametricCharacter {
                x: 12
                name: "Child"
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
                activity: Character.Idle
            }

            // Stylized Woman
            ParametricCharacter {
                x: 25
                name: "Stylized"
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
                activity: Character.Idle
            }
        }
        
        // Character controller
        CharacterController {
            id: charController
            character: character
            enabled: true
            turnSpeed: 3.0
            axisX: gameController.axisX
            axisY: gameController.axisY
            sprinting: gameController.buttonAPressed  // Shift key (via buttonBKey) for running
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

    // Parameter slider component
    component ParamSlider: RowLayout {
        property string label: ""
        property real value: 0.5
        property real from: 0.0
        property real to: 1.0
        property real stepSize: 0.05
        spacing: 5
        Layout.fillWidth: true

        Text {
            text: label
            font.pixelSize: 11
            Layout.preferredWidth: 70
            color: "#333"
        }
        Slider {
            id: slider
            from: parent.from
            to: parent.to
            value: parent.value
            stepSize: parent.stepSize
            Layout.fillWidth: true
            onMoved: { parent.value = value; root.scheduleAutoSave(); }
        }
        Text {
            text: parent.value.toFixed(2)
            font.pixelSize: 10
            Layout.preferredWidth: 35
            color: "#666"
        }
    }

    // Color picker component
    component ColorPicker: RowLayout {
        id: colorPickerRow
        property string label: ""
        property color colorValue: "white"
        spacing: 5
        Layout.fillWidth: true

        ColorDialog {
            id: colorDialog
            selectedColor: colorPickerRow.colorValue
            onAccepted: {
                colorPickerRow.colorValue = selectedColor
                root.scheduleAutoSave()
            }
        }

        Text {
            text: colorPickerRow.label
            font.pixelSize: 11
            Layout.preferredWidth: 70
            color: "#333"
        }
        Rectangle {
            width: 24
            height: 24
            color: colorPickerRow.colorValue
            border.color: "#999"
            border.width: 1
            radius: 3

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: colorDialog.open()
            }
        }
        TextField {
            Layout.fillWidth: true
            text: colorPickerRow.colorValue
            font.pixelSize: 10
            onEditingFinished: { colorPickerRow.colorValue = text; root.scheduleAutoSave(); }
        }
    }

    // Control panel with sliders
    Rectangle {
        id: controlPanel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        width: 280
        color: "#f8f8f8"
        opacity: 0.95
        radius: 8
        border.color: "#ddd"
        border.width: 1

        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                id: controlColumn
                width: scrollView.availableWidth
                spacing: 8

                // Header
                Text {
                    text: "Character Parameters"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "WASD: move | Shift: run | Q/E: rotate cam"
                    font.pixelSize: 9
                    color: "#888"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "R/F: pitch | T/G: zoom | Right-drag: orbit"
                    font.pixelSize: 9
                    color: "#888"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Body section
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text { text: "Body"; font.pixelSize: 12; font.bold: true; color: "#555" }

                ParamSlider {
                    label: "Height"
                    value: character.bodyHeight
                    from: 4.0; to: 14.0; stepSize: 0.5
                    onValueChanged: character.bodyHeight = value
                }
                ParamSlider {
                    label: "Realism"
                    value: character.realism
                    onValueChanged: character.realism = value
                }
                ParamSlider {
                    label: "Maturity"
                    value: character.maturity
                    onValueChanged: character.maturity = value
                }
                ParamSlider {
                    label: "Femininity"
                    value: character.femininity
                    onValueChanged: character.femininity = value
                }
                ParamSlider {
                    label: "Mass"
                    value: character.mass
                    onValueChanged: character.mass = value
                }
                ParamSlider {
                    label: "Muscle"
                    value: character.muscle
                    onValueChanged: character.muscle = value
                }

                // Face section
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text { text: "Face"; font.pixelSize: 12; font.bold: true; color: "#555" }

                ParamSlider {
                    label: "Face Shape"
                    value: character.faceShape
                    onValueChanged: character.faceShape = value
                }
                ParamSlider {
                    label: "Chin Form"
                    value: character.chinForm
                    onValueChanged: character.chinForm = value
                }
                ParamSlider {
                    label: "Eyes"
                    value: character.eyes
                    from: 0.5; to: 1.5
                    onValueChanged: character.eyes = value
                }
                ParamSlider {
                    label: "Nose"
                    value: character.nose
                    from: 0.5; to: 1.5
                    onValueChanged: character.nose = value
                }
                ParamSlider {
                    label: "Mouth"
                    value: character.mouth
                    from: 0.5; to: 1.5
                    onValueChanged: character.mouth = value
                }
                ParamSlider {
                    label: "Hair"
                    value: character.hair
                    from: 0.0; to: 1.5
                    onValueChanged: character.hair = value
                }

                // Colors section
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text { text: "Colors"; font.pixelSize: 12; font.bold: true; color: "#555" }

                ColorPicker {
                    label: "Skin"
                    colorValue: character.skin
                    onColorValueChanged: character.skin = colorValue
                }
                ColorPicker {
                    label: "Hair"
                    colorValue: character.hairTone
                    onColorValueChanged: character.hairTone = colorValue
                }
                ColorPicker {
                    label: "Top"
                    colorValue: character.topClothing
                    onColorValueChanged: character.topClothing = colorValue
                }
                ColorPicker {
                    label: "Bottom"
                    colorValue: character.bottomClothing
                    onColorValueChanged: character.bottomClothing = colorValue
                }

                // Activity toggle
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Activity:"; font.pixelSize: 11 }
                    Button {
                        text: character.activity === Character.Idle ? "Idle" : "Walking"
                        onClicked: {
                            character.activity = character.activity === Character.Idle
                                ? Character.Walking : Character.Idle
                        }
                    }
                }

                // Facial expressions
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text { text: "Face"; font.pixelSize: 12; font.bold: true; color: "#555" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Button {
                        text: "Idle"
                        font.pixelSize: 10
                        highlighted: character.faceActivity === Head.Activity.Idle
                        onClicked: character.faceActivity = Head.Activity.Idle
                    }
                    Button {
                        text: "Joy"
                        font.pixelSize: 10
                        highlighted: character.faceActivity === Head.Activity.ShowJoy
                        onClicked: character.faceActivity = Head.Activity.ShowJoy
                    }
                    Button {
                        text: "Anger"
                        font.pixelSize: 10
                        highlighted: character.faceActivity === Head.Activity.ShowAnger
                        onClicked: character.faceActivity = Head.Activity.ShowAnger
                    }
                    Button {
                        text: "Sad"
                        font.pixelSize: 10
                        highlighted: character.faceActivity === Head.Activity.ShowSadness
                        onClicked: character.faceActivity = Head.Activity.ShowSadness
                    }
                    Button {
                        text: "Talk"
                        font.pixelSize: 10
                        highlighted: character.faceActivity === Head.Activity.Talk
                        onClicked: character.faceActivity = Head.Activity.Talk
                    }
                }

                // Info
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text {
                    text: "Settings auto-save and restore"
                    font.pixelSize: 9
                    color: "#888"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "Showcase behind: Thinker, Eater, Hero, Child, Stylized"
                    font.pixelSize: 9
                    color: "#888"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }
}
