// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.World

/*!
    \qmltype NavigateTo
    \inqmlmodule Clayground.Behavior
    \brief Obstacle-aware navigation combining GridPathfinder with FollowPath.

    NavigateTo converts world-unit destinations to grid coordinates,
    computes a path using A*, and feeds the resulting waypoints to
    FollowPath for physics-based movement. It periodically recalculates
    the path to handle moving targets.

    Example usage:
    \qml
    import Clayground.Behavior

    RectBoxBody {
        id: enemy

        NavigateTo {
            world: theWorld
            pathfinder: levelPathfinder
            destXWu: player.xWu
            destYWu: player.yWu
            cellSize: 2
            running: true
            desiredSpeed: 3
            recalcInterval: 500
            onArrived: console.log("Reached target!")
        }
    }
    \endqml

    \sa FollowPath, MoveTo, GridPathfinder
*/
Item {
    id: behavior

    /*!
        \qmlproperty ClayWorld2d NavigateTo::world
        \brief The world context (required).
    */
    required property ClayWorld2d world

    /*!
        \qmlproperty var NavigateTo::actor
        \brief The entity to move (defaults to parent).
    */
    property var actor: parent

    /*!
        \qmlproperty GridPathfinder NavigateTo::pathfinder
        \brief The pathfinder instance to use for computing paths (required).
    */
    required property var pathfinder

    /*!
        \qmlproperty real NavigateTo::destXWu
        \brief Destination X coordinate in world units.
    */
    property real destXWu: 0

    /*!
        \qmlproperty real NavigateTo::destYWu
        \brief Destination Y coordinate in world units.
    */
    property real destYWu: 0

    /*!
        \qmlproperty real NavigateTo::cellSize
        \brief World units per grid cell (default: 1).
    */
    property real cellSize: 1

    /*!
        \qmlproperty bool NavigateTo::running
        \brief Whether navigation is active.
    */
    property bool running: false
    onRunningChanged: {
        if (running) {
            _recalc();
        } else {
            _followPath.running = false;
        }
    }

    /*!
        \qmlproperty real NavigateTo::desiredSpeed
        \brief Movement speed in world units per second (default: 2).
    */
    property real desiredSpeed: 2

    /*!
        \qmlproperty int NavigateTo::recalcInterval
        \brief Milliseconds between path recalculations (default: 500).
    */
    property int recalcInterval: 500

    /*!
        \qmlproperty bool NavigateTo::debug
        \brief Show debug visualization of path.
    */
    property alias debug: _followPath.debug

    /*!
        \qmlproperty color NavigateTo::debugColor
        \brief Color for debug visualization.
    */
    property alias debugColor: _followPath.debugColor

    /*!
        \qmlsignal NavigateTo::arrived()
        \brief Emitted when the actor reaches the destination.
    */
    signal arrived()

    Timer {
        id: _recalcTimer
        interval: behavior.recalcInterval
        repeat: true
        running: behavior.running
        onTriggered: behavior._recalc()
    }

    FollowPath {
        id: _followPath
        world: behavior.world
        actor: behavior.actor
        parent: behavior.actor
        anchors.centerIn: parent
        desiredSpeed: behavior.desiredSpeed
        running: false
        onArrived: behavior.arrived()
    }

    function _recalc() {
        if (!pathfinder || !actor || !running) return;

        let cs = cellSize;

        // Skip recalc if already close to destination
        let dx = actor.xWu - destXWu;
        let dy = actor.yWu - destYWu;
        if (Math.sqrt(dx*dx + dy*dy) < cs) {
            _followPath.running = false;
            arrived();
            return;
        }

        let sx = Math.floor(actor.xWu / cs);
        let sy = Math.floor(actor.yWu / cs);
        let ex = Math.floor(destXWu / cs);
        let ey = Math.floor(destYWu / cs);

        // Clamp to grid bounds
        sx = Math.max(0, Math.min(sx, pathfinder.columns - 1));
        sy = Math.max(0, Math.min(sy, pathfinder.rows - 1));
        ex = Math.max(0, Math.min(ex, pathfinder.columns - 1));
        ey = Math.max(0, Math.min(ey, pathfinder.rows - 1));

        let gridPath = pathfinder.findPath(sx, sy, ex, ey);
        if (gridPath.length === 0) return;

        // Convert grid coords back to world units (cell center)
        let wps = [];
        for (let i = 1; i < gridPath.length; ++i) {
            wps.push(Qt.point(gridPath[i].x * cs + cs * 0.5,
                              gridPath[i].y * cs + cs * 0.5));
        }
        if (wps.length === 0) return;

        _followPath.running = false;
        _followPath.wpsWu = wps;
        _followPath.running = true;
    }
}
