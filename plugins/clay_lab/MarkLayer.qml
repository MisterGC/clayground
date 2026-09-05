// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick
import Clayground.Lab

/*!
    \qmltype MarkLayer
    \inqmlmodule Clayground.Lab
    \brief Rings on the world points something is naming right now.

    A presenter saying "collector on the left, emitter on the right, base
    facing you" is asking the eye to find three things by ear. This is the
    other half of that sentence: a ring on each of them, up while the line
    lasts and gone afterwards.

    It draws \l marks and nothing else. Where they come from is the caller's
    business - a \c{*mark ...*} cue in a performance script
    (\c Performance.marks), a \c {FlowStep.mark} field, or a lab pointing at
    its own selection. Each entry is a world point, either a \c vector3d or
    \c {{ at: vector3d, label: string }}; a label draws a small chip under
    the ring, and no label draws the ring alone.

    Screen space over the 3D scene, like \l WorldLabel and \l BoardOverlay:
    put it in the same parent as the \c View3D, not inside it.

    \qml
    import Clayground.Lab

    MarkLayer {
        anchors.fill: parent
        view: view3d
        camera: rig.camera
        marks: guide.markPoints
        keepOut: root.presenterBox
    }
    \endqml

    \note The projection lists \c camera.scenePosition and
    \c camera.sceneRotation as explicit dependencies. Without them the marks
    freeze where the camera first saw them - invisible until the rig moves,
    which is the one thing a mark has to survive.

    \sa WorldLabel, BoardOverlay, Flow, FlowStep
*/
Item {
    id: root

    /*!
        \qmlproperty var MarkLayer::view
        \brief The \c View3D to project through.

        \c var rather than \c View3D on purpose: the kernel should not import
        QtQuick3D to park a ring on a pixel.
    */
    property var view: null

    /*! \qmlproperty var MarkLayer::camera \brief The camera the \l view renders with. */
    property var camera: null

    /*!
        \qmlproperty var MarkLayer::marks
        \brief What to ring: world points, each a \c vector3d or \c {{at, label}}.

        Empty draws nothing. Replacing the list is the whole of the API -
        there is no add/remove, because a mark set belongs to one sentence
        and outliving it is the failure mode.
    */
    property var marks: []

    /*!
        \qmlproperty var MarkLayer::keepOut
        \brief A screen rectangle (\c {{x, y, width, height}}) no mark is drawn
               into, or null.

        Same rule and the same shape as \l {BoardOverlay::keepOut}. A ring is
        screen space over a 3D scene, so nothing depth-tests it against a
        presenter standing in front of the part: a ring drawn on the coat
        marks the coat. A mark whose point falls inside the box fades out
        for as long as it does.
    */
    property var keepOut: null

    /*! \qmlproperty color MarkLayer::tone \brief The ring colour. */
    property color tone: LabTheme.highlight

    /*! \qmlproperty real MarkLayer::ringSize \brief Ring diameter at rest, in px. */
    property real ringSize: LabTheme.px(34)

    /*!
        \qmlproperty int MarkLayer::pulseMs
        \brief Period of the halo that expands out of each ring; 0 draws none.

        The halo is what makes a ring read as "this one, now" rather than as
        another piece of chrome. It is decoration, so it is the first thing a
        lab turns off.
    */
    property int pulseMs: 1400

    /*! \qmlproperty int MarkLayer::count \readonly \brief How many marks are up. */
    readonly property int count: _points.length

    /*!
        \qmlmethod var MarkLayer::screenOf(int i)
        \brief Where mark \a i lands, as \c {{x, y, z}}; \c z <= 0 is behind the camera.

        The verification seam: a claim about a mark is checked by asking
        where it is, not by looking at a picture.
    */
    function screenOf(i) {
        if (i < 0 || i >= _points.length) return Qt.vector3d(0, 0, 0)
        return _project(_points[i].at)
    }

    /*! \qmlmethod bool MarkLayer::clear(real sx, real sy) \brief Is this screen point outside \l keepOut? */
    function clear(sx, sy) {
        const k = root.keepOut
        if (!k) return true
        return sx < k.x || sx > k.x + k.width || sy < k.y || sy > k.y + k.height
    }

    // Both accepted spellings normalized to one: { at, label }. Entries
    // without a usable point are dropped here rather than drawn at the origin,
    // which is what an unresolved name used to look like on screen.
    readonly property var _points: {
        const out = []
        const src = root.marks || []
        for (let i = 0; i < src.length; ++i) {
            const m = src[i]
            if (!m) continue
            const at = (m.at !== undefined) ? m.at : m
            if (!at || at.x === undefined) continue
            out.push({ at: at, label: (m.label === undefined || m.label === null) ? "" : "" + m.label })
        }
        return out
    }

    function _project(p) {
        if (!view || !p) return Qt.vector3d(0, 0, 0)
        return view.mapFrom3DScene(p)
    }

    Repeater {
        model: root._points

        Item {
            id: mark
            // Named so a headless render can pick the marks out of the
            // overlay without counting anonymous children.
            objectName: "mark"
            required property var modelData
            required property int index

            readonly property var screenAt: {
                // The dependencies that make a mark survive the camera moving.
                if (!root.camera) return Qt.vector3d(0, 0, 0)
                root.camera.scenePosition; root.camera.sceneRotation
                return root._project(mark.modelData.at)
            }
            readonly property bool shown: screenAt.z > 0
                                          && root.clear(screenAt.x, screenAt.y)

            x: screenAt.x
            y: screenAt.y
            width: 0
            height: 0
            visible: opacity > 0.001
            opacity: shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // The halo: one ring expanding out of the mark and fading, so a
            // mark that comes up while the reader is looking elsewhere still
            // catches the eye.
            Rectangle {
                id: halo
                anchors.centerIn: parent
                width: root.ringSize; height: width
                radius: width / 2
                color: "transparent"
                border.color: root.tone
                border.width: Math.max(1, LabTheme.px(2))
                visible: root.pulseMs > 0 && mark.shown
                SequentialAnimation {
                    running: halo.visible
                    loops: Animation.Infinite
                    ParallelAnimation {
                        NumberAnimation { target: halo; property: "scale"
                                          from: 1.0; to: 2.1
                                          duration: root.pulseMs
                                          easing.type: Easing.OutCubic }
                        NumberAnimation { target: halo; property: "opacity"
                                          from: 0.55; to: 0
                                          duration: root.pulseMs
                                          easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                id: ring
                anchors.centerIn: parent
                width: root.ringSize; height: width
                radius: width / 2
                color: "transparent"
                border.color: root.tone
                border.width: Math.max(2, LabTheme.px(3))
                scale: mark.shown ? 1 : 0.6
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            }

            // The name, when the caller supplies one - "collector" under the
            // ring on the collector. Under, not over: the ring is on the part
            // and the chip must not cover what it is naming.
            Rectangle {
                id: chip
                visible: mark.modelData.label !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: ring.bottom
                anchors.topMargin: LabTheme.px(4)
                width: chipText.implicitWidth + LabTheme.spaceL
                height: chipText.implicitHeight + LabTheme.spaceS
                radius: LabTheme.px(4)
                color: LabTheme.panel
                border.color: root.tone
                border.width: Math.max(1, LabTheme.px(1.5))
                opacity: 0.96
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: mark.modelData.label
                    color: LabTheme.ink
                    font.pixelSize: LabTheme.fontSmall
                    font.bold: true
                    font.family: LabTheme.monoFont
                }
            }
        }
    }
}
