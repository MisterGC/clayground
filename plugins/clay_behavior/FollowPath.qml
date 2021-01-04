// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import Clayground.World 1.0
import Clayground.Canvas 1.0 as Canv

Item
{
    id: behavior

    required property ClayWorld world
    property var actor: parent
    property var wpsWu: []
    property int _currentWpIndex: -1
    property alias running: _moveto.running
    property bool repeat: false

    signal arrived()

    onWpsWuChanged: _currentWpIndex = 0

    property alias debug: _moveto.debug
    property alias debugColor: _moveto.debugColor

    Component {
        id: debugVisu
        Item{
            parent: behavior
            Canv.Poly {canvas: world; vertices: wpsWu; strokeWidth: 3; strokeColor: Qt.darker(_moveto.debugColor, 1.2); }
            Repeater{
                model: wpsWu.length
                Canv.Rectangle{
                    radius: height * .25
                    color: Qt.darker(_moveto.debugColor, 1.7)
                    canvas: world
                    xWu: wpsWu[index].x - .5 * widthWu; yWu: wpsWu[index].y + .5 *  heightWu
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
