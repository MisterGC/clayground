// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// DetailedHand - four fingers and a thumb on the end of a character's arm.
//
// This exists for one reason. The plugin's hand is a single box, so a
// professor pointing at something high and far away is a body with a straight
// limb sticking out of it - a silhouette that reads as a fascist salute. A
// bent elbow (PointAnim's half of the fix) breaks the straight line; an
// EXTENDED INDEX FINGER is what says the gesture is aimed at a thing. Between
// them there is nothing left of the salute.
//
// So legibility beats anatomy everywhere the two disagree. The index is both
// the longest and the thickest finger here, which no hand is, and the other
// three are stubbier than a hand's so they fold away to nothing in the fist -
// all of it so that the one thing left projecting from the outline is the
// finger. Measured on the bench: it still reads as an extended finger with the
// whole figure about 120 px tall, and stops reading below roughly 90 px.
//
// Everything is measured off the arm's own handWidth/handHeight/handDepth, so
// dragging the professor's proportions around keeps the hand on the wrist and
// in proportion. Nothing here is in world units.
//
// It attaches to the arm's WRIST JOINT and treats the plugin's existing block
// hand as the palm: the knuckle line sits on that box's far face. Leave
// handWidth/handHeight/handDepth alone and there is one hand, not two.

import QtQuick
import QtQuick3D
import Clayground.Character3D

pragma ComponentBehavior: Bound

