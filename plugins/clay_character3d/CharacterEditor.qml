// (c) Clayground Contributors - MIT License, see "LICENSE" file
// CharacterEditor.qml - Self-contained character editing overlay
// Can be added to any scene for character customization, removed for zero overhead

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick3D
import Clayground.Storage
import "control"
import "bodyparts"

Item {
    id: root

    // Required properties
    required property var characters      // Array of ParametricCharacter
    required property View3D view3d       // For 3D picking
    required property var gameController  // For input when controlling

    // Optional configuration
    property bool enabled: true
    property int transitionDuration: 500

    // State - exposed for external camera/controller coordination
    property ParametricCharacter selectedCharacter: null
    readonly property ParametricCharacter editTarget: selectedCharacter ?? (characters.length > 0 ? characters[0] : null)
    readonly property bool hasSelection: selectedCharacter !== null

    // Don't render anything when disabled
    visible: enabled

    // Storage for per-character persistence
    KeyValueStore {
        id: store
        name: "CharacterEditor"
    }

    // Pick handling MouseArea - reparented to view3d
    MouseArea {
        id: pickArea
        parent: root.view3d
        anchors.fill: parent
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton

        onClicked: (mouse) => {
            var result = root.view3d.pick(mouse.x, mouse.y)
            if (result.objectHit) {
                var pickedChar = findCharacterFromPick(result.objectHit)
                if (pickedChar) {
                    selectCharacter(pickedChar)
                } else {
                    deselectCharacter()
                }
            } else {
                deselectCharacter()
            }
        }
    }

    // Find which character owns the picked object by traversing parents
    function findCharacterFromPick(obj) {
        let node = obj
        while (node) {
            for (let i = 0; i < characters.length; i++) {
                if (node === characters[i]) {
                    return characters[i]
                }
            }
            node = node.parent
        }
        return null
    }

    function selectCharacter(target) {
        if (target === selectedCharacter) return
        // Save current before switching
        if (selectedCharacter) {
            saveSettings(selectedCharacter)
        }
        selectedCharacter = target
        console.log("Selected: " + (target ? target.name : "none"))
    }

    function deselectCharacter() {
        if (selectedCharacter) {
            saveSettings(selectedCharacter)
            console.log("Deselected: " + selectedCharacter.name)
        }
        selectedCharacter = null
    }

    // Controller for selected character - takes over input
    CharacterController {
        id: editorController
        character: root.selectedCharacter
        enabled: root.enabled && root.selectedCharacter !== null
        axisX: root.gameController ? root.gameController.axisX : 0
        axisY: root.gameController ? root.gameController.axisY : 0
        sprinting: root.gameController ? root.gameController.buttonAPressed : false
        turnSpeed: 3.0
    }

    // Per-character persistence
    function saveSettings(target) {
        if (!target) return
        let settings = {
            bodyHeight: target.bodyHeight,
            realism: target.realism,
            maturity: target.maturity,
            femininity: target.femininity,
            mass: target.mass,
            muscle: target.muscle,
            faceShape: target.faceShape,
            chinForm: target.chinForm,
            eyes: target.eyes,
            nose: target.nose,
            mouth: target.mouth,
            hair: target.hair,
            skin: target.skin.toString(),
            hairTone: target.hairTone.toString(),
            topClothing: target.topClothing.toString(),
            bottomClothing: target.bottomClothing.toString()
        }
        store.set("char_" + target.name, JSON.stringify(settings))
        console.log("Saved settings for: " + target.name)
    }

    function loadSettings(target) {
        if (!target) return
        let key = "char_" + target.name
        if (!store.has(key)) return
        try {
            let settings = JSON.parse(store.get(key, "{}"))
            if (settings.bodyHeight !== undefined) target.bodyHeight = settings.bodyHeight
            if (settings.realism !== undefined) target.realism = settings.realism
            if (settings.maturity !== undefined) target.maturity = settings.maturity
            if (settings.femininity !== undefined) target.femininity = settings.femininity
            if (settings.mass !== undefined) target.mass = settings.mass
            if (settings.muscle !== undefined) target.muscle = settings.muscle
            if (settings.faceShape !== undefined) target.faceShape = settings.faceShape
            if (settings.chinForm !== undefined) target.chinForm = settings.chinForm
            if (settings.eyes !== undefined) target.eyes = settings.eyes
            if (settings.nose !== undefined) target.nose = settings.nose
            if (settings.mouth !== undefined) target.mouth = settings.mouth
            if (settings.hair !== undefined) target.hair = settings.hair
            if (settings.skin) target.skin = settings.skin
            if (settings.hairTone) target.hairTone = settings.hairTone
            if (settings.topClothing) target.topClothing = settings.topClothing
            if (settings.bottomClothing) target.bottomClothing = settings.bottomClothing
            console.log("Loaded settings for: " + target.name)
        } catch (e) {
            console.log("Failed to load settings for: " + target.name)
        }
    }

    // Load all character settings on startup
    Component.onCompleted: {
        for (let i = 0; i < characters.length; i++) {
            loadSettings(characters[i])
        }
    }

    // Auto-save timer (debounced)
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            if (root.editTarget) {
                saveSettings(root.editTarget)
            }
        }
    }

    function scheduleAutoSave() {
        saveTimer.restart()
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

    // Control panel UI
    Rectangle {
        id: controlPanel
        visible: root.enabled
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

                // Header with selected character name
                Text {
                    text: "Character Editor"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: root.hasSelection
                        ? "Editing: " + root.editTarget.name
                        : "Click a character to select"
                    font.pixelSize: 11
                    color: root.hasSelection ? "#2196F3" : "#888"
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
                Text {
                    text: "Left-click: select | Click ground: deselect"
                    font.pixelSize: 9
                    color: "#888"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Body section
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text { text: "Body"; font.pixelSize: 12; font.bold: true; color: "#555" }

                ParamSlider {
                    label: "Height"
                    value: root.editTarget ? root.editTarget.bodyHeight : 10
                    from: 4.0; to: 14.0; stepSize: 0.5
                    onValueChanged: if (root.editTarget) root.editTarget.bodyHeight = value
                }
                ParamSlider {
                    label: "Realism"
                    value: root.editTarget ? root.editTarget.realism : 0.5
                    onValueChanged: if (root.editTarget) root.editTarget.realism = value
                }
                ParamSlider {
                    label: "Maturity"
                    value: root.editTarget ? root.editTarget.maturity : 0.5
                    onValueChanged: if (root.editTarget) root.editTarget.maturity = value
                }
                ParamSlider {
                    label: "Femininity"
                    value: root.editTarget ? root.editTarget.femininity : 0.5
                    onValueChanged: if (root.editTarget) root.editTarget.femininity = value
                }
                ParamSlider {
                    label: "Mass"
                    value: root.editTarget ? root.editTarget.mass : 0.5
                    onValueChanged: if (root.editTarget) root.editTarget.mass = value
                }
                ParamSlider {
                    label: "Muscle"
                    value: root.editTarget ? root.editTarget.muscle : 0.5
                    onValueChanged: if (root.editTarget) root.editTarget.muscle = value
                }

                // Face section
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text { text: "Face"; font.pixelSize: 12; font.bold: true; color: "#555" }

                ParamSlider {
                    label: "Face Shape"
                    value: root.editTarget ? root.editTarget.faceShape : 0.5
                    onValueChanged: if (root.editTarget) root.editTarget.faceShape = value
                }
                ParamSlider {
                    label: "Chin Form"
                    value: root.editTarget ? root.editTarget.chinForm : 0.5
                    onValueChanged: if (root.editTarget) root.editTarget.chinForm = value
                }
                ParamSlider {
                    label: "Eyes"
                    value: root.editTarget ? root.editTarget.eyes : 1.0
                    from: 0.5; to: 1.5
                    onValueChanged: if (root.editTarget) root.editTarget.eyes = value
                }
                ParamSlider {
                    label: "Nose"
                    value: root.editTarget ? root.editTarget.nose : 1.0
                    from: 0.5; to: 1.5
                    onValueChanged: if (root.editTarget) root.editTarget.nose = value
                }
                ParamSlider {
                    label: "Mouth"
                    value: root.editTarget ? root.editTarget.mouth : 1.0
                    from: 0.5; to: 1.5
                    onValueChanged: if (root.editTarget) root.editTarget.mouth = value
                }
                ParamSlider {
                    label: "Hair"
                    value: root.editTarget ? root.editTarget.hair : 0.8
                    from: 0.0; to: 1.5
                    onValueChanged: if (root.editTarget) root.editTarget.hair = value
                }

                // Colors section
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text { text: "Colors"; font.pixelSize: 12; font.bold: true; color: "#555" }

                ColorPicker {
                    label: "Skin"
                    colorValue: root.editTarget ? root.editTarget.skin : "#fdbcb4"
                    onColorValueChanged: if (root.editTarget) root.editTarget.skin = colorValue
                }
                ColorPicker {
                    label: "Hair"
                    colorValue: root.editTarget ? root.editTarget.hairTone : "#8b4513"
                    onColorValueChanged: if (root.editTarget) root.editTarget.hairTone = colorValue
                }
                ColorPicker {
                    label: "Top"
                    colorValue: root.editTarget ? root.editTarget.topClothing : "#4169e1"
                    onColorValueChanged: if (root.editTarget) root.editTarget.topClothing = colorValue
                }
                ColorPicker {
                    label: "Bottom"
                    colorValue: root.editTarget ? root.editTarget.bottomClothing : "#2c3e50"
                    onColorValueChanged: if (root.editTarget) root.editTarget.bottomClothing = colorValue
                }

                // Activity toggle
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text { text: "Activity"; font.pixelSize: 12; font.bold: true; color: "#555" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Button {
                        text: "Idle"
                        font.pixelSize: 10
                        highlighted: root.editTarget && root.editTarget.activity === Character.Idle
                        enabled: root.editTarget !== null
                        onClicked: if (root.editTarget) root.editTarget.activity = Character.Idle
                    }
                    Button {
                        text: "Walk"
                        font.pixelSize: 10
                        highlighted: root.editTarget && root.editTarget.activity === Character.Walking
                        enabled: root.editTarget !== null
                        onClicked: if (root.editTarget) root.editTarget.activity = Character.Walking
                    }
                    Button {
                        text: "Run"
                        font.pixelSize: 10
                        highlighted: root.editTarget && root.editTarget.activity === Character.Running
                        enabled: root.editTarget !== null
                        onClicked: if (root.editTarget) root.editTarget.activity = Character.Running
                    }
                    Button {
                        text: "Using"
                        font.pixelSize: 10
                        highlighted: root.editTarget && root.editTarget.activity === Character.Using
                        enabled: root.editTarget !== null
                        onClicked: if (root.editTarget) root.editTarget.activity = Character.Using
                    }
                }

                // Facial expressions
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text { text: "Expression"; font.pixelSize: 12; font.bold: true; color: "#555" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Button {
                        text: "Idle"
                        font.pixelSize: 10
                        highlighted: root.editTarget && root.editTarget.faceActivity === Head.Activity.Idle
                        onClicked: if (root.editTarget) root.editTarget.faceActivity = Head.Activity.Idle
                    }
                    Button {
                        text: "Joy"
                        font.pixelSize: 10
                        highlighted: root.editTarget && root.editTarget.faceActivity === Head.Activity.ShowJoy
                        onClicked: if (root.editTarget) root.editTarget.faceActivity = Head.Activity.ShowJoy
                    }
                    Button {
                        text: "Anger"
                        font.pixelSize: 10
                        highlighted: root.editTarget && root.editTarget.faceActivity === Head.Activity.ShowAnger
                        onClicked: if (root.editTarget) root.editTarget.faceActivity = Head.Activity.ShowAnger
                    }
                    Button {
                        text: "Sad"
                        font.pixelSize: 10
                        highlighted: root.editTarget && root.editTarget.faceActivity === Head.Activity.ShowSadness
                        onClicked: if (root.editTarget) root.editTarget.faceActivity = Head.Activity.ShowSadness
                    }
                    Button {
                        text: "Talk"
                        font.pixelSize: 10
                        highlighted: root.editTarget && root.editTarget.faceActivity === Head.Activity.Talk
                        onClicked: if (root.editTarget) root.editTarget.faceActivity = Head.Activity.Talk
                    }
                }

                // Info
                Rectangle { height: 1; color: "#ddd"; Layout.fillWidth: true }
                Text {
                    text: "Settings auto-save per character"
                    font.pixelSize: 9
                    color: "#888"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
