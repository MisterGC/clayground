// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import Clayground.World
import Clayground.Canvas as Canv
import QtQuick.Shapes

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

    onWpsWuChanged: _currentWpIndex = wpsWu.length > 0 ? 0 : -1

    property alias debug: _moveto.debug
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
            Canv.Poly {canvas: world; opacity: .75
                vertices: wpsWu; strokeStyle: ShapePath.DashLine; strokeWidth: 3; strokeColor: Qt.darker(_moveto.debugColor, 1.2); }
            Component{
                id: wpComp
                Canv.Rectangle{
                    radius: height * .25
                    color: Qt.darker(behavior.debugColor, 1.7)
                    canvas: world
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
