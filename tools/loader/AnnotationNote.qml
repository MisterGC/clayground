// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

// A note in the margin panel, drawn as textli draws a comment: handwriting in
// dark red ink on a warm paper bubble. The bubble carries its own backdrop
// because a sandbox can be any colour underneath and legibility beats fidelity.
Item {
    id: root

    property string annId: ""
    property string handFamily: "Caveat"
    property string noteText: ""
    property string placeholder: ""
    property string status: "open"
    property string addressedNote: ""
    property bool attached: true
    property bool isScene: false
    property bool detachable: true
    property int idx: -1
    property color accent: "#ff3366"
    property bool selected: false

    readonly property bool addressed: status !== "open"
    readonly property color ink: addressed ? "#8a7f79" : "#6E2A1C"
    readonly property color paper: addressed ? "#E4DDD8" : "#F6E7DC"
    readonly property color edge: addressed ? "#A99E97" : "#B23A2A"
    // The tail is a leader to a frame on the scene. A scene-level note has no
    // frame, and a detached one no longer has a place to point at.
    readonly property int tailW: (root.isScene || !root.attached
                                  || root.addressed) ? 0 : 12

    // The point the leader line starts from, in this item's coordinates.
    readonly property point tailPoint: Qt.point(0, 26)

    signal noteCommitted(string text)
    signal submitted()
    signal removeRequested()
    signal selectRequested()

    implicitHeight: Math.max(54, column.implicitHeight + 18)

    function commit() {
        if (editor.text !== root.noteText) {
            root.noteText = editor.text;
            root.noteCommitted(editor.text);
        }
    }

    function focusEditor() { editor.forceActiveFocus(); editor.cursorPosition = editor.length; }

    onNoteTextChanged: if (!editor.activeFocus && editor.text !== noteText) editor.text = noteText

    // Bubble body plus tail, one path so the tail is part of the outline.
    Canvas {
        id: bubble
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width, h = height, t = root.tailW, r = 7;
            var l = t;
            ctx.beginPath();
            ctx.moveTo(l + r, 0);
            ctx.lineTo(w - r, 0);
            ctx.quadraticCurveTo(w, 0, w, r);
            ctx.lineTo(w, h - r);
            ctx.quadraticCurveTo(w, h, w - r, h);
            ctx.lineTo(l + r, h);
            ctx.quadraticCurveTo(l, h, l, h - r);
            if (t > 0) {
                ctx.lineTo(l, root.tailPoint.y + 7);
                ctx.lineTo(0, root.tailPoint.y);
                ctx.lineTo(l, root.tailPoint.y - 7);
            }
            ctx.lineTo(l, r);
            ctx.quadraticCurveTo(l, 0, l + r, 0);
            ctx.closePath();
            ctx.fillStyle = root.paper;
            ctx.fill();
            ctx.strokeStyle = root.selected ? Qt.lighter(root.accent, 1.0)
                                            : root.edge;
            ctx.lineWidth = root.selected ? 2.0 : 1.0;
            ctx.stroke();
        }
        Connections {
            target: root
            function onSelectedChanged() { bubble.requestPaint() }
            function onStatusChanged() { bubble.requestPaint() }
            function onAttachedChanged() { bubble.requestPaint() }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: function(mouse) { root.selectRequested(); mouse.accepted = false }
    }

    Column {
        id: column
        anchors.left: parent.left
        anchors.leftMargin: root.tailW + 10
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: 2

        Row {
            width: parent.width
            spacing: 6

            Rectangle {
                width: tag.width + 10
                height: tag.height + 3
                radius: 3
                color: root.isScene ? "#00d9ff" : root.accent
                visible: true
                Text {
                    id: tag
                    anchors.centerIn: parent
                    text: root.isScene ? "WHOLE SCENE" : String(root.idx + 1)
                    color: "#1a1010"
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "monospace"
                }
            }

            Rectangle {
                width: detachTag.width + 10
                height: detachTag.height + 3
                radius: 3
                color: "#ffd93d"
                visible: !root.isScene && !root.attached && !root.addressed
                Text {
                    id: detachTag
                    anchors.centerIn: parent
                    text: "DETACHED"
                    color: "#1a1010"
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "monospace"
                }
            }

            Rectangle {
                width: doneTag.width + 10
                height: doneTag.height + 3
                radius: 3
                color: "#0f9d9a"
                visible: root.addressed
                Text {
                    id: doneTag
                    anchors.centerIn: parent
                    text: "ADDRESSED"
                    color: "#0d1414"
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "monospace"
                }
            }

            Item { width: 1; height: 1 }
        }

        TextArea {
            id: editor
            width: parent.width - 18
            padding: 0
            topPadding: 2
            text: root.noteText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            readOnly: root.addressed
            color: root.ink
            selectionColor: "#E7C6A0"
            selectedTextColor: root.ink
            font.family: root.handFamily
            font.pixelSize: 21
            placeholderText: root.placeholder
            placeholderTextColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
            background: null

            onActiveFocusChanged: {
                if (activeFocus) root.selectRequested();
                else root.commit();
            }
            onTextChanged: idle.restart()

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        editor.insert(editor.cursorPosition, "\n");
                    } else {
                        root.commit();
                        root.submitted();
                    }
                    event.accepted = true;
                }
            }

            Timer {
                id: idle
                interval: 700
                onTriggered: root.commit()
            }
        }

        Text {
            width: parent.width - 18
            visible: root.addressed && root.addressedNote !== ""
            text: "✓ " + root.addressedNote
            wrapMode: Text.Wrap
            color: "#0f9d9a"
            font.family: root.handFamily
            font.pixelSize: 18
        }
    }

    // Eraser. Deleting is the author's alone - an agent only ever marks
    // addressed, so this button is the one and only removal path.
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 4
        text: "×"
        color: root.ink
        opacity: eraseArea.containsMouse ? 1.0 : 0.4
        font.pixelSize: 18
        font.bold: true
        visible: root.detachable
        MouseArea {
            id: eraseArea
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeRequested()
        }
    }
}
