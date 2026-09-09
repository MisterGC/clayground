// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// DetailedHand - four fingers and a thumb on the end of an Arm.
//
// Opt-in, through Arm::articulated, and off everywhere by default: it is ten
// more boxes per hand, and a character only ever seen from across a room does
// not need them.
//
// It exists for one reason. The plain hand is a single box, so a character
// pointing at something high and far away is a body with a straight limb
// sticking out of it - a silhouette that reads as a fascist salute. A bent
// elbow (GestureAnim's half of the fix, see safeSilhouette) breaks the
// straight line; an EXTENDED INDEX FINGER is what says the gesture is aimed at
// a thing. Between them there is nothing left of the salute.
//
// So legibility beats anatomy everywhere the two disagree. The index is both
// the longest and the thickest finger here, which no hand is, and the other
// three are stubbier than a hand's so they fold away to nothing in the fist -
// all of it so that the one thing left projecting from the outline is the
// finger. Measured: it still reads as an extended finger with the whole figure
// about 120 px tall, and stops reading below roughly 90 px.
//
// Everything is measured off the palm it is given, so a character's hand
// dimensions keep the fingers in proportion. Nothing here is in world units.
//
// It sits on the arm's WRIST JOINT and treats the plain Hand box as the palm:
// the knuckle line sits on that box's far face. That box stays visible - there
// is one hand here, not two.

import QtQuick
import QtQuick3D

pragma ComponentBehavior: Bound

