// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Hoverboard - what the professor travels on, and the reason it never has to
// walk.
//
// A walk cycle for a blocky character is a lot of animation to get wrong: legs
// that skate, feet that sink, a gait that has to be re-timed for every speed
// and every leg length. A board removes the problem rather than solving it.
// The figure keeps its standing pose, the whole thing translates, and the only
// thing that has to look right is the lean - which is one angle.
//
// It is also the honest reading. A professor who arrives at the tree by
// gliding there is obviously being moved by the lab; one who arrives walking
// invites the viewer to judge the walk.
//
// Everything is a fraction of `length`, so a board under a taller professor is
// a bigger board and not a longer one with the same thickness.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D

Node {
    id: root

    /*! Nose to tail, in world units. Everything else follows from it. */
    property real length: 1.0

    /*! The deck. */
    property color deckTone: "#2f3437"

    /*! The underside, and it is meant to look powered rather than painted. */
    property color glowTone: "#00d9ff"

    /*!
        0 parked, 1 flying. Fades the board in as it powers up rather than
        having it blink into existence under a pair of feet, and drives how
        far the glow stands off the underside.
    */
    property real energy: 0

    visible: root.energy > 0.01
    opacity: Math.min(1, root.energy * 1.6)

    // Wider than a real board relative to its length. A correctly-proportioned
    // one disappears under a character this square, and the board has to read
    // from the same distance the professor does.
    readonly property real _w: root.length * 0.42
    readonly property real _t: root.length * 0.07

    // The character stands with its feet at y = 0, so the deck hangs entirely
    // below that line - a board whose top face is at the feet is a board the
    // professor is standing inside.
    readonly property real _top: -root.length * 0.02

    // --- the deck -------------------------------------------------------------
    // Three boxes: the plank, and two ends that turn up. The turned-up ends are
    // most of what says "board" - a flat slab reads as a paving stone, and at
    // this polygon count the silhouette is the only thing carrying it.

    Box3D {
        id: _deck
        color: root.deckTone
        width: root._w
        height: root._t
        depth: root.length * 0.62
        position: Qt.vector3d(0, root._top - root._t, 0)
    }

    component Tip: Box3D {
        id: _tip
        // +1 nose (the character faces +Z), -1 tail.
        required property real end
        color: root.deckTone
        width: root._w * 0.82
        height: root._t
        depth: root.length * 0.22
        // Narrowing toward the tip as well as lifting: a rectangle tilted up
        // is a ramp, a taper tilted up is a nose.
        scaledFace: Box3DGeometry.FrontFace
        faceScale: Qt.vector2d(0.7, 1.0)
        eulerRotation: Qt.vector3d(-_tip.end * 16, _tip.end > 0 ? 0 : 180, 0)
        position: Qt.vector3d(0,
                              root._top - root._t * 0.85,
                              _tip.end * (_deck.depth + _tip.depth) * 0.48)
    }

    Tip { end: 1 }
    Tip { end: -1 }

    // --- what holds it up -----------------------------------------------------
    // Unlit, so it stays the same bright colour whichever way the board is
    // tilted - a shaded glow is a painted stripe. It grows and sinks with the
    // energy, which is the whole of the "powered" reading.

    Box3D {
        id: _glow
        color: root.glowTone
        lighting: PrincipledMaterial.NoLighting
        showEdges: false
        castsShadows: false
        width: root._w * (0.55 + 0.25 * root.energy)
        height: root._t * 0.5
        depth: _deck.depth * (0.6 + 0.3 * root.energy)
        opacity: 0.35 + 0.65 * root.energy
        position: Qt.vector3d(0,
                              _deck.position.y - _glow.height * (0.9 + 0.9 * root.energy),
                              0)
    }
}
