// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "lanemodel.js" as LaneModel

/*!
    \qmltype Cars3D
    \inqmlmodule Clayground.Kits.Traffic
    \brief Instanced cars driving a lane model.

    Two instanced models - body and cabin - for the whole population, so the
    cost of a car is four floats in a buffer rather than a QObject. Hand it the
    derived network and the sim's car list and call \l sync() once per frame.

    Slots are held for a car's LIFETIME, not reassigned per frame: the colour
    lives on the slot, so a car that kept changing slots would flicker through
    the palette as it drove.
*/
Node {
    id: root

    /*! \qmlproperty var Cars3D::net \brief The derived lane model (see lanemodel.js). */
    property var net: null

    /*! \qmlproperty var Cars3D::cars \brief The sim's live car array. */
    property var cars: []

    /*! \qmlproperty int Cars3D::capacity \brief Maximum simultaneous cars. */
    property int capacity: 160

    /*! \qmlproperty real Cars3D::roadY \brief Height of the road surface the cars sit on. */
    property real roadY: 0.07

    /*! \qmlproperty real Cars3D::carLength \brief Body length along the direction of travel. */
    property real carLength: 4.4

    /*! \qmlproperty real Cars3D::carWidth \brief Body width. */
    property real carWidth: 2.1

    /*! \qmlproperty real Cars3D::carHeight \brief Body height. */
    property real carHeight: 1.15

    /*! \qmlproperty bool Cars3D::castsShadows \brief Whether cars drop a shadow on the board. */
    property bool castsShadows: true

    /*! \qmlproperty var Cars3D::palette \brief Body colours, cycled over the slots. */
    property var palette: [LabTheme.clay, LabTheme.teal, LabTheme.plum,
                           LabTheme.forest, LabTheme.highlight, LabTheme.secondary]

    /*!
        \qmlproperty real Cars3D::fleetAlpha
        \brief Whole-population opacity, 0..1; multiplies each car's own alpha.

        It exists so a lab can dissolve the entire fleet on the WALL clock when
        the simulation is stopped. A fade driven from sim time would freeze
        half-way, because stopping the sim is what stopped that clock.
    */
    property real fleetAlpha: 1.0

    /*!
        \qmlproperty color Cars3D::fadeTarget
        \brief What a fading car dissolves towards.

        Per-instance alpha is not something every material path honours, so a
        car fading at a dead end ALSO lerps its colour towards the road beneath
        it. That way it reads as fading whether or not the blend takes.
    */
    property color fadeTarget: "#8d8880"

    /*! \qmlproperty int Cars3D::liveCount \readonly \brief Cars currently drawn. */
    readonly property alias liveCount: root._live
    property int _live: 0

    // slot bookkeeping: car id -> slot, plus the free list
    property var _slotOf: ({})
    property var _free: []
    property var _alphaOf: []
    property var _poseBody: null
    property var _poseCabin: null
    property bool _ready: false

    Component.onCompleted: _build()
    onCapacityChanged: _build()
    // a fleet-wide fade has to repaint the table even when no car moved
    onFleetAlphaChanged: if (_ready) sync()

    function _build() {
        var scales = [], colors = [], cabScales = [], cabColors = []
        _free = []
        _slotOf = ({})
        _alphaOf = []
        for (var i = 0; i < capacity; ++i) {
            var c = palette[i % palette.length]
            scales.push(Qt.vector3d(carWidth / 100, carHeight / 100, carLength / 100))
            colors.push(c)
            // The cabin must read as part of the car, not as a second one: it
            // is narrower than the body, sits LOW enough to overlap it, and is
            // only nudged back far enough to say which end is the front.
            cabScales.push(Qt.vector3d(carWidth * 0.72 / 100, carHeight * 0.55 / 100,
                                       carLength * 0.40 / 100))
            cabColors.push(Qt.darker(c, 1.45))
            _free.push(capacity - 1 - i)     // hand out low slots first
            _alphaOf.push(-1)
        }
        bodyInst.setBulk(scales, colors)
        cabinInst.setBulk(cabScales, cabColors)
        // parked below the table until a car claims the slot
        _poseBody = new Float32Array(capacity * 4)
        _poseCabin = new Float32Array(capacity * 4)
        for (var p = 0; p < capacity; ++p) _park(p)
        bodyInst.updatePoses(0, _poseBody.buffer)
        cabinInst.updatePoses(0, _poseCabin.buffer)
        // the roaming volume is the board, so Qt need not recompute it per upload
        bodyInst.setExtents(Qt.vector3d(-600, -10, -600), Qt.vector3d(600, 10, 600))
        cabinInst.setExtents(Qt.vector3d(-600, -10, -600), Qt.vector3d(600, 10, 600))
        _ready = true
    }

    function _park(slot) {
        _poseBody[slot * 4 + 1] = -1000
        _poseCabin[slot * 4 + 1] = -1000
    }

    /*!
        \qmlmethod void Cars3D::sync()
        \brief Repacks every live car into the instance tables. Call once per frame.
    */
    function sync() {
        if (!_ready || !net) return
        var seen = {}
        var n = 0
        for (var i = 0; i < cars.length && n < capacity; ++i) {
            var car = cars[i]
            var slot = _slotOf[car.id]
            if (slot === undefined) {
                if (!_free.length) continue
                slot = _free.pop()
                _slotOf[car.id] = slot
                _alphaOf[slot] = -1
            }
            seen[car.id] = true

            var pose = LaneModel.poseOn(net, car.kind, car.idx, car.s)
            var b = slot * 4
            _poseBody[b] = pose.x
            _poseBody[b + 1] = roadY + carHeight * 0.5
            _poseBody[b + 2] = pose.z
            _poseBody[b + 3] = pose.yaw

            // the cabin sits back from the nose, which is what makes the
            // direction of travel readable at a glance from above
            var back = -carLength * 0.10
            _poseCabin[b] = pose.x + Math.sin(pose.yaw) * back
            _poseCabin[b + 1] = roadY + carHeight * 0.5 + carHeight * 0.34
            _poseCabin[b + 2] = pose.z + Math.cos(pose.yaw) * back
            _poseCabin[b + 3] = pose.yaw

            var a = (car.alpha === undefined ? 1 : car.alpha) * fleetAlpha
            if (Math.abs(a - _alphaOf[slot]) > 0.03) {
                _alphaOf[slot] = a
                var base = palette[slot % palette.length]
                var col = Qt.rgba(base.r + (fadeTarget.r - base.r) * (1 - a),
                                  base.g + (fadeTarget.g - base.g) * (1 - a),
                                  base.b + (fadeTarget.b - base.b) * (1 - a), a)
                bodyInst.setEntryColor(slot, col)
                cabinInst.setEntryColor(slot, Qt.darker(col, 1.45))
            }
            ++n
        }
        // hand back the slots of cars that are gone
        for (var id in _slotOf) {
            if (seen[id]) continue
            var s = _slotOf[id]
            _park(s)
            _alphaOf[s] = -1
            _free.push(s)
            delete _slotOf[id]
        }
        _live = n
        bodyInst.updatePoses(0, _poseBody.buffer)
        cabinInst.updatePoses(0, _poseCabin.buffer)
    }

    Model {
        source: "#Cube"
        castsShadows: root.castsShadows
        receivesShadows: false
        instancing: DynamicInstances3D { id: bodyInst; capacity: root.capacity }
        materials: PrincipledMaterial {
            baseColor: "white"
            roughness: 1.0; metalness: 0.0; specularAmount: 0.0
            alphaMode: PrincipledMaterial.Blend
        }
    }
    Model {
        source: "#Cube"
        castsShadows: false
        receivesShadows: false
        instancing: DynamicInstances3D { id: cabinInst; capacity: root.capacity }
        materials: PrincipledMaterial {
            baseColor: "white"
            roughness: 1.0; metalness: 0.0; specularAmount: 0.0
            alphaMode: PrincipledMaterial.Blend
        }
    }
}
