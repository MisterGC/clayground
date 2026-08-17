// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Puff - the little cloud something arrives in and leaves by.
//
// Deliberately NOT a particle system. Nothing in this repo uses QtQuick3D's
// particles, and a realistic smoke cloud would be the one photographic thing
// in a world drawn as paper and ink. This is a cartoon puff instead: a ring
// that runs outward along the ground like a shockwave, and a handful of blobs
// thrown out and up. Two shapes, one clock.
//
// Nothing here consumes randomness. The blob directions are a hash of the
// blob's index, so the same puff comes out the same way every time - which is
// what lets a lab screenshot it and a flow replay it.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab

Node {
    id: root

    /*! The colour of the cloud. */
    property color tone: LabTheme.soft

    /*! How far the ring and the blobs travel, in world units. */
    property real radius: 1.6

    /*! How long one burst lasts. */
    property int duration: 420

    /*! How many blobs are thrown. More reads as smoke, fewer as a cartoon. */
    property int blobs: 9

    /*! True while a burst is playing. */
    readonly property bool running: _clock.running

    /*!
        Plays one burst. Calling it again restarts it, so an appear immediately
        followed by a vanish does not leave half a cloud hanging in the air.
    */
    function burst() {
        _clock.stop()
        _t = 0
        _clock.start()
    }

    // 0 at the moment of the burst, 1 when the cloud has gone.
    property real _t: 0
    visible: _t > 0 && _t < 1

    NumberAnimation {
        id: _clock
        target: root
        property: "_t"
        from: 0; to: 1
        duration: root.duration
        // out of the gate fast and then coasting: a puff is an event, and an
        // event that eases IN reads as a machine starting up
        easing.type: Easing.OutQuad
    }

    // Everything fades on the same curve, but the ring outlives the blobs by a
    // hair so the last thing you see is the shape rather than the crumbs.
    readonly property real _fade: Math.max(0, 1 - root._t)

    // --- the shockwave ------------------------------------------------------
    // A ring rather than a disc: a disc on the ground reads as a shadow, and
    // this has to read as air being pushed.
    LineBatch3D {
        widthUnits: LineBatch3D.World
        orientation: LineBatch3D.Flat
        opaque: false
        castsShadows: false
        depthBias: 2
        opacity: root._fade
        lines: {
            const r = root.radius * (0.15 + 0.85 * root._t)
            const pts = [], n = 24
            for (let i = 0; i <= n; ++i) {
                const a = i / n * 2 * Math.PI
                pts.push(Qt.vector3d(Math.cos(a) * r, 0.06, Math.sin(a) * r))
            }
            // thins as it spreads, the way a real ring of dust does
            return [{ points: pts, color: root.tone,
                      width: 0.13 * (1 - 0.6 * root._t), styleId: 0 }]
        }
    }

    // --- the blobs ----------------------------------------------------------
    Repeater3D {
        model: root.blobs

        Model {
            id: blob
            required property int index

            // A hash, not a random number: same puff every time. The three
            // constants are only there to decorrelate the three components.
            readonly property real _h1: {
                const x = Math.sin(blob.index * 12.9898) * 43758.5453
                return x - Math.floor(x)
            }
            readonly property real _h2: {
                const x = Math.sin(blob.index * 78.233) * 12345.6789
                return x - Math.floor(x)
            }

            // Spread evenly around the circle and then nudged, so the cloud is
            // even without looking counted out.
            readonly property real _angle:
                (blob.index / root.blobs) * 2 * Math.PI + (blob._h1 - 0.5) * 0.7
            readonly property real _reach: root.radius * (0.95 + 0.55 * blob._h2)
            // thrown up and falling back: the arc is what makes it air rather
            // than a ring of dots sliding outward
            readonly property real _rise: root.radius * (0.5 + 0.5 * blob._h1)

            source: "#Sphere"
            castsShadows: false
            // Starts a third of the way out, not at the middle: whatever the
            // puff is delivering is standing in the middle, and blobs born
            // inside it are blobs nobody sees.
            readonly property real _out: blob._reach * (0.35 + 0.65 * root._t)
            position: Qt.vector3d(
                Math.cos(blob._angle) * blob._out,
                blob._rise * Math.sin(root._t * Math.PI) + 0.15,
                Math.sin(blob._angle) * blob._out)
            // grows as it flies and then thins away - a puff dissipates, it
            // does not shrink back to a point
            scale: {
                const s = 0.011 * (0.55 + 1.1 * root._t) * (0.7 + 0.6 * blob._h2)
                return Qt.vector3d(s, s, s)
            }
            // linear, not squared: squared looked correct in the maths and
            // invisible on the paper-pale ground it is drawn against
            opacity: root._fade
            materials: PrincipledMaterial {
                baseColor: root.tone
                lighting: PrincipledMaterial.NoLighting
                alphaMode: PrincipledMaterial.Blend
            }
        }
    }
}
