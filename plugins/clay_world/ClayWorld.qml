// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.SvgUtils 1.0
import Clayground.ScalingCanvas 1.0
import Clayground.Physics 1.0

CoordCanvas
{
    id: theWorld
    anchors.fill: parent

    // General/Sandbox Mode
    property bool runsInSbx: true
    property string map: ""
    readonly property string _fullmappath: (!runsInSbx ? ":/" : ClayLiveLoader.sandboxDir)
                         + "/" + map
    readonly property string _resPrefix: !theWorld.runsInSbx ? "qrc:/" : "file:///" + ClayLiveLoader.sandboxDir + "/"
    function resource(path) {
        return theWorld._resPrefix + path
    }

    // Physics
    property bool physicsDebugging: false
    property alias gravity: thePhysicsWorld.gravity
    property alias timeStep: thePhysicsWorld.timeStep
    property alias physicsEnabled: thePhysicsWorld.running

    signal worldAboutToBeCreated()
    signal worldCreated()
    signal objectCreated(var obj)

    onWidthChanged: {
        if (width > 0) {
            theSvgInspector.setSource(_fullmappath);
            theCreator.start();
        }
    }

    Timer {
        id: theCreator
        interval: 10
        onTriggered: theWorld.worldCreated()
    }

    World {
        id: thePhysicsWorld
        gravity: Qt.point(0,15*9.81)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
    }

    Component {
        id: physDebugComp
        DebugDraw {parent: coordSys; world: thePhysicsWorld }
    }
    Loader { sourceComponent: physicsDebugging ? physDebugComp : null }

    // Workaround to support dynamic component creation
    // and type-checking without relying on context
    // specific instanceof
    function isInstanceOf(obj, typename) {
        let str = obj.toString();
        return str.indexOf(typename + "(") === 0 ||
                str.indexOf(typename + "_QML") === 0;
    }

    SvgInspector
    {
        id: theSvgInspector
        property var objs: []

        onBegin: {
            theWorld.viewPortCenterWuX = 0;
            theWorld.viewPortCenterWuY = 0;
            theWorld.worldXMax = widthWu;
            theWorld.worldYMax = heightWu;
            for (let obj of objs) if(obj) obj.destroy();
            objs = [];
        }

        function fetchComp(cfg) {
            let compStr = cfg["component"];
            if (!compStr.startsWith("qrc:"))
                compStr = theWorld._resPrefix + compStr;
            let comp = Qt.createComponent(compStr);
            if (comp.status !== Component.Ready) {
                console.error(comp.errorString());
            }
            return comp;
        }

        function customInit(obj, cfg) {
            let initVals = cfg["properties"];
            if (initVals){
                for (let p in initVals)
                    obj[p] = initVals[p];
            }
        }

        function box2dWorkaround(obj) {
           if (obj.bodyType !== Body.Static ) {
              let oldT = obj.bodyType;
              obj.bodyType = Body.Static;
              obj.bodyType = oldT;
           }
        }

        onPolygon: {
            let cfg = JSON.parse(description);
            let comp = fetchComp(cfg);
            let obj = comp.createObject(coordSys,
                                        {
                                            canvas: theWorld,
                                            world: thePhysicsWorld,
                                            vertices: points
                                        });
            customInit(obj, cfg);
            objs.push(obj);
            theWorld.objectCreated(obj);
            box2dWorkaround(obj);
        }

        onRectangle: {
            let cfg = JSON.parse(description);
            let comp = fetchComp(cfg);
            let obj = comp.createObject(coordSys,
                                        {
                                            world: thePhysicsWorld,
                                            xWu: x,
                                            yWu: y,
                                            widthWu: width,
                                            heightWu: height,
                                        });
            obj.pixelPerUnit = Qt.binding( _ => {return theWorld.pixelPerUnit;} );
            objs.push(obj);
            theWorld.objectCreated(obj);
            box2dWorkaround(obj);
        }
    }
}