Node {
    id: root

    /*! The Arm to attach to, e.g. character.rightArm. null leaves it inert. */
    property var arm: null

    /*! "relax" (default), "point", "thumbsUp" or "open". */
    property string pose: "relax"

    /*! Skin. Follows the arm's own hand colour unless overridden. */
    property color tone: root._arm ? root._arm.handColor : "#d38d5f"

    /*! How long a pose change takes, in ms. */
    property real settleMs: 220

    /*! Set on the left hand, so the thumb ends up on the other side. */
    property bool mirrored: false

    // --- what it hangs off ---------------------------------------------------

    readonly property var _arm: (root.arm !== null && root.arm !== undefined) ? root.arm : null

    parent: root._arm ? root._arm.hand : null
    visible: root._arm !== null

    // The palm, as Arm.qml builds it: a box hanging off the wrist joint from
    // y = 0 down to y = -handHeight, full width and depth at the far end.
    readonly property real _pw: root._arm ? root._arm.handWidth : 0
    readonly property real _ph: root._arm ? root._arm.handHeight : 0
    readonly property real _pd: root._arm ? root._arm.handDepth : 0

    // Which edge of the palm the thumb and the index share. Default is the
    // -X edge, which on Character's rightArm (the plugin puts it at +X) is the
    // edge facing the body. That is where a thumb belongs here: the palm has
    // no wrist roll available to it and so always faces backwards at rest, and
    // a backwards-facing palm puts its thumb inboard. Seen from above with
    // both arms forward the two thumbs then point at each other, which is what
    // a pair of hands does; outboard thumbs read as two left hands.
    readonly property real _side: root.mirrored ? 1 : -1

    // Fingers grow from just inside the palm's far face, so the joint is a
    // fold rather than a gap.
    readonly property real _knuckle: -root._ph * 0.97

    // --- the pose ------------------------------------------------------------
    // i/m/r/l are per-finger curl, 0 straight and 1 folded into the palm.
    // sp is how far the four fan apart. The thumb needs three of its own,
    // because tucking it and standing it up are different rotations and the
    // poses do not agree on either: tx folds it across the front of the palm
    // (negative stands it off the back), tz swings it out from the hand's
    // side, tc curls the thumb itself.

    readonly property var _p: {
        if (root.pose === "point")
            return { i: 0.00, m: 1.00, r: 1.00, l: 1.00, sp: 0.00,
                     tx: 55, tz: -62, tc: 0.20 }
        // The thumb goes OUT along the side of the fist, not up off the back
        // of it. A thumb swings in the plane of its own palm; standing one on
        // the back of the hand is a joint nobody has, and it looks like one.
        // What makes it point at the sky is the wrist rolling a quarter turn -
        // see the thumbsUp pose in PointAnim, which is where that lives.
        if (root.pose === "thumbsUp")
            return { i: 1.00, m: 1.00, r: 1.00, l: 1.00, sp: 0.00,
                     tx: -12, tz: 84, tc: 0.00 }
        if (root.pose === "open")
            return { i: 0.00, m: 0.00, r: 0.00, l: 0.00, sp: 1.00,
                     tx: -6, tz: 34, tc: 0.00 }
        // The index is curled hardest of the four at rest, against the way a
        // hand actually relaxes: it is the long one, and left barely bent it
        // reads as a limp point rather than as a hand doing nothing.
        return { i: 0.40, m: 0.44, r: 0.50, l: 0.56, sp: 0.25,
                 tx: 20, tz: 26, tc: 0.28 }
    }

    // Held as animatable reals rather than read straight out of _p: a pose is
    // a destination, and the hand has to be caught mid-fold as well as at rest.
    property real _ci: root._p.i
    property real _cm: root._p.m
    property real _cr: root._p.r
    property real _cl: root._p.l
    property real _sp: root._p.sp
    property real _tx: root._p.tx
    property real _tz: root._p.tz
    property real _tc: root._p.tc

    Behavior on _ci { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _cm { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _cr { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _cl { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _sp { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _tx { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _tz { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _tc { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }

    // --- how the four are packed ---------------------------------------------

    readonly property real _gap: root._pw * 0.015
    readonly property real _w0: root._pw * 0.46   // index - deliberately the fat one
    readonly property real _w1: root._pw * 0.26
    readonly property real _w2: root._pw * 0.23
    readonly property real _w3: root._pw * 0.20   // little

    // The thumb is the thickest thing on the hand, which is true of a real one
    // and doubly worth having here: in a thumbs-up it is the entire gesture,
    // and a thumb no fatter than a finger reads as a fifth finger standing up.
    readonly property real _wt: root._pw * 0.54

    // Packed side by side and centred on the palm rather than fitted inside
    // it: the four together come out a little wider than the palm box, which
    // is what a fist does and what keeps the index thick enough to see.
    readonly property real _span: root._w0 + root._w1 + root._w2 + root._w3
                                  + 3 * root._gap
    readonly property real _x0: root._side * (root._span * 0.5 - root._w0 * 0.5)
    readonly property real _x1: root._side * (root._span * 0.5 - root._w0 - root._gap
                                              - root._w1 * 0.5)
    readonly property real _x2: root._side * (root._span * 0.5 - root._w0 - root._w1
                                              - 2 * root._gap - root._w2 * 0.5)
    readonly property real _x3: root._side * (root._span * 0.5 - root._w0 - root._w1
                                              - root._w2 - 3 * root._gap - root._w3 * 0.5)

    // The index is a little longer than the palm, and only a little: it was
    // half as long again for a while, bought by a distance-readability test
    // and paid for in a finger that read as a spike from any close angle.
    // Thickness carries the same distance at a fraction of the cost to the
    // shape, which is why _w0 is the fat one.
    //
    // The other three are SHORTER than a hand's, for a reason from the other
    // end: a folded finger longer than the palm is deep cannot tuck, and the
    // fist comes out a loose claw with three spare things in the outline
    // competing with the one that carries the meaning.
    readonly property real _l0: root._ph * 1.15   // index
    readonly property real _l1: root._ph * 0.90
    readonly property real _l2: root._ph * 0.80
    readonly property real _l3: root._ph * 0.66

    // How far the fan opens, per step away from the index.
    readonly property real _fan: 7

    /*!
        Where the extended index finger ends, in the wrist joint's own frame -
        the point a lab should aim, and the point a bench should measure.
        Only meaningful while the index is straight.
    */
    readonly property vector3d indexTip: Qt.vector3d(root._x0,
                                                     root._knuckle - root._l0,
                                                     0)

    // --- a finger ------------------------------------------------------------

    // Two boxes hinged at the knuckle and again halfway. Two joints is the
    // fewest that folds into a ball instead of tilting like a flap, and 112
    // degrees each is what lands the tip back on the front of the palm -
    // measured, not chosen: less and the fist is a claw with the tips still
    // out in the outline, more and they drive back through the knuckles.
    component Finger: Node {
        id: _f

        property real len: 1
        property real thick: 1
        /*!
            How thick the far segment is relative to the near one. Under 1
            for a finger, which narrows toward the tip; over 1 for the thumb,
            whose pad is the broadest part of it. Getting this backwards on
            the thumb is what turns a thumbs-up into a spike.
        */
        property real taper: 0.82
        /*! 0 straight, 1 folded into the palm. */
        property real curl: 0
        /*! Degrees away from the hand's centre line. */
        property real splay: 0

        readonly property real _seg1: _f.len * 0.55
        readonly property real _seg2: _f.len - _f._seg1

        eulerRotation: Qt.vector3d(_f.curl * 112, 0, _f.splay)

        BodyPart {
            width: _f.thick
            depth: _f.thick
            height: _f._seg1
            color: root.tone
            basePos: Qt.vector3d(0, -height, 0)
            // Thinner than BodyPart's default: at finger scale the plugin's
            // outline weight eats the whole box and every finger goes black.
            edgeThickness: 2.2
        }

        Node {
            y: -_f._seg1
            eulerRotation.x: _f.curl * 112

            BodyPart {
                width: _f.thick * _f.taper
                depth: _f.thick * _f.taper
                height: _f._seg2
                color: root.tone
                basePos: Qt.vector3d(0, -height, 0)
                edgeThickness: 2.2
            }
        }
    }

    // --- the hand ------------------------------------------------------------

    Finger {
        x: root._x0; y: root._knuckle
        len: root._l0; thick: root._w0
        curl: root._ci
        // The index never fans, even in the open pose: in the pointing pose it
        // has to lie on the line the arm was aimed along, and a finger that
        // wanders off it by a few degrees is a finger that misses the thing.
        splay: 0
    }

    Finger {
        x: root._x1; y: root._knuckle
        len: root._l1; thick: root._w1
        curl: root._cm
        splay: -root._side * root._sp * root._fan
    }

    Finger {
        x: root._x2; y: root._knuckle
        len: root._l2; thick: root._w2
        curl: root._cr
        splay: -root._side * root._sp * root._fan * 2
    }

    Finger {
        x: root._x3; y: root._knuckle
        len: root._l3; thick: root._w3
        curl: root._cl
        splay: -root._side * root._sp * root._fan * 3
    }

    // The thumb leaves the palm lower and further out than any finger, and it
    // needs two rotations rather than one: a fold across the front of the palm
    // (X) and a swing out from the hand's side (Z). Both stay within what a
    // thumb can do - the extended poses swing it out (Z) and only tilt it a
    // few degrees off the palm's plane (X).
    Node {
        x: root._side * root._pw * 0.44
        y: -root._ph * 0.38
        z: -root._pd * 0.10

        eulerRotation: Qt.vector3d(root._tx, 0, root._side * root._tz)

        Finger {
            len: root._ph * 0.85
            // One width all the way up. A thumb tapering to a point reads as
            // a spike and a thumb widening toward the pad reads as a club;
            // at two boxes there is not enough of it for either shape to look
            // like anything but a mistake, and a plain stub reads as a thumb.
            thick: root._wt
            taper: 1.0
            curl: root._tc
        }
    }
}
