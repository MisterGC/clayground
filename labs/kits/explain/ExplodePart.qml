// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

// One piece of an exploded assembly: the Models that draw the piece, plus the
// four facts a view and a lesson need about it - where it travels at full
// spread, where a fingertip or a ring lands on it, when it gets explained, and
// what it is made of.
//
// The piece keeps its DECLARED `position` as the assembled pose: the owning
// ExplodedView3D captures it into \l basePosition on completion and writes
// `position` itself from then on. That way the assembled scene is authored in
// plain coordinates - the same numbers the circuit kit's part uses - and the
// animation is not a binding every part has to carry a copy of.
//
// \l anchor exists because a mark must not land at the piece's origin: a
// Box3D's origin is its BOTTOM-centre, so a ring there sits inside whatever is
// underneath. The anchor is a real child Node, so its scene position is Qt's
// answer to "where is that point now", not arithmetic of ours that would have
// to be kept in step with every parent transform.
Node {
    id: root

    /*! Which piece this is - an authoring token (\c die.base), identical in
        every language, and the name every mechanism in the kit refers to it
        by. */
    property string partId: ""

    /*! The whole displacement the piece takes at spread 1, in the assembly's
        local units. */
    property vector3d offset: Qt.vector3d(0, 0, 0)

    /*! The local point a mark, a leader line or a fingertip lands on. Defaults
        to the piece's own origin. */
    property vector3d anchor: Qt.vector3d(0, 0, 0)

    /*! Position in the lesson, 1-based. 0 means the piece is drawn but never
        explained on its own (the silkscreen, the header). */
    property int order: 0

    /*! What the piece is made of, as a role name from \c anatomy.js. The view
        does not read it; the subject file colours by it. */
    property string role: ""

    /*! The assembled pose, captured from the authored \c position on
        completion. The view adds the spread displacement to this. */
    property vector3d basePosition: Qt.vector3d(0, 0, 0)

    /*! Which piece the view is focused on, written by the owning
        ExplodedView3D. Empty means nothing is focused. */
    property string focusId: ""

    /*! How far a piece fades when some OTHER piece is focused. */
    property real dimOpacity: 0.25

    /*! True while another piece holds the focus. */
    readonly property bool dimmed: root.focusId !== "" && root.focusId !== root.partId

    /*! A second, independent opacity factor - what the transistor's x-ray
        drives on the epoxy. Kept apart from focus dimming so a subject can set
        one without silently overriding the other. */
    property real ghost: 1.0

    opacity: (root.dimmed ? root.dimOpacity : 1.0) * root.ghost

    /*! \l anchor in SCENE coordinates - what a mark or a fingertip is given. */
    readonly property vector3d anchorScene: _anchor.scenePosition

    // Copied component-wise on purpose: a vector3d read off a property is a
    // live reference to that property, so holding `root.position` here would
    // hold whatever the view writes next rather than the authored pose.
    Component.onCompleted: root.basePosition = Qt.vector3d(root.position.x,
                                                           root.position.y,
                                                           root.position.z)

    Node { id: _anchor; position: root.anchor }
}
