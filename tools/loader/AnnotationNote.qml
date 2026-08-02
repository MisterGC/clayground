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
    property color highlight: "#ffd93d"
    property bool selected: false
    // The frame this card belongs to is under the cursor. A preview of the
    // pairing, deliberately weaker than a selection.
    property bool hovered: false

    readonly property bool addressed: status !== "open"
    readonly property color ink: addressed ? "#8a7f79" : "#6E2A1C"
    readonly property color paper: addressed ? "#E4DDD8" : "#F6E7DC"
    readonly property color edge: addressed ? "#A99E97" : "#B23A2A"
    // Nothing on the scene corresponds to this card, so nothing will light up
    // beside it when it is picked.
    readonly property bool frameless: !root.isScene
                                      && (!root.attached || root.addressed)

    signal noteCommitted(string text)
    signal submitted()
    signal removeRequested()
    signal selectRequested()
    signal hoverRequested(bool on)

    // Covers the card and everything in it, the text editor included: hovering
    // a note is hovering the words, not just the paper around them.
    HoverHandler {
        id: hoverProbe
        onHoveredChanged: root.hoverRequested(hoverProbe.hovered)
    }

    implicitHeight: Math.max(54, column.implicitHeight + 18)

    function commit() {
        if (editor.text !== root.noteText) {
            root.noteText = editor.text;
            root.noteCommitted(editor.text);
        }
    }

    function focusEditor() { editor.forceActiveFocus(); editor.cursorPosition = editor.length; }

    // Last line of defence. Cards are delegates over a list that is rebuilt on
    // every structural change, so a card can go away with keystrokes in it
    // that no focus change and no idle timer ever saw.
    Component.onDestruction: {
        try { root.commit(); } catch (e) { }
    }

    onNoteTextChanged: if (!editor.activeFocus && editor.text !== noteText) editor.text = noteText

    // The bubble body. It used to carry a tail pointing at a leader line to
    // the frame; both are gone, so the paper is a plain rounded card and the
    // number badge carries the association on its own.
    Canvas {
        id: bubble
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width, h = height, r = 7;
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.lineTo(w - r, 0);
            ctx.quadraticCurveTo(w, 0, w, r);
            ctx.lineTo(w, h - r);
            ctx.quadraticCurveTo(w, h, w - r, h);
            ctx.lineTo(r, h);
            ctx.quadraticCurveTo(0, h, 0, h - r);
            ctx.lineTo(0, r);
            ctx.quadraticCurveTo(0, 0, r, 0);
            ctx.closePath();
            ctx.fillStyle = root.paper;
            ctx.fill();
            ctx.strokeStyle = (root.selected || root.hovered) ? root.highlight
                                                              : root.edge;
            ctx.lineWidth = root.selected ? 2.2 : (root.hovered ? 1.5 : 1.0);
            ctx.stroke();
        }
        Connections {
            target: root
            function onSelectedChanged() { bubble.requestPaint() }
            function onHoveredChanged() { bubble.requestPaint() }
            function onStatusChanged() { bubble.requestPaint() }
            function onAttachedChanged() { bubble.requestPaint() }
        }
    }

    // The spine down the left edge. Solid means picked, faint means the cursor
    // is passing over the pair - the same distinction the frame draws with its
    // halo, so both ends of a pairing read the same way.
    Rectangle {
        x: 2
        y: 9
        width: root.selected ? 4 : 3
        height: Math.max(0, parent.height - 18)
        radius: 2
        color: root.highlight
        visible: !root.isScene && opacity > 0.01
        opacity: root.selected ? 1.0 : (root.hovered ? 0.45 : 0.0)
        Behavior on opacity { NumberAnimation { duration: 110 } }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: function(mouse) { root.selectRequested(); mouse.accepted = false }
    }

    Column {
        id: column
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: 2

        Row {
            width: parent.width
            spacing: 6

            // The twin of the badge on the frame. Same number, and it turns
            // gold at the same moment - this pair of numbers is the whole
            // association cue now that there is no line to follow.
            Rectangle {
                width: tag.width + 10
                height: tag.height + 3
                radius: 3
                color: root.isScene ? "#00d9ff"
                                    : (root.selected ? root.highlight
                                                     : root.accent)
                border.color: root.hovered && !root.selected ? root.highlight
                                                             : "transparent"
                border.width: 1
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

        // Picking a card normally lights up its frame. When there is no frame,
        // silence would read as "the highlight is broken" - so the card says
        // so itself rather than letting you hunt the scene for a gold rect
        // that is never coming.
        Text {
            width: parent.width - 18
            visible: root.selected && root.frameless
            text: "⌀ nothing on the scene corresponds"
            wrapMode: Text.Wrap
            color: Qt.darker(root.highlight, 2.1)
            font.family: "monospace"
            font.pixelSize: 10
            font.bold: true
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
