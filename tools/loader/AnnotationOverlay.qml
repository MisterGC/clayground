// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

// The annotation surface (issue #182). Lives in the loader's overlay layer,
// never in the sandbox: it has to survive hot reload and must never become
// part of the application under development.
//
// Two kinds of note, one view. The scene-level note sits at the top of the
// margin panel (this is what Ctrl+F used to produce in one shot). Region
// notes are framed on the scene and written in the margin below it - text
// never floats over the pixels it is about.
//
// The panel FLOATS over the scene rather than taking layout space from it. The
// sandbox keeps its full size while the surface is open: shrinking it would
// reflow every responsive layout and change the very thing being annotated,
// and it would put a third of the viewport out of reach of a frame. Tab folds
// the panel away when it is in front of what you want to look at.
//
// A frame and its card used to be joined by a drawn leader line. That is gone.
// A line only means something while the two ends hold still relative to each
// other, and the panel now floats, folds and scrolls - the lines crossed the
// panel, pointed at cards that were not there, and vanished on Tab. What
// replaces them is a PAIRING: the matching number on frame and card is the
// static cue, and picking either end lights up the other. Hover previews the
// pair, a click makes it stick, and the two never look alike.
Item {
    id: root

    signal closeRequested()

    readonly property int panelW: Math.max(300, Math.min(420, width * 0.32))
    // The strip left sticking out when the panel is folded away.
    readonly property int handleW: 26
    // Half the height, parked at the bottom: the top-left of a scene is where
    // most of it lives, so that is the corner the panel never covers.
    readonly property int dockH: Math.max(260, Math.round(height * 0.5))
    // Frames are pink, the picked pair is gold, addressed is teal - the same
    // three the panel already used. No new colour comes in with the pairing:
    // gold was already "this is the one", it just now means it at both ends.
    readonly property color accent: "#ff3366"
    readonly property color pick: "#ffd93d"

    // Folded state belongs to the store, not here - the surface is rebuilt
    // with every engine, and a panel that unfolds itself on each hot reload is
    // a panel you fight.
    readonly property bool collapsed: ClayAnnotations.panelCollapsed

    // Local copy of the store. Re-read only at structural moments (open,
    // add, remove, clear) so typing in a note never tears down the field
    // being typed in.
    property var items: []
    property var regionItems: []
    // At most one of each, ever. Two selections would make "the other end" a
    // question rather than an answer.
    property string selectedId: ""
    property string hoveredId: ""
    property string sceneId: ""
    property bool wipeArmed: false
    // How many times the list actually moved. The scroll rule is "the card
    // being written in is always fully visible, and the list moves only when
    // it is not" - and the only way to hold the second half of that honest is
    // to be able to count the moves that did not need to happen.
    property int scrollCount: 0

    FontLoader { id: hand; source: "qrc:/clayground/fonts/Caveat.ttf" }

    // Picking one end of a pair. `reveal` is set when the pick came from the
    // scene, where the card may be scrolled out of sight; a pick made IN the
    // list needs no scrolling, because you were already looking at it.
    function selectAnnotation(id, reveal) {
        selectedId = id;
        if (reveal) revealCard(id);
    }

    function clearSelection() { selectedId = ""; }

    function setHovered(id, on) {
        if (on) hoveredId = id;
        else if (hoveredId === id) hoveredId = "";
    }

    function revealCard(id) {
        for (var i = 0; i < regionItems.length; ++i) {
            if (regionItems[i].id === id) {
                var card = noteRepeater.itemAt(i);
                if (card) notesFlick.ensureVisible(card);
                return;
            }
        }
    }

    // A card that has just been added - or has just grown another line - is not
    // yet where it is going to be: the delegate exists but the column lays out
    // on the next frame, so asking to scroll to it now measures a size and a
    // position it does not have. Every reveal that follows a layout change goes
    // through here. Selecting an existing frame needs none of it - nothing
    // moved - and a coalescing timer also means one scroll per burst of typing
    // rather than one per wrapped line.
    function revealCardLater(id) {
        revealLater.annId = id;
        revealLater.restart();
    }

    Timer {
        id: revealLater
        interval: 32
        property string annId: ""
        onTriggered: root.revealCard(annId)
    }

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
    }

    // Called from MainWindow when the surface is shown.
    function activate() {
        ClayAnnotations.reload();
        // Placeholders left behind by a run that ended without a close.
        ClayAnnotations.dropEmptyNotes();
        wipeArmed = false;
        // A session starts with nothing picked: the selection from last time
        // would be pointing at a scene you have since walked away from.
        selectedId = "";
        hoveredId = "";
        scrollCount = 0;
        sync();
        if (root.collapsed) root.forceActiveFocus();
        else sceneNote.focusEditor();
    }

    // Called from MainWindow right before the surface is hidden - the last
    // chance to get an unsaved keystroke into the store, and the moment a
    // frame nobody wrote on stops being feedback and becomes clutter.
    function deactivate() {
        commitAll();
        ClayAnnotations.dropEmptyNotes();
    }

    function commitAll() {
        sceneNote.commit();
        for (var i = 0; i < noteRepeater.count; ++i) {
            var c = noteRepeater.itemAt(i);
            if (c) c.commit();
        }
    }

    // Tab, the chevron, and the handle all land here. Whatever is half-typed
    // goes into the store first: folding the panel away takes the editor off
    // screen, and nothing typed may be lost to a keystroke about layout.
    function toggleCollapsed() {
        commitAll();
        ClayAnnotations.panelCollapsed = !ClayAnnotations.panelCollapsed;
        if (ClayAnnotations.panelCollapsed)
            root.forceActiveFocus();
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
        // A frame you cannot write on is not feedback: the panel comes back
        // out whenever a new region needs a note.
        ClayAnnotations.panelCollapsed = false;
        sync();
        selectedId = id;
        for (var i = 0; i < regionItems.length; ++i) {
            if (regionItems[i].id === id) {
                var card = noteRepeater.itemAt(i);
                if (card) card.focusEditor();
                break;
            }
        }
        revealCardLater(id);
    }

    function removeAnnotation(id) {
        commitAll();
        ClayAnnotations.removeAnnotation(id);
        sync();
    }

    focus: true

    Keys.onEscapePressed: root.closeRequested()
    // Tab is deliberately NOT handled here. Hiding a focused QQuickWidget makes
    // Qt synthesise a Tab into the offscreen window (hide_helper ->
    // focusNextPrevChild), so a QML-side Tab handler fires every time the
    // surface closes and silently undoes the fold. MainWindow owns the key.

    // A whisper of dim so the surface is visibly on without hiding the scene.
    Rectangle {
        anchors.fill: parent
        color: "#1e0a0a12"
    }

    // ---------------------------------------------------------------- scene
    // The full viewport, always. Every pixel the sandbox draws can be framed,
    // including the pixels the panel is floating over right now.
    Item {
        id: sceneArea
        objectName: "annotationSceneArea"
        anchors.fill: parent
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
                var isClick = (w < 24 || h < 24);
                // Empty scene, no drag, something picked: that is how you let
                // go of a pair. Esc is not available for it - Esc closes the
                // surface and always has. A drag always frames, and a click
                // with nothing picked frames too, so this costs a gesture only
                // when you are actually holding one.
                if (isClick && root.selectedId !== "") {
                    band.width = 0; band.height = 0;
                    root.clearSelection();
                    return;
                }
                // A plain click still gets you something grabbable - a
                // zero-size rect would be a marker you cannot take hold of.
                if (isClick) {
                    w = 150; h = 100;
                    x = mouse.x - w / 2; y = mouse.y - h / 2;
                }
                x = Math.max(0, Math.min(x, width - w));
                y = Math.max(0, Math.min(y, height - h));
                band.width = 0; band.height = 0;
                root.createRegion(x, y, w, h);
            }
        }

        Repeater {
            id: regionRepeater
            model: root.regionItems
            AnnotationRegion {
                objectName: "annotationRegion"
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
                baseColor: root.accent
                highlightColor: root.pick
                selected: root.selectedId === modelData.id
                hovered: root.hoveredId === modelData.id
                          && root.selectedId !== modelData.id
                // Picked from the scene, so the card may well be somewhere
                // down the list - this is the one direction that scrolls.
                onSelectRequested: root.selectAnnotation(modelData.id, true)
                onHoverRequested: function(on) { root.setHovered(modelData.id, on) }
                onGeometryEdited: ClayAnnotations.setRect(
                    annId, Qt.rect(x, y, width, height))
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

    // ----------------------------------------------------------------- dock
    // Handle plus panel, slid off to the right as one piece. Nothing here is
    // ever part of the scene's layout - it hovers.
    Item {
        id: dock
        objectName: "annotationDock"
        width: root.panelW + root.handleW
        height: root.dockH
        y: root.height - height
        x: root.collapsed ? root.width - root.handleW : root.width - width

        Behavior on x {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        // -------- the handle: the way back out, and the reminder ----------
        Rectangle {
            id: handle
            objectName: "annotationHandle"
            width: root.handleW
            height: 128
            y: (dock.height - height) / 2
            radius: 5
            color: "#d2141018"
            border.color: "#5500d9ff"
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.collapsed ? "❮" : "❯"
                    color: "#00d9ff"
                    font.pixelSize: 15
                    font.bold: true
                }

                // The count is what keeps a folded panel from becoming a
                // forgotten one.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 18
                    height: 18
                    radius: 9
                    color: ClayAnnotations.openCount > 0 ? root.accent : "#33ffffff"
                    Text {
                        anchors.centerIn: parent
                        text: ClayAnnotations.openCount
                        color: ClayAnnotations.openCount > 0 ? "#1a1010" : "#9aa0a6"
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "TAB"
                    color: "#6f7680"
                    font.family: "monospace"
                    font.pixelSize: 8
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleCollapsed()
            }
        }

        // ---------------------------------------------------------- panel
        Rectangle {
            id: panel
            x: root.handleW
            width: root.panelW
            height: dock.height
            // Translucent on purpose: the scene has to read through the notes
            // about it, and the bubbles carry their own paper so the text
            // stays legible whatever is underneath.
            color: "#c2141018"

            // Swallows anything the panel's own controls did not take. A press
            // that starts here must never end up framing a region - declared
            // first so every control below stays on top of it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
                cursorShape: Qt.ArrowCursor
                onWheel: function(wheel) { wheel.accepted = true }
            }

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
                    accent: root.accent
                    highlight: root.pick
                    onNoteCommitted: function(text) { root.commitSceneNote(text) }
                    onSubmitted: root.closeRequested()
                    // The subject moved to the whole scene, so no single frame
                    // is the one being talked about any more.
                    onSelectRequested: root.clearSelection()
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
                objectName: "annotationNotes"
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

                // Deliberately NOT a Behavior on contentY: that would animate
                // the wheel and the scrollbar too, and a list that lags your
                // own dragging is a list that feels broken.
                NumberAnimation {
                    id: scrollTo
                    target: notesFlick
                    property: "contentY"
                    duration: 170
                    easing.type: Easing.OutCubic
                }

                // Scroll ON DEMAND. If the card is already on screen this does
                // nothing at all: a list that jumps when nothing needed to
                // move costs you your place for no reason, which is worse than
                // one that never moves.
                function ensureVisible(item) {
                    var pad = 6;
                    var top = item.y - pad;
                    var bottom = item.y + item.height + pad;
                    var target = contentY;
                    if (bottom - top > height) {
                        // Taller than the list itself, so one end of it has to
                        // go over the edge. It is the top that goes: the caret
                        // is at the bottom, and a card you are writing in whose
                        // last line you cannot see is the whole complaint.
                        if (bottom < contentY || bottom > contentY + height)
                            target = bottom - height;
                    } else if (top < contentY) {
                        target = top;
                    } else if (bottom > contentY + height) {
                        target = bottom - height;
                    }
                    target = Math.max(0, Math.min(target,
                                                  Math.max(0, contentHeight - height)));
                    if (Math.abs(target - contentY) < 1.0) return;
                    root.scrollCount += 1;
                    scrollTo.stop();
                    scrollTo.to = target;
                    scrollTo.start();
                }

                ScrollBar.vertical: ScrollBar { }

                Column {
                    id: noteColumn
                    width: notesFlick.width
                    spacing: 8
                    // Room under the last card. The card being written in is
                    // almost always the last one, and a Flickable cannot scroll
                    // past its own content: without this the final card lands
                    // flush against the bottom edge and the next line typed
                    // goes straight under it.
                    bottomPadding: 6

                    Repeater {
                        id: noteRepeater
                        model: root.regionItems
                        AnnotationNote {
                            objectName: "annotationCard"
                            width: noteColumn.width
                            annId: modelData.id
                            idx: index
                            handFamily: hand.name
                            noteText: modelData.note
                            status: modelData.status
                            addressedNote: modelData.addressedNote
                            attached: modelData.attached
                            accent: root.accent
                            highlight: root.pick
                            placeholder: "what is wrong here?"
                            selected: root.selectedId === modelData.id
                            hovered: root.hoveredId === modelData.id
                                      && root.selectedId !== modelData.id
                            onNoteCommitted: function(text) {
                                ClayAnnotations.setNote(annId, text);
                            }
                            // Done with this one: the pair lets go, so the
                            // next click on the scene frames rather than
                            // deselects.
                            onSubmitted: {
                                root.clearSelection();
                                root.forceActiveFocus();
                            }
                            // Picked in the list, where it is by definition
                            // already visible - nothing to scroll to.
                            onSelectRequested: root.selectAnnotation(modelData.id,
                                                                    false)
                            // The card being written in is a different matter:
                            // it has to stay whole on screen from the moment it
                            // takes the cursor, and again every time another
                            // wrapped line makes it taller.
                            onRevealRequested: root.revealCardLater(annId)
                            onHoverRequested: function(on) {
                                root.setHovered(modelData.id, on);
                            }
                            onRemoveRequested: root.removeAnnotation(annId)
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
                    text: "Ctrl+F  close   ·   Esc  close   ·   Tab  fold panel"
                    color: "#6f7680"; font.family: "monospace"; font.pixelSize: 10
                }
                Text {
                    text: "drag  frame   ·   click  rect   ·   Enter  save"
                    color: "#6f7680"; font.family: "monospace"; font.pixelSize: 10
                }
                // The one line that changes: holding a pick is the only state
                // in which clicking the empty scene means something other than
                // framing, so it is the only state that says so. Four lines
                // either way - the list is short enough already.
                Text {
                    text: root.selectedId !== ""
                          ? "click empty scene  ·  drop the pick"
                          : "click a frame or its card  ·  they pair"
                    color: root.selectedId !== "" ? "#ffd93d" : "#6f7680"
                    font.family: "monospace"; font.pixelSize: 10
                }
                Text {
                    text: "Ctrl+Shift+F  clear addressed"
                    color: "#6f7680"; font.family: "monospace"; font.pixelSize: 10
                }
            }
        }
    }

    // The store changes under us when an agent marks something addressed. A
    // generation bump rebuilds every card, so whatever was half-typed goes in
    // first - a hot reload must not eat a remark in progress.
    Connections {
        target: ClayAnnotations
        function onGenerationChanged() { root.commitAll(); root.sync() }
    }
}
