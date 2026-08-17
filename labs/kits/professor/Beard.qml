// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Beard - the fastest way to say "old" that does not depend on the viewer
// reading a hair colour correctly.
//
// Built the way Head.qml builds hair: a handful of boxes, every one of them
// placed and sized off the head's own dimensions. There is not a single world
// unit in this file, so a professor whose skull is made twice as wide still
// gets a beard that fits it rather than a beard that used to fit the last one.
//
// It parents itself to the head NODE, not to the character. The head is
// animated - it turns, it tilts, the pointing gesture drives it - and a beard
// one level further up would swing off the face the moment the professor looks
// at something. That is worse than no beard, because a missing beard is a
// choice and a floating one is a bug.
//
// It also stays off the mouth. The mouth is the only part of this face that
// carries information while the professor talks, and the jaw box it sits on
// STRETCHES DOWNWARD as the mouth opens (Head.jawDrop), so "below the mouth"
// is a moving target - see _mouthBottom and _chinBottom below.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D

pragma ComponentBehavior: Bound

Node {
    id: root

    /*! The Character to grow it on. null leaves it inert - nothing is drawn. */
    property var character: null

    /*! Beard colour. Follows the character's hair unless told otherwise. */
    property color tone: root._head ? root._head.hairColor : "#9a9a9a"

    /*!
        Which beard:

        \list
        \li \c full - the lot: chin, cheeks, jaw and an upper lip
        \li \c walrus - no chin hair at all, and the moustache that would
            have been an accent becomes the face's main event
        \li \c goatee - a narrow chin tuft joined to the moustache
        \li \c chin - the tuft alone, upper lip shaved
        \li \c none - clean shaven
        \endlist

        Style decides WHICH pieces exist; \l length and \l fullness still
        size the ones that do, so two professors can wear the same style
        and not be the same man.
    */
    property string style: "full"

    /*! 0 is three days unshaven, 1 is a beard you could lose a pen in. */
    property real length: 0.6

    /*! How far round the jaw it wraps: 0 is a goatee, 1 reaches the ears. */
    property real fullness: 0.7

    /*!
        Whether the upper lip gets one too. Only ever removes: a style
        without a moustache does not grow one because this is true.
    */
    property bool moustache: true

    // --- what the style is made of -------------------------------------------
    // One flag per piece rather than a switch at each use site, so adding a
    // style is a line here and nothing at all down there.

    readonly property bool _hasChin: root.style === "full" || root.style === "goatee"
                                     || root.style === "chin"
    readonly property bool _hasJaw: root.style === "full"
    readonly property bool _hasCheeks: root.style === "full"
    readonly property bool _hasTache: root.moustache && root.style !== "chin"

    // A goatee is a goatee because it is narrow. Without this it is just a
    // full beard with the sides forgotten, which reads as a modelling mistake
    // rather than as a choice somebody made in a mirror.
    readonly property real _narrow: root.style === "full" ? 1.0 : 0.62

    // How much bigger the moustache gets when it is the only thing there.
    // A walrus is not a normal moustache scaled up evenly: it is mostly
    // WIDER and it droops much further, which is why the two grow apart.
    readonly property real _walrus: root.style === "walrus" ? 1 : 0

    // --- what it hangs on ----------------------------------------------------

    readonly property var _head: (root.character !== null && root.character !== undefined)
                                 ? root.character.head : null

    // The attachment itself. Reparenting rather than mirroring a transform:
    // the head's rotation, its position and the character's scale all come for
    // free, including the 0-to-1 scale the professor arrives with.
    parent: root._head
    visible: root._head !== null && root.style !== "none"

    // --- the head, in numbers ------------------------------------------------
    // Guarded one by one so an unattached beard evaluates to a harmless zero
    // instead of raising on every binding.

    readonly property real _uw: root._head ? root._head.upperHeadWidth : 0
    readonly property real _uh: root._head ? root._head.upperHeadHeight : 0
    readonly property real _lw: root._head ? root._head.lowerHeadWidth : 0
    readonly property real _lh: root._head ? root._head.lowerHeadHeight : 0
    readonly property real _ld: root._head ? root._head.lowerHeadDepth : 0

    // Head.qml pushes both head boxes this far forward of the head node.
    readonly property real _zOff: root._head ? root._head.depth * 0.09 : 0
    readonly property real _jawFront: _zOff + _ld * 0.5
    readonly property real _jawTop: _lh

    // The chin is not where it was at rest while the mouth is open: the jaw
    // box grows downward and its bottom edge moves with it.
    readonly property real _open: root._head ? root._head.mouthOpen : 0
    readonly property real _chinBottom: -(_open * (root._head ? root._head.jawDrop : 0) * _lh)

    // The mouth line stays put while that happens; the cavity opens downward
    // from it. This is the lowest the mouth ever reaches.
    readonly property real _mouthW: _lw * 0.22 * (root._head ? root._head.mouthSize : 1)
    readonly property real _mouthLine: 0.6 * _lh
    readonly property real _mouthBottom: _mouthLine - 0.3 * _mouthW - _open * _lh * 0.45

    // Breathing room between hair and mouth, and how far the beard falls
    // below the jaw once it has some length to it.
    readonly property real _clear: _lh * 0.09
    readonly property real _hang: root.length * _lh * 1.5

    // A beard stops below the cheekbone. Head.qml sets the eyes' lower edge
    // 0.3 upper-head-heights up, and hair above that line is in the way of the
    // eyes - and of anything worn over them.
    readonly property real _wrapLimit: _lh * 0.99 + 0.3 * _uh - _uh * 0.1

    // --- the chin ------------------------------------------------------------

    // Two boxes, not one. A single slab from the lip to the tip is a bucket
    // strapped to the face; a wide mass that steps down into a narrower point
    // is a beard, and the step is the only thing carrying that reading at this
    // polygon count.
    readonly property real _chinTop: _mouthBottom - _clear
    readonly property real _chinWidth: _lw * (0.45 + 0.55 * fullness) * _narrow
    readonly property real _chinStep: _chinBottom - _hang * 0.5

    // How wide the moustache is allowed to be. Needed up here because the
    // cheeks have to start outside it.
    readonly property real _tacheSpan: _mouthW * (1.3 + 0.45 * fullness) * (1 + 0.7 * _walrus)

    // The mass under the mouth. Its top tracks the open mouth so the cavity is
    // never covered; its bottom tracks the dropping chin, so the beard behaves
    // like something growing out of the jaw rather than something pinned in
    // front of it.
    BodyPart {
        id: _chin
        visible: root._hasChin
        color: root.tone
        width: root._chinWidth
        height: Math.max(0.001, root._chinTop - root._chinStep)
        depth: root._ld * (0.24 + 0.16 * root.length)
        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(0.78, 0.85)
        basePos: Qt.vector3d(0,
                             root._chinStep,
                             root._jawFront - root._ld * 0.13 + _chin.depth * 0.5)
    }

    // The tip. Nothing at all when length is 0 - a stubble beard has no point
    // to it, and an invisible box would still cast a shadow.
    BodyPart {
        id: _point
        visible: root._hasChin && root._hang > 0.0001
        color: root.tone
        width: root._chinWidth * 0.62
        height: Math.max(0.001, root._chinStep - (root._chinBottom - root._hang))
        depth: _chin.depth * 0.82
        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(0.4, 0.5)
        basePos: Qt.vector3d(0,
                             root._chinBottom - root._hang,
                             _chin.basePos.z - (_chin.depth - _point.depth) * 0.35)
    }

    // Closes the beard underneath. Without it the jaw is bare from any camera
    // below eye level, which is exactly where a lab camera tends to sit when
    // it is looking up at someone standing at a bench.
    BodyPart {
        id: _underJaw
        visible: root._hasJaw
        color: root.tone
        width: root._lw * (0.46 + 0.3 * root.fullness)
        depth: root._ld * (0.42 + 0.3 * root.fullness)
        height: root._lh * 0.14 + root._hang * 0.45
        basePos: Qt.vector3d(0,
                             root._chinBottom + root._lh * 0.06 - _underJaw.height,
                             root._zOff + root._ld * 0.05)
    }

    // The jaw sides, sweeping up toward the ears as fullness rises. They
    // straddle the side face the way Head.qml's side hair does, so the beard
    // is half inside the head and reads as attached rather than clipped on.
    //
    // They stop short of the back of the jaw and narrow as they go down. A
    // slab covering the whole side is what turns the profile into one grey
    // box - the taper is what puts a jawline back into it.
    component JawSide: BodyPart {
        id: _jawSide
        property real side: 1
        visible: root._hasJaw
        color: root.tone
        width: root._lw * 0.15 * (0.6 + 0.8 * root.fullness)
        height: Math.max(0.001, Math.min(root._wrapLimit,
                                         root._jawTop + root._uh * 0.42 * root.fullness)
                                - (root._chinBottom - root._hang * 0.35))
        depth: root._ld * (0.62 + 0.36 * root.fullness)
        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(1.0, 0.7)
        // Bottom follows the chin; the top is what fullness buys. Flush with
        // the front of the jaw so no strip of cheek is left between the side
        // and the chin mass, and open at the back where a jaw has no beard.
        basePos: Qt.vector3d(_jawSide.side * root._lw * 0.5,
                             root._chinBottom - root._hang * 0.35,
                             root._zOff + (root._ld - _jawSide.depth) * 0.5 + root._ld * 0.02)
    }

    JawSide { side: -1 }
    JawSide { side: 1 }

    // The two bands that run up beside the mouth and join the chin mass to the
    // jaw sides. Without them a beard is a bib: the cheeks stay bare skin from
    // the mouth to the jawline and the front pieces read as strapped on. They
    // are what makes it a U around the mouth rather than a patch under it.
    readonly property real _cheekInner: Math.max(_mouthW * 1.05, _tacheSpan * 0.6)
    readonly property real _cheekTop: Math.min(
        _wrapLimit, _chinTop + (_jawTop - _chinTop + _uh * 0.35 * fullness) * fullness)

    component Cheek: BodyPart {
        id: _cheek
        property real side: 1
        visible: root._hasCheeks && _cheek.height > root._lh * 0.02 && _cheek.width > 0
        color: root.tone
        width: Math.max(0, root._lw * 0.5 - root._cheekInner)
        height: Math.max(0.001, root._cheekTop - root._chinTop)
        depth: root._ld * (0.3 + 0.14 * root.fullness)
        basePos: Qt.vector3d(_cheek.side * (root._cheekInner + _cheek.width * 0.5),
                             root._chinTop,
                             root._jawFront - _cheek.depth * 0.5 + root._ld * 0.11)
    }

    Cheek { side: -1 }
    Cheek { side: 1 }

    // --- the upper lip -------------------------------------------------------

    Node {
        id: _tache
        visible: root._hasTache

        // Under the nose, above the lip line - and the lip line is where the
        // moustache stops. The gap between them is what there is to fill.
        readonly property real noseH: root._uh * 0.2 * (root._head ? root._head.noseSize : 1)
        readonly property real noseBottom: root._lh * 0.99 + 0.3 * root._uh - 1.1 * noseH
        readonly property real lipTop: root._mouthLine + 0.06 * root._mouthW
        readonly property real gap: Math.max(0, noseBottom - lipTop)
        // A walrus fills the whole gap to the nose; a normal one leaves the
        // lip showing above it. Capped either way - hair growing out of a
        // nostril is not the look.
        readonly property real bar: Math.max(0.001, gap * Math.min(
            1.0, 0.34 + 0.3 * root.length + 0.62 * root._walrus))
        readonly property real span: root._tacheSpan
        readonly property real front: root._jawFront - root._ld * 0.06

        BodyPart {
            id: _tacheBar
            color: root.tone
            width: _tache.span
            height: _tache.bar
            // A walrus stands off the face. Seen from the side it is the
            // silhouette that carries it, and a flat one has none.
            depth: root._ld * 0.17 * (1 + 0.55 * root._walrus)
            basePos: Qt.vector3d(0, _tache.lipTop, _tache.front + _tacheBar.depth * 0.5)
        }

        // The two ends droop. A straight bar reads as a plaster; the tilt is
        // the whole difference between "moustache" and "rectangle".
        //
        // They hang lower than the lip line, which everything else in this
        // file is forbidden to do - but they sit outside the mouth's own
        // width, so the one thing that must stay legible while the professor
        // talks stays legible.
        component TacheTip: BodyPart {
            id: _tip
            property real side: 1
            color: root.tone
            width: _tache.span * (0.3 + 0.06 * root._walrus)
            height: _tache.bar * (1.0 + 0.7 * root._walrus)
            depth: _tacheBar.depth * 0.85
            // A walrus droops further, but only a little further: past about
            // 40 degrees the tips swing clear of the bar they grow out of and
            // the moustache stops being one object.
            baseEuler: Qt.vector3d(0, 0, -_tip.side * (26 + 12 * root._walrus))
            // and they move INWARD as they lengthen, for the same reason.
            //
            // They also sit a little higher than a small moustache's, which
            // buys back some of the mouth. Only some: a walrus this size
            // covers the corners whatever is done here, and the corners are
            // where a smile is. Under one of these the expression is carried
            // by the eyebrows and by how far the mouth is open.
            basePos: Qt.vector3d(_tip.side * _tache.span * (0.42 - 0.07 * root._walrus),
                                 _tache.lipTop - _tache.bar * (0.35 - 0.1 * root._walrus),
                                 _tache.front + _tip.depth * 0.5)
        }

        TacheTip { side: -1 }
        TacheTip { side: 1 }
    }
}
