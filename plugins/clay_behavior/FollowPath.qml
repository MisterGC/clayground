// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.World
import Clayground.Canvas as Canv
import QtQuick.Shapes

/*!
    \qmltype FollowPath
    \inqmlmodule Clayground.Behavior
    \brief Makes an entity follow a predefined path of waypoints.

    FollowPath moves an actor through a sequence of waypoints using
    physics-based movement. It supports looping paths and provides
    debug visualization for development.

    Example usage:
    \qml
    import Clayground.Behavior

    RectBoxBody {
        id: guard

        FollowPath {
            world: theWorld
            wpsWu: [
                Qt.point(5, 5),
                Qt.point(10, 5),
                Qt.point(10, 10),
                Qt.point(5, 10)
            ]
            repeat: true
            running: true
            debug: true
        }
    }
    \endqml

    \sa MoveTo
*/
Item
{
    id: behavior

    /*!
        \qmlproperty ClayWorld2d FollowPath::world
        \brief The world context (required).
    */
    required property ClayWorld2d world

    /*!
        \qmlproperty var FollowPath::actor
        \brief The entity to move (defaults to parent).
    */
    property var actor: parent

    /*!
        \qmlproperty list FollowPath::wpsWu
        \brief Array of waypoints in world units.

        Each waypoint should be a Qt.point(x, y) object.
    */
    property var wpsWu: []

    property int _currentWpIndex: -1

    /*!
        \qmlproperty bool FollowPath::running
        \brief Whether path following is active.
    */
    property alias running: _moveto.running

    /*!
        \qmlproperty bool FollowPath::repeat
        \brief Loop back to the first waypoint when path completes.
    */
    property bool repeat: false

    /*!
        \qmlsignal FollowPath::arrived()
        \brief Emitted when the actor completes the path (when repeat is false).
    */
    signal arrived()

    onWpsWuChanged: _currentWpIndex = wpsWu.length > 0 ? 0 : -1

    /*!
        \qmlproperty bool FollowPath::debug
        \brief Show debug visualization of waypoints and path.
    */
    property alias debug: _moveto.debug

    /*!
        \qmlproperty color FollowPath::debugColor
        \brief Color for debug visualization.
    */
    property alias debugColor: _moveto.debugColor

    Component {
        id: debugVisu
        Item{
            id: item
            parent: behavior
            Timer {id: createWps; running: true; interval: 1; onTriggered: createWpVisu();}
            function createWpVisu() {
                for (let i=0; i<wpsWu.length; ++i){
                    let obj = wpComp.createObject(behavior.world.room);
                    obj.xWu = Qt.binding(_ => {return behavior.wpsWu[i].x - .5 * obj.widthWu});
                    obj.yWu = Qt.binding(_ => {return behavior.wpsWu[i].y + .5 * obj.heightWu});
                }
            }
            Canv.Poly {canvas: world.canvas; opacity: .75
                vertices: wpsWu; strokeStyle: ShapePath.DashLine; strokeWidth: 3; strokeColor: Qt.darker(_moveto.debugColor, 1.2); }
            Component{
                id: wpComp
                Canv.Rectangle{
                    radius: height * .25
                    color: Qt.darker(behavior.debugColor, 1.7)
                    canvas: world.canvas
                    widthWu: .3; heightWu: .3;
                }
            }
        }
    }
    Loader{sourceComponent: behavior.debug ? debugVisu : null}

    MoveTo {
        id: _moveto; parent: actor; actor: behavior.actor; world: behavior.world;
        debug: true
        anchors.centerIn: parent; destXWu: actor.xWu; destYWu: actor.yWu
        onArrived: {
            if (_currentWpIndex < wpsWu.length -1) _currentWpIndex++;
            else {
                if (!repeat) {behavior.running = false; behavior.arrived();}
                else _currentWpIndex = 0;
            }
        }
    }

    on_CurrentWpIndexChanged: {
        if (_currentWpIndex >= 0 && _currentWpIndex < wpsWu.length) {
            let wp = wpsWu[_currentWpIndex];
            _moveto.destXWu = wp.x;
            _moveto.destYWu = wp.y;
        }
    }
}