/*!
    \qmltype DetailedHand
    \inqmlmodule Clayground.Character3D
    \inherits Node
    \brief Four fingers and a thumb on the end of an \l Arm.

    Created by \l Arm when its \l {Arm::articulated}{articulated} property is
    set, which is what \l {Character::detail}{Character.detail} resolves to. The plain \l Hand box stays and becomes the palm; the
    fingers grow off its far face.

    A gesture picks the pose (a pointing hand extends its index finger);
    \l {Character::handPose}{Character.handPose} decides what the hands do
    the rest of the time.

    \sa Arm, Hand, GestureAnim
*/
Node {
    id: root

    /*!
        \qmlproperty string DetailedHand::pose
        \brief Which shape the hand takes: "relax" (default), "open",
               "point", "thumbsUp" or "fist".
    */
    property string pose: "relax"

    /*!
        \qmlproperty real DetailedHand::palmWidth
        \brief Width of the palm the fingers are packed across.
    */
    property real palmWidth: 1

    /*!
        \qmlproperty real DetailedHand::palmHeight
        \brief Height of the palm, measured down from the wrist joint. The
               knuckles sit at its far end.
    */
    property real palmHeight: 1

    /*!
        \qmlproperty real DetailedHand::palmDepth
        \brief Depth of the palm.
    */
    property real palmDepth: 1

    /*!
        \qmlproperty color DetailedHand::tone
        \brief Skin colour of the fingers.
    */
    property color tone: "#d38d5f"

    /*!
        \qmlproperty real DetailedHand::settleMs
        \brief How long a pose change takes, in milliseconds.
    */
    property real settleMs: 220

    /*!
        \qmlproperty bool DetailedHand::mirrored
        \brief Set on the left hand, so the thumb ends up on the other side.
    */
    property bool mirrored: false

    /*!
        \qmlproperty vector3d DetailedHand::indexTip
        \readonly
        \brief Where the extended index finger ends, in the wrist joint's own
               frame - the point to aim, and the point to measure.

        Only meaningful while the index is straight.
    */
    readonly property vector3d indexTip: Qt.vector3d(root._x0,
                                                     root._knuckle - root._l0,
                                                     root._knuckleZ)

    // Which edge of the palm the thumb and the index share. Default is the
    // -X edge, which on the right arm (the character puts it at +X) is the
    // edge facing the body. That is where a thumb belongs here: the palm has
    // no wrist roll available to it and so always faces backwards at rest, and
    // a backwards-facing palm puts its thumb inboard. Seen from above with
    // both arms forward the two thumbs then point at each other, which is what
    // a pair of hands does; outboard thumbs read as two left hands.
    readonly property real _side: root.mirrored ? 1 : -1

    // Fingers grow from just inside the palm's far face, so the joint is a
    // fold rather than a gap.
    readonly property real _knuckle: -root.palmHeight * 0.97

    // --- the pose ------------------------------------------------------------
    // i/m/r/l are per-finger curl, 0 straight and 1 folded into the palm.
    // sp is how far the four fan apart. The thumb needs three of its own,
    // because tucking it and standing it up are different rotations and the
    // poses do not agree on either: tx folds it across the front of the palm
    // (negative stands it off the back), tz swings it out from the hand's
    // side, tc curls the thumb itself.

    // toff slides the thumb's ROOT forward, in palm depths, and only the fist
    // uses it. The four fingers fold to about 1.6 palm depths in front of the
    // knuckle line, and the thumb's proximal segment is 1.0 long from a root
    // 0.35 in front of centre - so from where a thumb actually grows it CANNOT
    // reach the outside of the block its own hand has made, whatever angle it
    // leaves at. Every setting buries it, which is what "the thumb is messed
    // up" looked like: a red-tinted test render showed it swallowed whole.
    //
    // Two boxes have one joint between them, so the node they hang off is the
    // thumb's MCP rather than its CMC - the knuckle, not the root of the
    // metacarpal - and on a real hand that knuckle IS well forward on the palm
    // when the hand closes, carried there by a joint this model does not have.
    // Sliding it is therefore closer to the anatomy than leaving it, and it is
    // the same trade the rest of this file makes: legibility beats anatomy
    // where the two disagree, and here they do not even disagree.
    //
    // tl scales the thumb's own LENGTH. One number in the table rather than a
    // fixed thumb, because the thumbs-up is the one gesture that is nothing
    // but the thumb: everywhere else it is a detail of the hand, and there it
    // has to carry the whole meaning from across a room. Same argument as the
    // index being the longest and fattest finger here, which no hand is.
    function poseFor(name) {
        if (name === "point")
            return { i: 0.00, m: 1.00, r: 1.00, l: 1.00, sp: 0.00,
                     tx: 48, tz: 52, tc: 0.20, tl: 1.00, toff: 0.00, tr: 80 }
        // The thumb goes OUT along the side of the fist, not up off the back
        // of it. A thumb swings in the plane of its own palm; standing one on
        // the back of the hand is a joint nobody has, and it looks like one.
        // What makes it point at the sky is the wrist rolling a quarter turn -
        // see the thumbsUp pose in GestureAnim, which is where that lives.
        if (name === "thumbsUp")
            return { i: 1.00, m: 1.00, r: 1.00, l: 1.00, sp: 0.00,
                     tx: -12, tz: 88, tc: 0.00, tl: 1.15, toff: 0.00, tr: 0 }
        if (name === "open")
            return { i: 0.00, m: 0.00, r: 0.00, l: 0.00, sp: 1.00,
                     tx: 6, tz: 48, tc: 0.00, tl: 1.00, toff: 0.00, tr: 80 }
        // A fist closes OVER its own thumb: the four fingers curl first and
        // the thumb comes ACROSS THE FRONT of them, its tip tucked into the
        // hollow they curl around.
        //
        // tz IS NEGATIVE HERE and that is the whole fix. Positive swings the
        // thumb out along its own edge of the hand, which is what a thumbs-up
        // wants and what this pose asked for for a long time - it was 70, then
        // 30, and 30 is still outboard: the thumb left the fist at the front
        // corner and stood there as a loose spike with a gap behind it.
        // Negative takes it the other way, in over the folded fingers, so the
        // proximal segment lies along them and the curl below can drop the tip
        // into the hole. Measured off the direction the segment ends up
        // pointing: +0.71 inboard where it used to be -0.50 outboard.
        if (name === "fist")
            return { i: 1.00, m: 1.00, r: 1.00, l: 1.00, sp: 0.00,
                     tx: 90, tz: -72, tc: 0.25, tl: 1.15, toff: 1.00, tr: 90 }
        // The index is curled hardest of the four at rest, against the way a
        // hand actually relaxes: it is the long one, and left barely bent it
        // reads as a limp point rather than as a hand doing nothing.
        return { i: 0.40, m: 0.44, r: 0.50, l: 0.56, sp: 0.25,
                 tx: 18, tz: 38, tc: 0.28, tl: 1.00, toff: 0.00, tr: 80 }
    }

    /*!
        \qmlproperty var DetailedHand::poseOverride
        \brief Fields to replace in the current pose's row, or null.

        The tuning channel, and the reason it exists: every number in the table
        above was arrived at by looking, and looking is done at a bench with a
        hand in front of you, not in a text editor with a rebuild between each
        guess. \c bench/HandSandbox.qml puts sliders on these and prints the row
        back out in the form it is written here, so a shape somebody dialled in
        is pasted into the table rather than re-derived from a screenshot.

        Partial: only the keys it carries are replaced. It may also carry
        \c foldNear, \c foldFar, \c tuckNear and \c tuckFar, which are not part
        of a pose but are the other half of what a folded finger looks like.
    */
    property var poseOverride: null

    readonly property var _p: {
        const base = root.poseFor(root.pose)
        if (!root.poseOverride)
            return base
        let out = {}
        for (const k in base)
            out[k] = base[k]
        for (const k2 in root.poseOverride)
            out[k2] = root.poseOverride[k2]
        return out
    }

    /*!
        \qmlproperty real DetailedHand::foldNear
        \brief How far the knuckle bends at full curl, in degrees.
    */
    property real foldNear: 86

    /*!
        \qmlproperty real DetailedHand::foldFar
        \brief And how far the second joint bends on top of it.
    */
    property real foldFar: 122

    /*! \qmlproperty real DetailedHand::tuckNear
        \brief How much of its length the near segment gives up at full curl. */
    property real tuckNear: 0.10

    /*! \qmlproperty real DetailedHand::tuckFar
        \brief The same for the far segment, which does the reaching. */
    property real tuckFar: 0.35

    /*!
        \qmlproperty real DetailedHand::thumbDown
        \brief Where the thumb leaves the palm, as a fraction of the palm's
               length measured down from the wrist.

        Off a photograph of an articulated hand rather than off a guess: a
        thumb comes away from the palm LOW, past halfway to the wrist, which is
        what leaves the long open web between it and the index. It was 0.38 -
        barely a third down - and a thumb rooted that high is a fifth finger
        set slightly apart, which is what it read as.
    */
    property real thumbDown: 0.55

    /*!
        \qmlproperty real DetailedHand::thumbOut
        \brief And how far out to the side, as a fraction of the palm's width.
    */
    property real thumbOut: 0.46

    readonly property real _td: root._p.tdown === undefined ? root.thumbDown : root._p.tdown
    readonly property real _tw: root._p.tout === undefined ? root.thumbOut : root._p.tout

    // A pose may carry its own fold shape; almost none does, and the four
    // properties above are what it falls back to.
    readonly property real _fn: root._p.foldNear === undefined ? root.foldNear : root._p.foldNear
    readonly property real _ff: root._p.foldFar === undefined ? root.foldFar : root._p.foldFar
    readonly property real _tn: root._p.tuckNear === undefined ? root.tuckNear : root._p.tuckNear
    readonly property real _tf: root._p.tuckFar === undefined ? root.tuckFar : root._p.tuckFar

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
    property real _tl: root._p.tl
    property real _to: root._p.toff
    property real _tr: root._p.tr

    Behavior on _ci { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _cm { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _cr { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _cl { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _sp { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _tx { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _tz { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _tc { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _tl { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _to { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _tr { NumberAnimation { duration: root.settleMs; easing.type: Easing.OutCubic } }

    // --- how the four are packed ---------------------------------------------

    readonly property real _gap: root.palmWidth * 0.015
    readonly property real _w0: root.palmWidth * 0.38   // index - deliberately the fat one
    readonly property real _w1: root.palmWidth * 0.215
    readonly property real _w2: root.palmWidth * 0.19
    readonly property real _w3: root.palmWidth * 0.165  // little

    // The thumb is the thickest digit on the hand, which is true of a real one -
    // but only just. It was 0.44, better than twice the middle finger's width
    // and a sixth more than the index's, and against four fingers this thin
    // that stops reading as a thumb and starts reading as a thumb belonging to
    // a bigger hand. A hair over the index is enough: the index is already the
    // fat one here, and what separates a thumb from a finger is where it grows
    // and which way it points, not how much of it there is.
    readonly property real _wt: root.palmWidth * 0.40

    // Packed side by side and centred on the palm, and the four together come
    // to just about the palm's own width. They used to overhang it by a fifth,
    // which bought the index enough thickness to see at distance back when the
    // palm was a narrow brick; the palm is a hand's width now, so the same
    // index is thicker in absolute terms than the overhanging one was.
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
    // The other three still fall away toward the little finger faster than a
    // hand's do - the index is the one carrying the meaning and three fingers
    // of its length beside it split the outline four ways. They used to fall
    // away much harder still, back when a folded finger could not tuck and
    // every extra millimetre of one stayed out in the silhouette; the fold
    // works now, so they get most of their length back.
    readonly property real _l0: root.palmHeight * 1.15   // index
    readonly property real _l1: root.palmHeight * 0.98
    readonly property real _l2: root.palmHeight * 0.88
    readonly property real _l3: root.palmHeight * 0.70

    // How far the fan opens, per step away from the index.
    readonly property real _fan: 7

    // How deep the fingers are THROUGH the hand, as opposed to how wide they
    // are across it. Two numbers rather than one, because the two are set by
    // different things: width is how many fingers have to fit side by side on
    // the palm, depth is how thick the palm is. A single square cross-section
    // ties them together and then a hand slim enough to be a hand has fingers
    // standing out of both of its faces.
    //
    // One depth for all four: the back of a hand is flat, and at this scale the
    // difference between a real index and a real little finger is thinner than
    // the outline drawn around them.
    readonly property real _deep: root.palmDepth * 0.82

    // Through the hand the thumb is deeper than a finger - it is the only part
    // with a joint that can turn to face the others, and a flat one reads as a
    // fifth finger lying on its side - but it does not fill the palm's whole
    // thickness. At 0.96 against the fingers' 0.82 it stood a sixth proud of
    // the back of the hand from every angle.
    readonly property real _deepT: root.palmDepth * 0.88

    // The knuckle line sits on the BACK of the palm rather than down the middle
    // of it. Fingers fold to the palm side, so a knuckle on the centre line
    // folds them through the palm box: at a full fist the tips come to rest
    // inside it and the near segments break out through its front face, which
    // is the loose jumble of boxes a fist used to be. Flush with the back is
    // also what a hand does - the back of one is flat and all the variation in
    // thickness is on the palm side.
    //
    // Clamped, because a character can be given a palm shallower than its own
    // fingers are deep, and a finger hanging off the back of the hand is a
    // worse failure than one that is merely centred.
    readonly property real _knuckleZ: Math.max(0, (root.palmDepth - root._deep) * 0.5)

    // --- a finger ------------------------------------------------------------

    // Two boxes and two hinges: one at the knuckle, one where a PIP joint goes.
    // Two is the fewest that folds into a ball instead of tilting like a flap,
    // and it is also the whole cost of the articulated hand - four fingers and
    // a thumb come to ten boxes. The joint being dropped is the one nearest the
    // tip, which contributes least to an outline; the thumb has only two bones
    // anyway, so for the thumb this is not an approximation at all.
    //
    // The split is 45/55 - the near segment is the SHORTER one. That is a real
    // finger's proportion (the proximal bone is about 45% of the length and the
    // two beyond it about 55% together), and getting it backwards puts the fold
    // further out than a knuckle goes, which throws the folded tip past the
    // palm instead of onto it.
    component Finger: Node {
        id: _f

        property real len: 1
        /*! Across the hand. */
        property real thick: 1
        /*! Through the hand, back to palm. Square unless told otherwise. */
        property real deep: _f.thick
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
        /*!
            How far the KNUCKLE bends at full curl. Just past square, so the
            near segment lies across the front of the palm.
        */
        property real foldNear: root._fn

        /*!
            And how far the second joint bends on top of it. The two together
            are what land the tip ON the palm, and getting their sum wrong is
            the whole difference between a fist and a jumble: at 96 and 96 -
            which is what this was - the finger folds through 192 degrees and
            comes back up PAST its own knuckle, so the tips ended up level with
            the wrist and a palm's thickness clear of the hand in front of it.
            Measured: 92 and 78 put the fingertip a little over half way down
            the palm and the whole folded finger inside a block about two palm
            thicknesses deep - which is what \l Hand's single-box fist is, so
            the two levels of detail agree about how big a fist is.
        */
        property real foldFar: root._ff

        /*!
            How much of its length each segment gives up at full curl, near and
            far. A cheat, and the same kind as everything else here: a fist
            hides its own fingertips, so nothing is lost by drawing them short,
            and what is bought is a folded finger that ends on the palm instead
            of reaching back off the far side of it. The far segment gives up
            more because it is the one doing the reaching.
        */
        property real tuckNear: root._tn
        property real tuckFar: root._tf
        /*!
            Where the second hinge sits across the segment's depth: 0.5 on the
            palm-side face, 0 on the centre line. Half is right for a finger,
            which is long against its own thickness, so the wedge that opens at
            the back of the joint stays small. A thumb is nearly as thick as its
            segments are long and the same wedge splits it in two, so it hinges
            much closer to its middle and accepts the overlap instead.
        */
        property real hinge: 0.5

        readonly property real _seg1: _f.len * 0.45 * (1 - _f.tuckNear * _f.curl)
        readonly property real _seg2: _f.len * 0.55 * (1 - _f.tuckFar * _f.curl)

        eulerRotation: Qt.vector3d(_f.curl * _f.foldNear, 0, _f.splay)

        BodyPart {
            width: _f.thick
            depth: _f.deep
            height: _f._seg1
            color: root.tone
            basePos: Qt.vector3d(0, -height, 0)
            // Thinner than BodyPart's default: at finger scale the standard
            // outline weight eats the whole box and every finger goes black.
            edgeThickness: 2.2
        }

        // The hinge is on the PALM-SIDE EDGE of the near segment, not on its
        // centre line. A centred pivot folds the two boxes half into each other
        // and half apart - and because BodyPart outlines every box, the overlap
        // does not hide, it draws a seam straight across the middle of the
        // finger. On the edge the palm side closes like a real knuckle does and
        // the whole error goes to the back of the joint, where a wedge opening
        // up reads as the knuckle itself.
        Node {
            y: -_f._seg1
            z: -_f.deep * _f.hinge
            eulerRotation.x: _f.curl * _f.foldFar

            BodyPart {
                width: _f.thick * _f.taper
                depth: _f.deep * _f.taper
                height: _f._seg2
                color: root.tone
                // Pushed back off the hinge by half its own depth, so its palm
                // side lands on the pivot rather than straddling it.
                basePos: Qt.vector3d(0, -height, _f.deep * _f.taper * _f.hinge)
                edgeThickness: 2.2
            }
        }
    }

    // --- the hand ------------------------------------------------------------

    Finger {
        x: root._x0; y: root._knuckle; z: root._knuckleZ
        len: root._l0; thick: root._w0; deep: root._deep
        curl: root._ci
        // The index never fans, even in the open pose: in the pointing pose it
        // has to lie on the line the arm was aimed along, and a finger that
        // wanders off it by a few degrees is a finger that misses the thing.
        splay: 0
    }

    Finger {
        x: root._x1; y: root._knuckle; z: root._knuckleZ
        len: root._l1; thick: root._w1; deep: root._deep
        curl: root._cm
        splay: -root._side * root._sp * root._fan
    }

    Finger {
        x: root._x2; y: root._knuckle; z: root._knuckleZ
        len: root._l2; thick: root._w2; deep: root._deep
        curl: root._cr
        splay: -root._side * root._sp * root._fan * 2
    }

    Finger {
        x: root._x3; y: root._knuckle; z: root._knuckleZ
        len: root._l3; thick: root._w3; deep: root._deep
        curl: root._cl
        splay: -root._side * root._sp * root._fan * 3
    }

    // The thumb leaves the palm lower and further out than any finger, and it
    // needs two rotations rather than one: a fold across the front of the palm
    // (X) and a swing out from the hand's side (Z). Both stay within what a
    // thumb can do - the extended poses swing it out (Z) and only tilt it a
    // few degrees off the palm's plane (X).
    Node {
        x: root._side * root.palmWidth * root._tw
        y: -root.palmHeight * root._td
        z: -root.palmDepth * (0.35 + root._to)

        eulerRotation: Qt.vector3d(root._tx, 0, root._side * root._tz)

        // The thumb TWISTED about its own length, and it needs a node of its
        // own: a QML euler composes as Ry*Rx*Rz, so the Y slot above is applied
        // outermost and turns the thumb about the HAND's axis, not its own.
        // Nested inside the orienting node it is a roll of the thumb itself.
        //
        // Which is a thing a thumb is: its flat faces are turned about a
        // quarter turn from a finger's, pad toward the other fingers and nail
        // outward, and it is the one joint in a hand that does that. Left at
        // zero the thumb is a finger that happens to grow lower down, and on a
        // closed fist - where the broad face lands square to the eye - that
        // reads as a slab lying on the knuckles rather than as a thumb.
        Node {
            eulerRotation.y: root._side * root._tr

            Finger {
                // A thumb is about two thirds of an index finger, and the
                // index here is 1.15 palms - so 0.72. It was 0.85, which put
                // it level with the middle finger and, with the thumbs-up
                // stretch on top, LONGER than the index: a hand whose biggest
                // digit is its thumb reads as a mitten with a spur.
                len: root.palmHeight * 0.72 * root._tl
                // One width all the way up. A thumb tapering to a point reads
                // as a spike and one widening toward the pad reads as a club;
                // at two boxes there is not enough of it for either shape to
                // look like anything but a mistake, and a plain stub reads as
                // a thumb.
                thick: root._wt
                deep: root._deepT
                taper: 1.0
                curl: root._tc
                hinge: 0.18
            }
        }
    }
}
