// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

// The annotation surface (issue #182). Lives in the loader's overlay layer,
// never in the sandbox: it has to survive hot reload and must never become
// part of the application under development.
//
// Two kinds of note, one view. The scene-level note sits at the top of the
// margin panel (this is what Ctrl+F used to produce in one shot). Region
// notes are framed on the scene and written in the margin below it, joined by
// a leader line - text never floats over the pixels it is about.
Item {
    id: root

    signal closeRequested()

    readonly property int panelW: Math.max(300, Math.min(420, width * 0.32))
    readonly property color ink: "#6E2A1C"
    readonly property color edge: "#B23A2A"
    readonly property color accent: "#ff3366"

    // Local copy of the store. Re-read only at structural moments (open,
    // add, remove, clear) so typing in a note never tears down the field
    // being typed in.
    property var items: []
    property var regionItems: []
    property string selectedId: ""
    property string sceneId: ""
    property bool wipeArmed: false

    FontLoader { id: hand; source: "qrc:/clayground/fonts/Caveat.ttf" }

    function sync() {
        var all = ClayAnnotations.annotations;
        var regions = [];
        for (var i = 0; i < all.length; ++i)
            if (all[i].scope === "region") regions.push(all[i]);
        items = all;
        regionItems = regions;
        sceneId = ClayAnnotations.sceneNoteId();
        var scene = null;
        for (var j = 0; j < all.length; ++j)
            if (all[j].id === sceneId) scene = all[j];
        sceneNote.noteText = scene ? scene.note : "";
        leaders.requestPaint();
    }

    // Called from MainWindow when the surface is shown.
    function activate() {
        ClayAnnotations.reload();
        wipeArmed = false;
        sync();
        sceneNote.focusEditor();
    }

    // Called from MainWindow right before the surface is hidden - the last
    // chance to get an unsaved keystroke into the store.
    function deactivate() {
        commitAll();
    }

    function commitAll() {
        sceneNote.commit();
        for (var i = 0; i < noteRepeater.count; ++i) {
            var c = noteRepeater.itemAt(i);
            if (c) c.commit();
        }
    }

    function commitSceneNote(text) {
        if (sceneId === "") {
            if (text.trim() === "") return;
            sceneId = ClayAnnotations.addAnnotation(
                "scene", Qt.rect(0, 0, 0, 0), text, ClayTimeCtrl.paused);
            sync();
        } else {
            ClayAnnotations.setNote(sceneId, text);
        }
    }

    function createRegion(x, y, w, h) {
        var id = ClayAnnotations.addAnnotation(
            "region", Qt.rect(x, y, w, h), "", ClayTimeCtrl.paused);
        if (id === "") return;
        sync();
        selectedId = id;
        for (var i = 0; i < regionItems.length; ++i) {
            if (regionItems[i].id === id) {
                var card = noteRepeater.itemAt(i);
                if (card) { notesFlick.ensureVisible(card); card.focusEditor(); }
                break;
            }
        }
    }

    function removeAnnotation(id) {
        commitAll();
        ClayAnnotations.removeAnnotation(id);
        sync();
    }

    Keys.onEscapePressed: root.closeRequested()

    // A whisper of dim so the surface is visibly on without hiding the scene.
    Rectangle {
        anchors.fill: parent
        color: "#1e0a0a12"
    }

    // ---------------------------------------------------------------- scene
    Item {
        id: sceneArea
        x: 0
        y: 0
        width: root.width - root.panelW
        height: root.height
        clip: true

        MouseArea {
            id: creator
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            property real startX: 0
            property real startY: 0
            property bool dragging: false

            onPressed: function(mouse) {
                root.commitAll();
                startX = mouse.x; startY = mouse.y;
                dragging = true;
                band.x = mouse.x; band.y = mouse.y;
                band.width = 0; band.height = 0;
            }
            onPositionChanged: function(mouse) {
                if (!dragging) return;
                band.x = Math.min(startX, mouse.x);
                band.y = Math.min(startY, mouse.y);
                band.width = Math.abs(mouse.x - startX);
                band.height = Math.abs(mouse.y - startY);
            }
            onReleased: function(mouse) {
                dragging = false;
                var w = band.width, h = band.height;
                var x = band.x, y = band.y;
                // A plain click still gets you something grabbable - a
                // zero-size rect would be a marker you cannot take hold of.
                if (w < 24 || h < 24) {
                    w = 150; h = 100;
                    x = mouse.x - w / 2; y = mouse.y - h / 2;
                }
                x = Math.max(0, Math.min(x, width - w));
                y = Math.max(0, Math.min(y, height - h));
                band.width = 0; band.height = 0;
                root.createRegion(x, y, w, h);
            }
        }

        Canvas {
            id: leaders
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = root.edge;
                ctx.lineWidth = 1.5;
                for (var i = 0; i < regionRepeater.count; ++i) {
                    var reg = regionRepeater.itemAt(i);
                    var card = noteRepeater.itemAt(i);
                    if (!reg || !card || !reg.visible || !card.visible) continue;
                    var from = Qt.point(reg.x + reg.width, reg.y + reg.height / 2);
                    var to = card.mapToItem(leaders, card.tailPoint.x,
                                            card.tailPoint.y);
                    if (to.x < from.x) continue;
                    ctx.beginPath();
                    ctx.moveTo(from.x, from.y);
                    var mx = (from.x + to.x) / 2;
                    ctx.bezierCurveTo(mx, from.y, mx, to.y, to.x, to.y);
                    ctx.stroke();
                }
            }
        }

        Repeater {
            id: regionRepeater
            model: root.regionItems
            AnnotationRegion {
                annId: modelData.id
                idx: index
                x: modelData.rectX
                y: modelData.rectY
                width: modelData.rectW
                height: modelData.rectH
                // A marker is never drawn over pixels that no longer
                // correspond to it - a detached note lives in the margin only.
                visible: modelData.attached && modelData.status === "open"
                enabled: visible
                selected: root.selectedId === modelData.id
                frameColor: root.selectedId === modelData.id ? "#ffd93d"
                                                             : root.accent
                onSelectRequested: root.selectedId = modelData.id
                onGeometryEdited: {
                    ClayAnnotations.setRect(annId, Qt.rect(x, y, width, height));
                    leaders.requestPaint();
                }
                onXChanged: leaders.requestPaint()
                onYChanged: leaders.requestPaint()
                onWidthChanged: leaders.requestPaint()
                onHeightChanged: leaders.requestPaint()
            }
        }

        Rectangle {
            id: band
            color: "#33ff3366"
            border.color: root.accent
            border.width: 2
            visible: creator.dragging && width > 2 && height > 2
        }
    }

    // ---------------------------------------------------------------- panel
    Rectangle {
        id: panel
        anchors.right: parent.right
        width: root.panelW
        height: root.height
        color: "#f7141018"

        Rectangle {
            width: 1; height: parent.height
            color: "#55ffffff"
        }

        Column {
            id: head
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 6

            Row {
                width: parent.width
                spacing: 8
                Text {
                    text: "ANNOTATIONS"
                    color: "#00d9ff"
                    font.family: "monospace"
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: ClayAnnotations.openCount + " open"
                    color: "#9aa0a6"
                    font.family: "monospace"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: 1; height: 1 }
            }

            Row {
                width: parent.width
                spacing: 6

                // Pause on open, with the opt-out right where you notice it.
                Rectangle {
                    width: pauseTxt.width + 14
                    height: pauseTxt.height + 8
                    radius: 3
                    color: ClayAnnotations.pauseOnOpen ? "#0f9d9a" : "#2a2a33"
                    Text {
                        id: pauseTxt
                        anchors.centerIn: parent
                        text: ClayAnnotations.pauseOnOpen ? "‖ pause scene"
                                                          : "▶ scene runs"
                        color: ClayAnnotations.pauseOnOpen ? "#0d1414" : "#9aa0a6"
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ClayAnnotations.pauseOnOpen = !ClayAnnotations.pauseOnOpen;
                            ClayTimeCtrl.paused = ClayAnnotations.pauseOnOpen;
                        }
                    }
                }

                Rectangle {
                    width: clearTxt.width + 14
                    height: clearTxt.height + 8
                    radius: 3
                    color: "#2a2a33"
                    Text {
                        id: clearTxt
                        anchors.centerIn: parent
                        text: "clear addressed"
                        color: "#9aa0a6"
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.commitAll();
                            ClayAnnotations.clearAddressed();
                            root.sync();
                        }
                    }
                }

                Rectangle {
                    width: wipeTxt.width + 14
                    height: wipeTxt.height + 8
                    radius: 3
                    color: root.wipeArmed ? "#ff3366" : "#2a2a33"
                    Text {
                        id: wipeTxt
                        anchors.centerIn: parent
                        text: root.wipeArmed ? "sure?" : "wipe all"
                        color: root.wipeArmed ? "#1a1010" : "#9aa0a6"
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.wipeArmed) {
                                root.wipeArmed = true;
                                disarm.restart();
                            } else {
                                root.wipeArmed = false;
                                ClayAnnotations.wipeAll();
                                root.sync();
                            }
                        }
                    }
                    Timer {
                        id: disarm
                        interval: 3000
                        onTriggered: root.wipeArmed = false
                    }
                }
            }

            AnnotationNote {
                id: sceneNote
                width: parent.width
                isScene: true
                detachable: sceneNote.noteText !== ""
                handFamily: hand.name
                placeholder: "the lighting is too dark ..."
                onNoteCommitted: function(text) { root.commitSceneNote(text) }
                onSubmitted: root.closeRequested()
                onRemoveRequested: {
                    if (root.sceneId !== "") root.removeAnnotation(root.sceneId);
                    sceneNote.noteText = "";
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#33ffffff"
            }

            Text {
                text: root.regionItems.length === 0
                      ? "drag on the scene to frame a region"
                      : "REGIONS"
                color: "#6f7680"
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        Flickable {
            id: notesFlick
            anchors.top: head.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: hints.top
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            clip: true
            contentHeight: noteColumn.height
            boundsBehavior: Flickable.StopAtBounds
            onContentYChanged: leaders.requestPaint()

            function ensureVisible(item) {
                var top = item.y;
                var bottom = item.y + item.height;
                if (top < contentY) contentY = top;
                else if (bottom > contentY + height)
                    contentY = Math.max(0, bottom - height);
            }

            ScrollBar.vertical: ScrollBar { }

            Column {
                id: noteColumn
                width: notesFlick.width
                spacing: 8
                onHeightChanged: leaders.requestPaint()

                Repeater {
                    id: noteRepeater
                    model: root.regionItems
                    AnnotationNote {
                        width: noteColumn.width
                        annId: modelData.id
                        idx: index
                        handFamily: hand.name
                        noteText: modelData.note
                        status: modelData.status
                        addressedNote: modelData.addressedNote
                        attached: modelData.attached
                        placeholder: "what is wrong here?"
                        selected: root.selectedId === modelData.id
                        onNoteCommitted: function(text) {
                            ClayAnnotations.setNote(annId, text);
                        }
                        onSubmitted: root.forceActiveFocus()
                        onSelectRequested: root.selectedId = modelData.id
                        onRemoveRequested: root.removeAnnotation(annId)
                        onYChanged: leaders.requestPaint()
                        onHeightChanged: leaders.requestPaint()
                    }
                }
            }
        }

        Column {
            id: hints
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 2

            Rectangle { width: parent.width; height: 1; color: "#33ffffff" }
            Text {
                text: "Ctrl+F  close   ·   Esc  close"
                color: "#6f7680"; font.family: "monospace"; font.pixelSize: 10
            }
            Text {
                text: "drag  frame a region   ·   click  default rect"
                color: "#6f7680"; font.family: "monospace"; font.pixelSize: 10
            }
            Text {
                text: "Enter  save (scene note also closes)"
                color: "#6f7680"; font.family: "monospace"; font.pixelSize: 10
            }
            Text {
                text: "Ctrl+Shift+F  clear addressed"
                color: "#6f7680"; font.family: "monospace"; font.pixelSize: 10
            }
        }
    }

    // The store changes under us when an agent marks something addressed.
    Connections {
        target: ClayAnnotations
        function onGenerationChanged() { root.sync() }
    }
}
