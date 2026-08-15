// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype WorldLabel
    \inqmlmodule Clayground.Lab
    \brief A 2D chip pinned to a point in a 3D scene.

    The overlay every 3D lab grows by hand: project a world point to the
    window, park a small paper panel next to it, keep it inside the viewport
    and hide it when it goes behind the camera. Put one in the same parent as
    the \l View3D (not inside it - this is a QtQuick item, not a 3D node).

    Use \l text for a one-line readout, or give it children for anything
    richer; the chip sizes itself either way.

    \note The projection lists \c camera.scenePosition and
    \c camera.sceneRotation as explicit dependencies. Without them the
    binding never re-evaluates when the camera moves and every label freezes
    in place - invisible with a static camera, which is exactly why this
    is easy to get wrong.

    Example usage:
    \qml
    import Clayground.Lab

    Item {
        View3D { id: view; anchors.fill: parent; camera: cam }

        WorldLabel {
            view: view
            camera: cam
            worldPosition: Qt.vector3d(0, 4, 0)
            text: "12.4 A"
            accent: LabTheme.forest
        }
    }
    \endqml

    \sa LabTheme, Plot2D
*/
Rectangle {
    id: root

    /*!
        \qmlproperty enumeration WorldLabel::placement
        \brief Where the chip sits relative to the projected point.

        \value WorldLabel.Above   above the point (the default)
        \value WorldLabel.Below   below it
        \value WorldLabel.Centered  centred on it
    */
    enum Placement { Above, Below, Centered }

    /*!
        \qmlproperty var WorldLabel::view
        \brief The View3D to project through.

        Deliberately \c var, not \c View3D: typing it would make
        \c Clayground.Lab import QtQuick3D for one property, and the kernel
        should not need a 3D dependency to draw a paper chip.
    */
    property var view: null

    /*!
        \qmlproperty var WorldLabel::camera
        \brief The camera that View3D renders with.
    */
    property var camera: null

    /*!
        \qmlproperty vector3d WorldLabel::worldPosition
        \brief The scene point to pin to.
    */
    property vector3d worldPosition: Qt.vector3d(0, 0, 0)

    /*!
        \qmlproperty int WorldLabel::placement
        \brief See \l Placement.
    */
    property int placement: WorldLabel.Above

    /*!
        \qmlproperty real WorldLabel::gap
        \brief Pixels between the point and the chip.
    */
    property real gap: LabTheme.spaceM

    /*!
        \qmlproperty point WorldLabel::offset
        \brief Extra pixel nudge, applied after placement.
    */
    property point offset: Qt.point(0, 0)

    /*!
        \qmlproperty bool WorldLabel::keepInView
        \brief Keeps the chip inside its parent instead of letting it leave.

        Zoom in far enough and the anchor point sits well outside the window;
        a readout that vanished then would look like a bug rather than a
        viewpoint.
    */
    property bool keepInView: true

    /*!
        \qmlproperty real WorldLabel::margin
        \brief Closest the chip may come to the window edge.
    */
    property real margin: LabTheme.spaceS

    /*!
        \qmlproperty string WorldLabel::text
        \brief Convenience one-line content.
    */
    property string text: ""

    /*!
        \qmlproperty color WorldLabel::accent
        \brief Border colour - use it to carry meaning.
    */
    property color accent: LabTheme.panelEdge

    /*!
        \qmlproperty bool WorldLabel::active
        \brief Set false to hide without unloading.
    */
    property bool active: true

    /*!
        \qmlproperty bool WorldLabel::onScreen
        \readonly
        \brief Whether the anchor point is in front of the camera.
    */
    readonly property bool onScreen: _screen.z > 0

    /*!
        \qmlproperty var WorldLabel::contentItem
        \readonly
        \brief The item children are parented to.
    */
    readonly property alias contentItem: _content

    default property alias _children: _content.data

    readonly property vector3d _screen: {
        if (!root.view || !root.camera) return Qt.vector3d(0, 0, -1)
        // mapFrom3DScene projects to PIXELS, so all four of these change the
        // result while the function body names none of them. The camera pair
        // tracks orbiting; the size pair tracks window resizes AND the initial
        // layout — without it a label projected while the View3D is still 0x0
        // stays at (0,0) until something moves the camera.
        root.camera.scenePosition
        root.camera.sceneRotation
        root.view.width
        root.view.height
        return root.view.mapFrom3DScene(root.worldPosition)
    }

    visible: root.active && root.onScreen
    implicitWidth: (root.text !== "" ? _label.implicitWidth : _content.childrenRect.width) + LabTheme.spaceXxl
    implicitHeight: (root.text !== "" ? _label.implicitHeight : _content.childrenRect.height) + LabTheme.px(10)
    width: implicitWidth
    height: implicitHeight

    x: {
        var v = root._screen.x - width / 2 + root.offset.x
        if (!root.keepInView || !parent) return v
        return Math.max(root.margin,
                        Math.min(parent.width - width - root.margin, v))
    }
    y: {
        var v = root._screen.y + root.offset.y
        if (root.placement === WorldLabel.Above) v -= height + root.gap
        else if (root.placement === WorldLabel.Below) v += root.gap
        else v -= height / 2
        if (!root.keepInView || !parent) return v
        return Math.max(root.margin,
                        Math.min(parent.height - height - root.margin, v))
    }

    radius: LabTheme.radius
    color: LabTheme.panel
    border.color: root.accent
    border.width: LabTheme.borderWidth
    opacity: 0.95

    Item {
        id: _content
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
        visible: root.text === ""
    }

    Text {
        id: _label
        anchors.centerIn: parent
        visible: root.text !== ""
        text: root.text
        color: LabTheme.ink
        font.pixelSize: LabTheme.fontBody
        font.bold: true
        font.family: LabTheme.monoFont
    }
}
