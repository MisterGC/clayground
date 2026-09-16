// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Hand - one box, whose SHAPE says what the hand is doing.
//
// The box has two jobs and they want different sizes.
//
// Under a DetailedHand it is the palm, and the fingers are drawn on it. That
// is what pose "" means here, and then the box is left exactly as the arm
// sized it.
//
// On its own it is the whole hand, and a palm is less than half of one - the
// articulated hand reaches palm-plus-index, better than twice as far. A box
// left at palm size is a stump on the end of the arm, which is what the low
// level of detail has been until now.
//
// Being the whole hand is also what lets it act. Ten boxes are what it costs
// to fold real fingers, but the SILHOUETTE of a folded hand is just a shorter,
// much thicker block, and the silhouette is all there is at the distance this
// version is used. So a fist gets stubby and deep, an open hand stays long and
// flat, and a wave stops looking like a punch - for nothing, in one box.
//
// The numbers are not free invention: each one is the bounding shape of the
// ARTICULATED hand in that same pose. That is the whole discipline here. Two
// levels of detail that disagree about how big a fist is cannot be swapped
// between while anyone is looking, and being swapped between while someone is
// looking is the entire point of having two.

import QtQuick
import Clayground.Canvas3D

/*!
    \qmltype Hand
    \inqmlmodule Clayground.Character3D
    \inherits BodyPart
    \brief A whole hand in a single box, or the palm under a \l DetailedHand.

    Which one it is depends on \l pose. An \l Arm with
    \l {Arm::articulated}{articulated} set leaves the pose empty and the box
    stays palm-sized under the fingers; otherwise the box takes on the whole
    hand's size and changes shape with the pose - long and flat for an open
    hand, short and deep for a fist.

    \sa Arm, DetailedHand
*/
BodyPart {
    id: _hand

    /*!
        \qmlproperty string Hand::pose
        \brief What the hand is doing: "open", "relax", "point", "thumbsUp",
               "fist" - or "" for a palm under a set of real fingers.

        Empty is not a pose but a role: it says something else is drawing the
        fingers, so this box is only the palm and must not be reshaped.
    */
    property string pose: ""

    /*!
        \qmlproperty real Hand::palmWidth
        \brief Width of the palm. Every pose is measured against it.
    */
    property real palmWidth: 1

    /*!
        \qmlproperty real Hand::palmHeight
        \brief Wrist-to-knuckles length of the palm. A whole hand is roughly
               twice this.
    */
    property real palmHeight: 1

    /*!
        \qmlproperty real Hand::palmDepth
        \brief Thickness of the palm.
    */
    property real palmDepth: 1

    /*!
        \qmlproperty real Hand::settleMs
        \brief How long the shape takes to change, in milliseconds. Matches
               \l {DetailedHand::settleMs}{DetailedHand}, so the two levels of
               detail take the same time to answer a pose change.
    */
    property real settleMs: 220

    // Default color that can be overridden
    color: "#d38d5f"

    // w/h/d multiply the palm; t is how far the wrist end is pulled in.
    //
    // Height above 1 is the whole hand rather than the palm. Depth is where
    // most of the acting is: a hand folding is a hand getting thicker, and at
    // the distance one box is enough, thickness against length is the only
    // thing that separates a fist from a flat hand.
    readonly property var _m: {
        // Palm under real fingers - not a pose, and nothing to reshape.
        if (_hand.pose === "")
            return { w: 1.00, h: 1.00, d: 1.00, t: 0.70 }
        // Flat and at full reach. This is the wave, and the one pose where the
        // hand is longer than it is anything else.
        if (_hand.pose === "open")
            return { w: 1.00, h: 2.05, d: 1.00, t: 0.70 }
        // Nothing left projecting: the knuckles are the far end of it. Wider
        // than it is long and nearly as deep as it is wide, which is a fist.
        // Blunter at the wrist too - the taper that reads as a wrist widening
        // into a hand reads as a wedge on a fist.
        if (_hand.pose === "fist")
            return { w: 1.00, h: 1.00, d: 2.20, t: 0.88 }
        // The same block. What makes it a thumbs-up is the wrist rolling a
        // quarter turn, which is GestureAnim's to do and cannot be done with
        // shape at this level anyway.
        if (_hand.pose === "thumbsUp")
            return { w: 0.95, h: 1.05, d: 1.95, t: 0.86 }
        // A closed hand, and deliberately NOT a long one. There is no finger
        // to extend here, and a long box on a raised arm is the salute this
        // whole component exists to stay out of - the articulated hand is what
        // a point is for, and Auto will have switched to it by the time anyone
        // is close enough to want one.
        if (_hand.pose === "point")
            return { w: 0.85, h: 1.15, d: 1.85, t: 0.84 }
        // relax, and anything unrecognised. Half-curled: most of the reach,
        // noticeably thicker than an open hand. It is the default pose, so it
        // is the shape a character has when nobody has said otherwise.
        return { w: 0.98, h: 1.70, d: 1.45, t: 0.74 }
    }

    // Held as animatable reals rather than read straight out of _m: a pose is
    // a destination, and the hand has to be caught mid-change as well as at
    // rest - the same reason DetailedHand animates its curls.
    property real _fw: _hand._m.w
    property real _fh: _hand._m.h
    property real _fd: _hand._m.d
    property real _ft: _hand._m.t

    Behavior on _fw { NumberAnimation { duration: _hand.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _fh { NumberAnimation { duration: _hand.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _fd { NumberAnimation { duration: _hand.settleMs; easing.type: Easing.OutCubic } }
    Behavior on _ft { NumberAnimation { duration: _hand.settleMs; easing.type: Easing.OutCubic } }

    width: _hand.palmWidth * _hand._fw
    height: _hand.palmHeight * _hand._fh
    depth: _hand.palmDepth * _hand._fd

    // Narrow at the wrist, full at the knuckles - a hand widens as it leaves
    // the arm. How much is per pose: see the fist.
    scaledFace: Box3DGeometry.TopFace
    faceScale: Qt.vector2d(_hand._ft, _hand._ft)
}
