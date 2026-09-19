// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

// A generic exploded assembly: a Node whose ExplodePart children slide out
// along their own offsets as `spread` goes 0 -> 1, and slide back.
//
// Nothing in this file knows what the assembly is, and that is the point. The
// subject is a file of ExplodePart declarations (TransistorAnatomy3D); the
// mechanism - the glide, the focus dimming, the teaching order, where a mark
// lands - is here, and a lab about a gearbox or a cell reuses it unchanged.
//
// Goal and interpolant are two properties (the kit's rule 1): `spread` is what
// a flow step sets and an `expect` asserts, `spreadNow` is what the frame
// draws. Lab.runFlow() steps sim time without an event loop, so an interpolant
// can never be asserted headless - only the goal can.
//
// The parts are moved IMPERATIVELY, from one handler, rather than by each part
// binding its own position to the view. A part authored with a plain
// `position: Qt.vector3d(0, 1.55, -0.35)` is readable next to the component it
// has to match silhouettes with; the same part written as an offset arithmetic
// binding is not.
Node {
    id: root

    /*! The goal: 0 assembled, 1 fully exploded. */
    property real spread: 0

    /*! Scales every part's offset - how far apart "fully exploded" is. */
    property real unit: 1.0

    /*! Part id to focus on. Every other part fades to \l dimOpacity. Empty
        means nothing is focused and all parts are drawn fully. */
    property string focus: ""

    /*! How far an unfocused part fades. */
    property real dimOpacity: 0.25

    /*! How long \l spreadNow takes to reach \l spread. */
    property int glideMs: 900

    /*! The interpolant \l spread eases toward. */
    readonly property real spreadNow: _glide.value

    /*! True while anything is still moving. */
    readonly property bool animating: Math.abs(_glide.value - root.spread) > 1e-4
                                      || root.otherAnimating

    /*! For a subject that adds a second glide of its own (the transistor's
        x-ray): bind this and \l animating covers it too. */
    property bool otherAnimating: false

    /*! Every ExplodePart's id, in child order. */
    readonly property var partIds: root._ids

    /*! The parts themselves, in child order. */
    readonly property var parts: root._parts

    /*!
        The part's \c anchor in scene coordinates as it is NOW - assembled pose
        plus the current displacement - for a fingertip or a ring. An unknown
        id answers Qt.vector3d(NaN, NaN, NaN) rather than throwing, because a
        lesson naming a part that a subject does not have should show up as a
        mark that cannot be placed, not as a broken flow.
    */
    function partAt(id) {
        const p = root.partOf(id)
        if (!p) return Qt.vector3d(NaN, NaN, NaN)
        // Copied: a vector3d handed straight out is a live reference to the
        // property it came from, so two calls would answer the same object.
        const v = p.anchorScene
        return Qt.vector3d(v.x, v.y, v.z)
    }

    /*! The part with this id, or null. */
    function partOf(id) {
        for (let i = 0; i < root._parts.length; ++i)
            if (root._parts[i].partId === id) return root._parts[i]
        return null
    }

    /*! The ids a lesson walks: every part with \c order > 0, ascending. */
    function idsInOrder() {
        const withOrder = []
        for (let i = 0; i < root._parts.length; ++i)
            if (root._parts[i].order > 0) withOrder.push(root._parts[i])
        withOrder.sort((a, b) => a.order - b.order)
        return withOrder.map(p => p.partId)
    }

    // --- internals -----------------------------------------------------------

    property var _parts: []
    property var _ids: []

    // The interpolant lives in its own object so `spreadNow` can stay readonly
    // and the Behavior has a plain, writable property to intercept. A Behavior
    // on a binding-driven property animates binding updates too, which is why
    // assigning `spread` is all a caller ever has to do.
    QtObject {
        id: _glide
        property real value: root.spread
        Behavior on value {
            NumberAnimation { duration: root.glideMs; easing.type: Easing.InOutCubic }
        }
        onValueChanged: root._applyPose()
    }

    onUnitChanged: root._applyPose()
    onFocusChanged: root._applyFocus()
    onDimOpacityChanged: root._applyFocus()

    Component.onCompleted: root._collect()

    // Parts are found by walking the children for a duck-typed marker rather
    // than by type. A `default property list<ExplodePart>` would NOT parent the
    // parts into the 3D scene - they would never be drawn - and a type check
    // would refuse a subclass of ExplodePart that a subject might want.
    function _collect() {
        const found = []
        const walk = (n) => {
            const cs = n.children
            for (let i = 0; i < cs.length; ++i) {
                const c = cs[i]
                if (c.partId !== undefined && c.offset !== undefined
                        && c.basePosition !== undefined) found.push(c)
                else walk(c)
            }
        }
        walk(root)
        root._parts = found
        const ids = []
        for (let i = 0; i < found.length; ++i) ids.push(found[i].partId)
        root._ids = ids
        root._applyPose()
        root._applyFocus()
    }

    function _applyPose() {
        const s = _glide.value * root.unit
        for (let i = 0; i < root._parts.length; ++i) {
            const p = root._parts[i]
            const b = p.basePosition
            const o = p.offset
            p.position = Qt.vector3d(b.x + o.x * s, b.y + o.y * s, b.z + o.z * s)
        }
    }

    function _applyFocus() {
        for (let i = 0; i < root._parts.length; ++i) {
            root._parts[i].dimOpacity = root.dimOpacity
            root._parts[i].focusId = root.focus
        }
    }
}
