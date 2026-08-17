// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Hair - the professor's silhouette, in four cuts.
//
// The head that comes with the character plugin already grows hair: four slabs
// around the skull, one knob to inflate them. That is a haircut in the sense
// that a helmet is a hat. What tells a cartoon audience it is looking at a
// professor is the OUTLINE - Einstein's exploded grey, an academic's swept-back
// mane, a neat part, a monk's ring - and an outline needs shapes that differ
// from each other, not one shape with a volume dial. Set the character's own
// hairVolume to 0 and use this instead; the two draw on top of each other
// otherwise.
//
// Built the way Beard.qml is built, and for the same reasons: every dimension
// is a fraction of a head dimension, so a professor whose skull is twice as
// wide gets hair that fits it. There is not a single world unit in this file -
// the professor is scaled from 0 to 1 as it arrives and may be any height.
//
// It parents itself to the head NODE. The head turns, tilts and is driven by
// the pointing gesture; hair one level further up would slide off the skull the
// moment the professor looks at something.
//
// Two things it cannot know about, both worth knowing before blaming it:
// Spectacles routes its arms around whatever the HEAD's hairVolume says is
// there, so with that turned off the arms run close to the skull and the side
// masses swallow their last stretch near the ear - which is what glasses worn
// under hair look like, but it is not a choice this file made. And the hairline
// can only ever be as low as the eyes and lenses allow (see _faceFloor), so on
// a character with very large eyes every cut gets the same high forehead.
//
// Nothing here consumes randomness. Clump angles, lengths and thicknesses are a
// hash of the clump's index, so the same professor comes out the same way every
// time - which is what lets a lab screenshot it and a flow replay it.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D

pragma ComponentBehavior: Bound

