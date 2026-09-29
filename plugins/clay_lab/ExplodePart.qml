// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype ExplodePart
    \inqmlmodule Clayground.Lab
    \ingroup lab-flow
    \brief One named piece of an \l ExplodedView3D: the models that draw it, plus its row of the part table.

    A part is a \c Node holding the Models of one piece, and the facts a view
    and a lesson need about it: which piece it is (\l partId), where it
    travels (\l offset, in which \l stage), where a mark or a fingertip lands
    on it (\l anchor), when it is explained (\l order) and what it is made
    of (\l role). Those facts are the part table; a subject keeps them in a
    Qt-free file beside its models and hands each part its \l row, so the
    table can be checked by \c node before a Model is built from it.

    The part keeps its DECLARED \c position as the assembled pose: the owning
    view captures it into \l basePosition on completion and writes \c position
    itself from then on. That way the assembled scene is authored in plain
    coordinates - the same numbers the circuit kit's part uses - and the
    animation is not a binding every part has to carry a copy of.

    A part may contain parts: a sub-assembly that comes off as a whole in
    one stage and then comes apart in the next. Its children's offsets are
    relative to it.

    \l anchor exists because a mark must not land at the piece's origin: a
    \c Box3D's origin is its bottom-centre, so a ring there sits inside
    whatever is underneath. The anchor is a real child Node, so its scene
    position is Qt's answer to "where is that point now", not arithmetic that
    would have to be kept in step with every parent transform.

    \qml
    ExplodePart {
        row: Anatomy.partById("case")       // id, offset, anchor, order, stage, role
        position: Qt.vector3d(0, 1.55, -0.35)
        Model { source: "#Cylinder"; ... }
    }
    \endqml

    \sa ExplodedView3D, MarkLayer
*/
Node {
    id: root

    /*!
        \qmlproperty string ExplodePart::partId
        \brief Which piece this is - an authoring token (\c die.base),
        identical in every language, and the name every mechanism refers to
        it by.
    */
    property string partId: ""

    /*!
        \qmlproperty vector3d ExplodePart::offset
        \brief The whole displacement the piece takes at the end of its
        \l stage, in the frame of whatever it sits in.
    */
    property vector3d offset: Qt.vector3d(0, 0, 0)

    /*!
        \qmlproperty vector3d ExplodePart::anchor
        \brief The local point a mark, an assembly line or a fingertip lands
        on. Defaults to the piece's own origin.
    */
    property vector3d anchor: Qt.vector3d(0, 0, 0)

    /*!
        \qmlproperty int ExplodePart::order
        \brief Place in the lesson, 1-based. 0 means the piece is drawn but
        never explained on its own (the silkscreen, the header).
    */
    property int order: 0

    /*!
        \qmlproperty int ExplodePart::stage
        \brief Which interval of the view's \c spread moves this piece: 1
        travels while spread goes 0 to 1, 2 while it goes 1 to 2. The shell
        comes off first, then what is inside.
    */
    property int stage: 1

    /*!
        \qmlproperty string ExplodePart::role
        \brief What the piece is made of, as a role name from the subject's
        table. The view does not read it; the subject colours by it.
    */
    property string role: ""

    /*!
        \qmlproperty var ExplodePart::row
        \brief The part's row of the table: \c {id, offset, anchor, order,
        stage, role}, plain numbers. Every field the row names is copied into
        the property of that name; fields the row lacks keep what the part
        declares. Set it and the piece IS that row.
    */
    property var row: null

    /*!
        \qmlproperty real ExplodePart::ghost
        \brief A second, independent opacity factor - what an x-ray drives on
        a shell. Kept apart from focus dimming so a subject can set one
        without silently overriding the other.
    */
    property real ghost: 1.0

    /*!
        \qmlproperty vector3d ExplodePart::basePosition
        \brief The assembled pose, captured from the authored \c position on
        completion. The view adds the displacement to this.
    */
    property vector3d basePosition: Qt.vector3d(0, 0, 0)

    /*!
        \qmlproperty vector3d ExplodePart::displacement
        \brief Where the piece is relative to its assembled pose right now,
        in its own frame. Written by the owning \l ExplodedView3D.
    */
    property vector3d displacement: Qt.vector3d(0, 0, 0)

    /*!
        \qmlproperty bool ExplodePart::dimmed
        \brief True while some other piece holds the focus. Written by the
        owning \l ExplodedView3D.
    */
    property bool dimmed: false

    /*!
        \qmlproperty real ExplodePart::fade
        \brief How far a dimmed piece has faded, 0 (not at all) to
        \c {1 - dimOpacity}. Written by the owning \l ExplodedView3D as its
        \c focusNow eases.
    */
    property real fade: 0

    /*!
        \qmlproperty vector3d ExplodePart::anchorScene
        \brief \l anchor in scene coordinates, where the piece is now - what a
        mark or a fingertip is given.
    */
    readonly property vector3d anchorScene: _anchor.scenePosition

    /*!
        \qmlproperty vector3d ExplodePart::assembledScene
        \brief \l anchor in scene coordinates as if the piece were back in its
        assembled pose - the other end of its assembly line. Moves with the
        parent the piece sits in.
    */
    readonly property vector3d assembledScene: _assembled.scenePosition

    opacity: (root.dimmed ? 1 - root.fade : 1) * root.ghost

    onRowChanged: root._applyRow()

    // The row first, then the pose: a row never carries a position (the
    // assembled pose is geometry, authored beside the models it has to
    // match), so the order only matters for keeping both in one place.
    // Copied component-wise on purpose: a vector3d read off a property is a
    // live reference to that property, so holding `root.position` here would
    // hold whatever the view writes next rather than the authored pose.
    Component.onCompleted: {
        root._applyRow()
        root.basePosition = Qt.vector3d(root.position.x, root.position.y, root.position.z)
    }

    function _applyRow() {
        const r = root.row
        if (!r) return
        if (r.id !== undefined) root.partId = String(r.id)
        if (r.offset) root.offset = Qt.vector3d(r.offset.x || 0, r.offset.y || 0, r.offset.z || 0)
        if (r.anchor) root.anchor = Qt.vector3d(r.anchor.x || 0, r.anchor.y || 0, r.anchor.z || 0)
        if (r.order !== undefined) root.order = r.order
        if (r.stage !== undefined) root.stage = r.stage
        if (r.role !== undefined) root.role = String(r.role)
    }

    Node { id: _anchor; position: root.anchor }
    Node {
        id: _assembled
        position: Qt.vector3d(root.anchor.x - root.displacement.x,
                              root.anchor.y - root.displacement.y,
                              root.anchor.z - root.displacement.z)
    }
}
