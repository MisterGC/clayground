// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "lanemodel.js" as LaneModel

/*!
    \qmltype Streets3D
    \inqmlmodule Clayground.Kits.Traffic
    \brief Draws a derived lane model as asphalt, paint and lane overlay.

    Four layers, stacked by height and depth bias so they never fight:

    \list
    \li \b asphalt - one flat ribbon per road, plus a paved disc at every
        junction. The ribbons run the full length of the road and simply
        disappear under the discs; overlapping asphalt is invisible, and it
        saves mitring every corner.
    \li \b paint - kerb lines and the centre line, trimmed at the boxes.
    \li \b lanes - the teal lane model: centerlines and turn curves. This is
        the layer that says what the asphalt \e means, and the one the lesson
        is about.
    \li \b flow - chevrons marching along each lane at a speed set by
        \l flowOf, relative to the busiest lane on the board.
    \endlist

    Every line lies \c Flat in the ground plane rather than billboarding: a
    camera-facing ribbon splays open on a curve, and cannot cast a shadow.
*/
Node {
    id: root

    /*! \qmlproperty var Streets3D::net \brief The derived lane model. */
    property var net: null

    /*! \qmlproperty real Streets3D::surfaceY \brief Height of the road surface. */
    property real surfaceY: 0.07

    /*! \qmlproperty bool Streets3D::showLanes \brief Show the lane-model overlay. */
    property bool showLanes: true

    /*! \qmlproperty bool Streets3D::showPaint \brief Show kerb and centre lines. */
    property bool showPaint: true

    /*! \qmlproperty real Streets3D::flowTime \brief Chevron phase; bind to the SimClock. */
    property real flowTime: 0

    /*!
        \qmlproperty var Streets3D::flowOf
        \brief Optional \c function(laneIndex) returning 0..1 - how busy that lane is.

        Null means "no flow": the lane model is drawn as static lines. The
        value is RELATIVE to the busiest lane, so a junction that splits a
        stream visibly splits its chevron speed too.
    */
    property var flowOf: null

    /*!
        \qmlproperty int Streets3D::flowRev
        \brief Bump this when \l flowOf would return different buckets.

        \l flowOf is a stable closure reading live state, so nothing tells the
        batch its styles went stale. Bumping a counter a few times a second is
        what re-bakes the chevrons - rebuilding every frame would throw the
        whole line batch away sixty times a second for an animation the GPU is
        already running on its own.
    */
    property int flowRev: 0

    /*! \qmlproperty int Streets3D::hoveredRoad \brief Road id under the cursor, or -1. */
    property int hoveredRoad: -1

    /*! \qmlproperty int Streets3D::selectedRoad \brief Selected road id, or -1. */
    property int selectedRoad: -1

    /*!
        \qmlproperty int Streets3D::activeNode
        \brief Junction whose turns are being edited, or -1.

        Its turn curves are drawn forward in the lane colour instead of faint,
        because they become clickable at the same moment.
    */
    property int activeNode: -1

    /*! \qmlproperty int Streets3D::hoveredTurn \brief Turn curve under the cursor, or -1. */
    property int hoveredTurn: -1

    /*! \qmlproperty bool Streets3D::eraser \brief Tints the hover mark as a removal. */
    property bool eraser: false

    property color asphalt: "#b6b0a6"
    property color kerbPaint: "#f4f1ea"
    property color centrePaint: "#d9c48a"
    property color laneColor: LabTheme.teal
    property color connColor: "#9a948b"
    property color deadEndColor: LabTheme.accent

    // one repaint dependency for everything the geometry reads
    readonly property int _rev: (net ? net.stats.lanes : 0)
                                + (net ? net.stats.bannedTurns * 7919 : 0)
                                + hoveredRoad * 31 + selectedRoad * 131
                                + activeNode * 523 + hoveredTurn * 1291
                                + (showLanes ? 1 : 0) + (showPaint ? 2 : 0)
                                + (eraser ? 4 : 0)

    readonly property color _markColor: eraser ? LabTheme.alarm : LabTheme.secondary

    // A run from the kit is flat [x, z, x, z, ...]; lift it into the batch's
    // world points at our own height. The kit stays free of Qt types so it can
    // run under node, and this is the one place that costs.
    function _lift(runs, y) {
        var out = []
        for (var i = 0; i < runs.length; ++i) {
            var r = runs[i], pts = []
            for (var p = 0; p < r.xz.length; p += 2)
                pts.push(Qt.vector3d(r.xz[p], y, r.xz[p + 1]))
            out.push({ points: pts, color: r.color, width: r.width,
                       styleId: r.styleId })
        }
        return out
    }

    // ---- asphalt ------------------------------------------------------------
    LineBatch3D {
        widthUnits: LineBatch3D.World
        orientation: LineBatch3D.Flat
        opaque: true
        depthBias: 2
        castsShadows: false
        styles: [{ dash: [0, 0], capRound: false, opacity: 1.0 }]
        lines: {
            root._rev
            if (!root.net) return []
            return root._lift(LaneModel.surfaceRuns(root.net, root.asphalt),
                              root.surfaceY)
        }
    }

    // Paved discs at the junctions: they cover the trimmed lane ends and give
    // a crossing the rounded corners a mitred ribbon would not.
    Repeater3D {
        model: root.net ? root.net.nodes : []
        Model {
            required property var modelData
            source: "#Cylinder"
            visible: modelData.degree >= 2
            castsShadows: false
            position: Qt.vector3d(modelData.x, root.surfaceY - 0.012, modelData.z)
            scale: Qt.vector3d(modelData.pad * 2 / 100, 0.0002, modelData.pad * 2 / 100)
            materials: PrincipledMaterial {
                baseColor: root.asphalt
                roughness: 1.0; metalness: 0.0; specularAmount: 0.0
            }
        }
    }

    // ---- paint --------------------------------------------------------------
    LineBatch3D {
        visible: root.showPaint
        widthUnits: LineBatch3D.World
        orientation: LineBatch3D.Flat
        opaque: true
        depthBias: 6
        castsShadows: false
        styles: [{ dash: [0, 0], capRound: false, opacity: 1.0 },
                 { dash: [2.6, 2.6], capRound: false, opacity: 1.0 }]
        lines: {
            root._rev
            if (!root.net) return []
            var runs = LaneModel.markingRuns(root.net, {
                edgeColor: root.kerbPaint, centreColor: root.centrePaint })
            // the selected road wears its outline in ink, the hovered one a
            // thinner mark: the same language the other labs use for "this one"
            for (var i = 0; i < runs.length; ++i) {
                var sel = runs[i].roadId === root.selectedRoad
                var hov = runs[i].roadId === root.hoveredRoad
                if (!sel && !hov) continue
                if (runs[i].kind !== "edge") continue
                // hover is a quiet outline, selection a firm one - the gap
                // between them has to be visible or they read as one state
                runs[i].color = sel ? LabTheme.secondary : root._markColor
                runs[i].width = sel ? 0.66 : 0.30
            }
            // a centre line is dashed on a one-lane road, solid on a wider one
            for (var k = 0; k < runs.length; ++k)
                if (runs[k].kind === "centre") runs[k].styleId = 1
            return root._lift(runs, root.surfaceY + 0.02)
        }
    }

    // ---- lane model ---------------------------------------------------------
    LineBatch3D {
        visible: root.showLanes
        widthUnits: LineBatch3D.World
        orientation: LineBatch3D.Flat
        depthBias: 10
        castsShadows: false
        flowTime: root.flowTime
        flowAutoPlay: false
        // 0 is the resting lane; 1..6 march chevrons at increasing speed. Kept
        // unhurried on purpose - the flow is there to be read, not to fizz.
        styles: [
            { dash: [0, 0], capRound: true, opacity: 1.0 },
            { dash: [1.2, 3.0], pattern: "chevron", flow: 0.9 },
            { dash: [1.2, 3.0], pattern: "chevron", flow: 1.6 },
            { dash: [1.2, 3.0], pattern: "chevron", flow: 2.5 },
            { dash: [1.2, 3.0], pattern: "chevron", flow: 3.6 },
            { dash: [1.2, 3.0], pattern: "chevron", flow: 4.9 },
            { dash: [1.2, 3.0], pattern: "chevron", flow: 6.4 },
            // 7: a banned movement - dashed, so "switched off" reads at a
            // glance and can be switched back on
            { dash: [1.6, 1.6], capRound: false, opacity: 1.0 }
        ]
        lines: {
            root._rev; root.flowOf; root.flowRev
            if (!root.net) return []
            var f = root.flowOf
            var runs = LaneModel.laneRuns(root.net, {
                laneColor: root.laneColor, connColor: root.connColor,
                deadColor: root.deadEndColor, width: 0.34,
                banColor: LabTheme.alarm, banStyleId: 7,
                highlightNode: root.activeNode,
                styleOf: function (i) {
                    if (!f) return 0
                    var rel = f(i)
                    if (!(rel > 0.02)) return 0
                    return 1 + Math.min(5, Math.max(0, Math.round(rel * 5)))
                }
            })
            // the turn under the cursor answers before it is clicked
            for (var h = 0; h < runs.length; ++h) {
                if (runs[h].connIdx === undefined) continue
                if (runs[h].connIdx !== root.hoveredTurn) continue
                runs[h].color = LabTheme.secondary
                runs[h].width = 0.62
            }
            return root._lift(runs, root.surfaceY + 0.05)
        }
    }
}