Node {
    id: root

    /*! The Character to grow it on. null leaves it inert - nothing is drawn. */
    property var character: null

    /*! Hair colour. Follows the character's own hair colour unless told otherwise. */
    property color tone: root._head ? root._head.hairColor : "#9a9a9a"

    /*!
        Which cut: "wild", "swept", "tidy", "ring" or "none". Anything else is
        drawn as "wild" rather than as nothing - a typo that silently makes a
        professor bald is harder to spot than one that makes it dishevelled.
    */
    property string style: "wild"

    /*! How much of it there is. 0 draws nothing at all, 1.6 is a lot. */
    property real volume: 1.0

    // --- what it grows on ----------------------------------------------------

    readonly property var _head: (root.character !== null && root.character !== undefined)
                                 ? root.character.head : null

    // Reparenting rather than mirroring a transform: the head's rotation, its
    // position and the character's arrival scale all come for free.
    parent: root._head
    // Below a hair's breadth of volume nothing is drawn at all, rather than a
    // set of zero-height slabs flickering in the depth buffer.
    visible: root._head !== null && root.style !== "none" && root._v > 0.01

    readonly property real _v: Math.max(0, root.volume)

    // --- the head, in numbers ------------------------------------------------
    // Guarded one by one so an unattached head of hair evaluates to a harmless
    // zero instead of raising on every binding.

    readonly property real _uw: root._head ? root._head.upperHeadWidth : 0
    readonly property real _uh: root._head ? root._head.upperHeadHeight : 0
    readonly property real _ud: root._head ? root._head.upperHeadDepth : 0
    readonly property real _lh: root._head ? root._head.lowerHeadHeight : 0

    // Head.qml pushes both head boxes this far forward of the head node, and
    // stacks the cranium just under a full jaw height up. Everything below is
    // measured off that box: bottom-centre origin, centred in x and z.
    readonly property real _zOff: root._head ? root._head.depth * 0.09 : 0
    readonly property real _base: _lh * 0.99
    readonly property real _top: _base + _uh
    readonly property real _backZ: _zOff - _ud * 0.5

    // The line hair may not cross on the front of the face. Head.qml puts the
    // eyes' lower edge 0.3 cranium-heights up and the eye boxes are cubes, so
    // the brow tops out 1.13 eye-widths above that; a pair of Spectacles at
    // default size reaches 1.35 up. 1.4 clears both with a little to spare.
    // Larger lenses than that are the caller's problem - see the header of
    // Spectacles.qml for what "size" does.
    readonly property real _eyeW: _uw * 0.22 * (root._head ? root._head.eyeSize : 1)
    readonly property real _faceFloor: _base + 0.3 * _uh + 1.4 * _eyeW

    // --- the cut, as numbers -------------------------------------------------
    // One table per style rather than four sets of ternaries down in the
    // geometry: the boxes are the same boxes in every cut, and the difference
    // between an Einstein and a monk is only how big they are and how far back
    // they sit. Every entry is a fraction of a head dimension.
    //
    // cap*   the pad on the crown        side*  the masses over the ears
    // back*  the mass behind the skull   wave*  the roll over the forehead
    // clump* / ring* / tilt              the tufts growing out of the pad
    readonly property var _S: {
        if (root.style === "swept") return {
            // Combed back off the forehead - which only reads as a haircut if
            // the mass is ABOVE the skull where a face-on camera can see it.
            // Hence the wave: a slab standing on the front of the crown and
            // leaning back, with the clumps continuing the same line over the
            // top (frontLong makes the front ones the long ones) and the back
            // box catching what arrives at the neck.
            capRise: 0.14, capDrop: 0.26, capW: 1.08, capD: 1.06, capBack: 0.02,
            sideW: 0.24, sideD: 0.54, sideH: 0.46, sideY: 0.34, sideZ: 0.12,
            sideFlare: 1.0, sideFlareZ: 0.9, sideRoll: 5, sideLong: 0.1,
            backW: 1.16, backD: 0.52, backH: 0.86, backY: 0.16, backIn: 0.14,
            part: false, partX: 0,
            waveH: 0.56, waveW: 0.90, waveD: 0.32, waveZ: 0.15, waveTilt: 34,
            clumps: 7, clumpW: 0.36, clumpLen: 0.50, clumpSink: 0.20, clumpBack: 0.04,
            clumpTip: 0.55, cross: 0.4, lenVar: 0.7, widVar: 0.4,
            tilt: 54, tiltSide: 0, sideDrop: 0.10, leanBack: 1.0,
            backLong: 0.5, frontLong: 1.2,
            ringX: 0.78, ringZ: 0.80, ringInner: 0.30, jitter: 0.4
        }
        if (root.style === "tidy") return {
            // a cap and a part, nothing else: no clumps, and the sides stop
            // where a barber would have stopped
            capRise: 0.09, capDrop: 0.30, capW: 1.05, capD: 1.05, capBack: 0.01,
            sideW: 0.22, sideD: 0.56, sideH: 0.42, sideY: 0.42, sideZ: 0.10,
            sideFlare: 1.0, sideFlareZ: 1.0, sideRoll: 0, sideLong: 0,
            backW: 1.09, backD: 0.32, backH: 0.46, backY: 0.36, backIn: 0.10,
            part: true, partX: -0.17,
            waveH: 0, waveW: 0.8, waveD: 0.3, waveZ: 0.1, waveTilt: 0,
            clumps: 0, clumpW: 0.16, clumpLen: 0.2, clumpSink: 0.1, clumpBack: 0,
            clumpTip: 0.3, cross: 0, lenVar: 0.6, widVar: 0.4,
            tilt: 20, tiltSide: 0, sideDrop: 0, leanBack: 0.6,
            backLong: 0, frontLong: 0,
            ringX: 0.6, ringZ: 0.6, ringInner: 0.4, jitter: 0.2
        }
        if (root.style === "ring") return {
            // bald: no cap, no clumps, and the sides and back sit at ear height
            capRise: 0, capDrop: 0, capW: 1.0, capD: 1.0, capBack: 0,
            sideW: 0.28, sideD: 0.52, sideH: 0.38, sideY: 0.22, sideZ: 0.10,
            sideFlare: 1.05, sideFlareZ: 1.0, sideRoll: 0, sideLong: 0,
            backW: 1.12, backD: 0.38, backH: 0.40, backY: 0.22, backIn: 0.12,
            part: false, partX: 0,
            waveH: 0, waveW: 0.8, waveD: 0.3, waveZ: 0.1, waveTilt: 0,
            clumps: 0, clumpW: 0.16, clumpLen: 0.2, clumpSink: 0.1, clumpBack: 0,
            clumpTip: 0.3, cross: 0, lenVar: 0.6, widVar: 0.4,
            tilt: 20, tiltSide: 0, sideDrop: 0, leanBack: 0,
            backLong: 0, frontLong: 0,
            ringX: 0.6, ringZ: 0.6, ringInner: 0.4, jitter: 0.2
        }
        return {
            // "wild", and the default. Modelled on the cartoon it is drawn
            // from, where the hair is a handful of BROAD overlapping tufts,
            // each about as wide at the root as it is long, with blunt ends
            // and a ragged upper edge. Many thin evenly-spaced needles is the
            // other thing this table can produce, and that reads as a
            // hedgehog: what makes it hair is that neighbours touch, that no
            // two are the same size, and that they do not all lean the same
            // way (cross).
            //
            // The pad reaches further into the skull than it stands above it
            // and the tufts are sunk deep into it (clumpSink), because the
            // ragged gaps between them have to show more hair rather than
            // scalp.
            //
            // Most of the mass is low and out at the sides - the tufts near
            // the ears slide down the skull (sideDrop), grow longer (sideLong)
            // and lean right over (tiltSide), which is what makes the two
            // bushes over the ears without a second slab pretending to be one.
            capRise: 0.14, capDrop: 0.16, capW: 1.10, capD: 1.08, capBack: 0.02,
            sideW: 0.34, sideD: 0.58, sideH: 0.52, sideY: 0.26, sideZ: 0.12,
            sideFlare: 1.3, sideFlareZ: 0.85, sideRoll: 12, sideLong: 0.35,
            backW: 1.16, backD: 0.48, backH: 0.78, backY: 0.20, backIn: 0.12,
            part: false, partX: 0,
            waveH: 0, waveW: 0.8, waveD: 0.3, waveZ: 0.1, waveTilt: 0,
            clumps: 9, clumpW: 0.50, clumpLen: 0.55, clumpSink: 0.30, clumpBack: 0.04,
            clumpTip: 0.5, cross: 1.6, lenVar: 0.95, widVar: 0.6,
            tilt: 25, tiltSide: 10, sideDrop: 0.5, leanBack: 0,
            backLong: 0.25, frontLong: 0,
            ringX: 1.0, ringZ: 0.92, ringInner: 0.35, jitter: 1.0
        }
    }

    // --- the crown pad -------------------------------------------------------
    // What the clumps grow out of, and what keeps the top of the skull from
    // showing between them. It stands capRise above the crown and reaches
    // capDrop into it - hair that starts at the crown and goes up is a wig,
    // hair that starts inside the skull is hair.
    //
    // The bottom edge is clamped to the face line rather than trusted to a
    // number: a caller who asks for a lot of volume must not be able to pull a
    // slab of hair down over the eyebrows or over a pair of glasses.
    readonly property real _capTop: _top + _uh * _S.capRise * _v
    readonly property real _capBottom: Math.max(_top - _uh * _S.capDrop, _faceFloor)

    BodyPart {
        id: _cap
        visible: root._S.capRise > 0 && _cap.height > root._uh * 0.01
        color: root.tone
        width: root._uw * root._S.capW
        height: Math.max(0.001, root._capTop - root._capBottom)
        depth: root._ud * root._S.capD
        // Narrowed at the top, and only across the width. A pad with parallel
        // sides is a board lying on the head, so the taper is what turns the
        // same box into a scalp - but taper it front-to-back as well and its
        // front face slides BEHIND the cranium's own above a certain height,
        // which paints a stripe of forehead straight through the hair just
        // above the brow. That stripe was on every capped cut until this line
        // stopped shrinking the pad's depth.
        scaledFace: Box3DGeometry.TopFace
        faceScale: Qt.vector2d(0.9, 1.0)
        basePos: Qt.vector3d(0, root._capBottom, root._zOff - root._ud * root._S.capBack)
    }

    // The parting. A groove would be invisible at this polygon count - a box
    // cut into the cap is a box nobody sees - so it is a ridge of scalp
    // standing a whisker proud of the hair instead, in the head's own skin
    // colour. From the front it is a notch in the silhouette, from above a line.
    BodyPart {
        id: _part
        visible: root._S.part && _cap.visible
        color: root._head ? root._head.skinColor : "#d38d5f"
        width: root._uw * 0.055
        height: _cap.height * 1.03
        depth: _cap.depth * 1.01
        basePos: Qt.vector3d(root._uw * root._S.partX, _cap.basePos.y, _cap.basePos.z)
    }

    // The wide side of the part gets a little more hair on it. Asymmetry is
    // what makes a part read as a choice rather than as a seam.
    BodyPart {
        id: _sweepLump
        visible: root._S.part && _cap.visible
        color: root.tone
        width: root._uw * 0.42
        height: root._uh * 0.07 * root._v
        depth: _cap.depth * 0.86
        scaledFace: Box3DGeometry.TopFace
        faceScale: Qt.vector2d(0.85, 0.9)
        basePos: Qt.vector3d(root._uw * (root._S.partX - 0.22),
                             _cap.basePos.y + _cap.height - root._uh * 0.02,
                             _cap.basePos.z)
    }

    // --- the wave over the forehead ------------------------------------------
    // A slab standing on the front of the crown and leaning back. Only the
    // swept cut has one, and it is the whole reason that cut is recognisable
    // from the front: hair combed back that stays flat on the skull is hair
    // nobody can see until the camera goes round the back, which for a style
    // picked off a list is the same as no style at all.
    //
    // It leans rather than stands, and it starts at the crown rather than at
    // the hairline, so it reads as hair going somewhere instead of as a fin.
    BodyPart {
        id: _wave
        visible: root._S.waveH > 0 && _wave.height > root._uh * 0.01
        color: root.tone
        width: root._uw * root._S.waveW
        height: Math.max(0.001, root._uh * root._S.waveH * root._v)
        depth: root._ud * root._S.waveD
        // Narrower and thinner where it tips over: the wave is a roll of hair
        // and a roll has a far edge, not a top.
        scaledFace: Box3DGeometry.TopFace
        faceScale: Qt.vector2d(0.82, 0.55)
        // Negative x-rotation tips the box's own up axis toward -z, which here
        // is the back of the head.
        baseEuler: Qt.vector3d(-root._S.waveTilt, 0, 0)
        basePos: Qt.vector3d(0,
                             root._capTop - root._uh * 0.06,
                             root._zOff + root._ud * root._S.waveZ)
    }

    // --- the sides -----------------------------------------------------------
    // Centred ON the skull's side face, so half of each mass is inside the
    // head - the same trick Head.qml's own side hair uses, and the difference
    // between hair and two boards nailed to a skull.
    //
    // They are pushed back (sideZ) so the temples stay clear: that is where a
    // pair of spectacle arms runs, and where a fringe would start creeping
    // toward the eyes.
    component SideMass: BodyPart {
        id: _side
        property real side: 1
        visible: _side.height > root._uh * 0.01
        color: root.tone
        width: root._uw * root._S.sideW * (0.55 + 0.45 * root._v)
        height: Math.max(0.001, root._uh * root._S.sideH * root._v)
        depth: root._ud * root._S.sideD
        // Flaring at the top rather than the bottom, and narrowing front to
        // back as it goes: bushy hair is widest well above the ear and thins
        // toward the crown, while a mass that widens downward is a helmet strap.
        scaledFace: Box3DGeometry.TopFace
        faceScale: Qt.vector2d(root._S.sideFlare, root._S.sideFlareZ)
        // Tipped outward, so the two masses splay instead of standing to
        // attention. Small angles only - past about fifteen degrees the bottom
        // corner comes out of the skull and the mass reads as unglued.
        baseEuler: Qt.vector3d(0, 0, -_side.side * root._S.sideRoll)
        basePos: Qt.vector3d(_side.side * root._uw * 0.5,
                             root._base + root._uh * root._S.sideY,
                             root._zOff - root._ud * root._S.sideZ)
    }

    SideMass { side: -1 }
    SideMass { side: 1 }

    // --- the back ------------------------------------------------------------
    // Straddles the back face for the same reason the sides straddle theirs.
    // Without it every cut is bald from behind, and a lab camera goes behind a
    // character the first time somebody drags with the right mouse button.
    //
    // Wider than the skull on purpose: a mass narrower than the head is a mass
    // entirely inside the head's own silhouette, which from every angle except
    // straight from behind is a mass nobody can see.
    BodyPart {
        id: _back
        visible: _back.height > root._uh * 0.01
        color: root.tone
        width: root._uw * root._S.backW
        height: Math.max(0.001, root._uh * root._S.backH * root._v)
        depth: root._ud * root._S.backD
        scaledFace: Box3DGeometry.TopFace
        faceScale: Qt.vector2d(0.94, 1.0)
        basePos: Qt.vector3d(0,
                             root._base + root._uh * root._S.backY,
                             root._backZ + root._ud * root._S.backIn)
    }

    // --- the clumps ----------------------------------------------------------
    // The tufts. Few and broad, not many and thin: at this polygon count a
    // narrow tapered box is a needle, and a headful of evenly spaced needles is
    // a hedgehog. What reads as hair is a handful of masses about as wide at
    // the root as they are long, overlapping their neighbours, ending in a
    // blunt wedge and disagreeing with each other about size and direction.
    //
    // Count follows volume, but only weakly. A count proportional to volume
    // empties the head at low volume, and it is the coverage - no gap wide
    // enough to see the pad through - that has to survive, not the density.
    // Capped because this is drawn every frame inside a character that already
    // carries a beard and two ten-box hands.
    readonly property int _clumpCount:
        Math.max(0, Math.min(14, Math.round(_S.clumps * (0.6 + 0.4 * _v))))

    Repeater3D {
        model: root._clumpCount

        BodyPart {
            id: _clump
            required property int index

            // A hash, not a random number: the same professor every time. Five
            // of them, and the constants only serve to decorrelate the draws:
            // where round the crown it grows, how far out from the middle and
            // how thick, how long, which way it leans and how deep, and how far
            // over it leans. Length and lean have to come from different draws
            // or the head ends up combed by accident - every long clump would
            // be leaning the same way as every other long one.
            readonly property real _h1: {
                const x = Math.sin(_clump.index * 12.9898) * 43758.5453
                return x - Math.floor(x)
            }
            readonly property real _h2: {
                const x = Math.sin(_clump.index * 78.233) * 12345.6789
                return x - Math.floor(x)
            }
            readonly property real _h3: {
                const x = Math.sin(_clump.index * 39.425) * 24634.6345
                return x - Math.floor(x)
            }
            readonly property real _h4: {
                const x = Math.sin(_clump.index * 53.117) * 31415.9265
                return x - Math.floor(x)
            }
            readonly property real _h5: {
                const x = Math.sin(_clump.index * 27.619) * 17324.8971
                return x - Math.floor(x)
            }

            // Where on the crown it grows. Spread evenly around and then
            // nudged hard - at a jitter near one slot width the ring stops
            // being a ring and becomes a scatter, which is the point: even
            // spacing is what makes a head of hair look counted out. Gaps are
            // acceptable, bare scalp is not, and that is the pad's job.
            // 0 is the front of the skull, half a turn is the back.
            readonly property real _theta:
                (_clump.index + 0.5) / Math.max(1, root._clumpCount) * 2 * Math.PI
                + (_clump._h1 - 0.5) * root._S.jitter
            // How far out from the middle of the crown: 0 at the very top of
            // the skull, 1 at the rim. Square-rooted, which puts more of them
            // out at the rim than in the middle - spacing them evenly in
            // radius crowds the crown and leaves the outline, which is the
            // part anybody actually reads, thin.
            readonly property real _rf:
                root._S.ringInner
                + (1 - root._S.ringInner) * Math.sqrt(_clump._h2)

            // Which way it leans, as a direction rather than an angle so the
            // two cases blend: outward from the crown (leanBack 0, the wild
            // cut) through to all of them straight back (leanBack 1, combed).
            // Then thrown off that heading by up to half of cross, so
            // neighbours cross each other instead of fanning out like the
            // spokes of a wheel - hair that all points away from one spot is
            // hair that has been blown off the head, not grown on it.
            readonly property real _dirX: (1 - root._S.leanBack) * Math.sin(_clump._theta)
            readonly property real _dirZ: (1 - root._S.leanBack) * Math.cos(_clump._theta)
                                          - root._S.leanBack
            readonly property real _phi: Math.atan2(_clump._dirX, _clump._dirZ)
                                         + (_clump._h4 - 0.5) * root._S.cross

            // How much this one belongs to the side of the head rather than to
            // the crown: 0 straight ahead or straight back, 1 over an ear.
            readonly property real _sideness: Math.abs(Math.sin(_clump._theta))
            // How much it faces the forehead. Everything that has to be kept
            // away from the eyes is scaled by this.
            readonly property real _front: Math.max(0, Math.cos(_clump._theta))
            // The side ones slide down the skull. Squared, so the transition
            // from crown to bush happens over the last quarter turn instead of
            // tilting the whole ring - that gap over the temple is the
            // receded hairline the wild cut is built around.
            readonly property real _drop: root._S.sideDrop * _clump._rf
                                          * _clump._sideness * _clump._sideness

            // Clumps at the rim lean hardest, the ones that dropped down the
            // side lean right over into a bush, and how far over is a draw of
            // its own so that no two neighbours agree. The ones over the
            // forehead lean least: a clump hanging forward over a bare
            // forehead is the one thing in this file that can end up in front
            // of an eye. Capped well short of flat: a broad clump past about
            // sixty degrees stops being hair standing up and becomes a wing
            // sticking out, which is the failure mode a wide tuft has and a
            // needle does not.
            readonly property real _tilt: Math.min(62,
                root._S.tilt * (0.55 + 0.9 * _clump._h5)
                * (0.35 + 0.65 * _clump._rf)
                * (1 - 0.5 * _clump._front)
                + root._S.tiltSide * _clump._sideness * _clump._rf)

            // A leaning box pivots about its own base, so its lower corner
            // swings BELOW the point it is placed at - and the wider the clump
            // the further below. Half its footprint times the sine of the lean
            // is that corner, and the floor is raised by exactly that much.
            readonly property real _dip:
                0.5 * Math.max(_clump.width, _clump.depth)
                * Math.sin(_clump._tilt * Math.PI / 180)

            // How low this one may start. Out at the sides and round the back
            // that is the ear line - a caller who asks for a huge sideDrop
            // should get a bush, not sideburns. Toward the front it is the
            // face line instead, which is what keeps a big clump off the brow
            // and off a pair of glasses however wide and however tilted it is.
            readonly property real _floorY:
                root._base + 0.3 * root._uh
                + _clump._front * (root._faceFloor - root._base - 0.3 * root._uh)
                + _clump._dip

            readonly property real _baseY:
                Math.max(_clump._floorY,
                         root._capTop - root._uh * (root._S.clumpSink + _clump._drop))

            visible: _clump.height > root._uh * 0.02
            color: root.tone
            // Thinner as well as shorter when there is less hair, or a low
            // volume gives full-width tufts with the length taken off them,
            // which reads as a haircut rather than as thinner hair.
            width: root._uw * root._S.clumpW * (0.72 + 0.28 * root._v)
                   * (1 - root._S.widVar * 0.5 + root._S.widVar * _clump._h2)
            // Not square in plan. A clump with equal sides is a post; one
            // that is thin across the direction it leans is a lock of hair.
            depth: _clump.width * (0.75 + 0.4 * _clump._h4)
            // Tallest over the middle of the skull, and - where a style asks
            // for it - longer toward the back, toward the front, or out at the
            // ears. The spread around the mean is wide on purpose: clumps that
            // are all one length give a flat top edge, and the ragged edge is
            // the thing the eye actually reads as wild hair.
            height: Math.max(0.001,
                             root._uh * root._S.clumpLen * root._v
                             * (1 - root._S.lenVar * 0.5 + root._S.lenVar * _clump._h3)
                             * (1.25 - 0.5 * _clump._rf)
                             * (1 + root._S.backLong * 0.5
                                    * (1 - Math.cos(_clump._theta)))
                             * (1 + root._S.frontLong * 0.5
                                    * (1 + Math.cos(_clump._theta)))
                             * (1 + root._S.sideLong * _clump._sideness * _clump._rf))
            // A blunt wedge, not a point: real hair ends in a chopped-off tuft,
            // and a tip narrower than about a third of the root is thinner than
            // the edge line drawn around it - which turns the clump into a dark
            // smudge as soon as the professor is small on screen. The tip
            // loses more along the direction the clump leans than across it,
            // which makes the end a chisel rather than a stub.
            scaledFace: Box3DGeometry.TopFace
            faceScale: Qt.vector2d(root._S.clumpTip, root._S.clumpTip * 0.65)
            // The base sits inside the crown pad (clumpSink), so a clump
            // tilted about its own bottom corner still has that corner buried.
            basePos: Qt.vector3d(
                root._uw * 0.5 * root._S.ringX * _clump._rf * Math.sin(_clump._theta),
                _clump._baseY,
                root._zOff - root._ud * root._S.clumpBack
                + root._ud * 0.5 * root._S.ringZ * _clump._rf * Math.cos(_clump._theta))
            // Quick3D applies eulerRotation as Ry*Rx*Rz, so with no roll the
            // box's own up axis ends up leaning by _tilt in the compass
            // direction _phi - which is exactly the two numbers above.
            baseEuler: Qt.vector3d(_clump._tilt, _clump._phi * 180 / Math.PI, 0)
        }
    }
}
