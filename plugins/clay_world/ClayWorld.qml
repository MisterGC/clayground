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
    readonly property string _fullmappath: (map.length === 0 ? ""
        : ((!runsInSbx ? ":/" : ClayLiveLoader.sandboxDir)
                         + "/" + map))
    readonly property string _resPrefix: !theWorld.runsInSbx ? "qrc:/" : "file:///" + ClayLiveLoader.sandboxDir + "/"
    function resource(path) {
        return theWorld._resPrefix + path
    }

    // Physics
    property World physics: thePhysicsWorld
    property bool physicsDebugging: false
    property alias gravity: thePhysicsWorld.gravity
    property alias timeStep: thePhysicsWorld.timeStep
    property alias physicsEnabled: thePhysicsWorld.running

    signal worldAboutToBeCreated()
    signal worldCreated()
    signal objectCreated(var obj)

    property alias entities: theSvgInspector.entities
    // Signals which are emitted when elements have
    // been loaded which are not yet processed by
    // ClayWorld functionality
    signal polylineLoaded(var points, var description)
    signal polygonLoaded(var points, var description)
    signal rectangleLoaded(var x, var y, var width, var height, var description)
    signal circleLoaded(var x, var y, var radius, var description)

    onWidthChanged: _refreshMap();
    on_FullmappathChanged: _refreshMap();

    function _refreshMap() {
        if (width > 0 || height > 0) {
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
        property var entities: []
        readonly property string componentPropKey: "component"

        onBegin: {
            theWorld.viewPortCenterWuX = 0;
            theWorld.viewPortCenterWuY = 0;
            theWorld.worldXMax = widthWu;
            theWorld.worldYMax = heightWu;
            for (let obj of entities) if(obj) obj.destroy();
            entities = [];
            theWorld.worldAboutToBeCreated();
        }

        function fetchComp(cfg) {
            let compStr = cfg[componentPropKey];
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

        function canBeHandled(objCfg) {
            return objCfg.hasOwnProperty(componentPropKey);
        }

        onPolygon: {
            let cfg = JSON.parse(description);
            if (!canBeHandled(cfg)) theWorld.polygonLoaded(points, description);

            let comp = fetchComp(cfg);
            let obj = comp.createObject(coordSys,
                                        {
                                            canvas: theWorld,
                                            world: thePhysicsWorld,
                                            vertices: points
                                        });
            customInit(obj, cfg);
            entities.push(obj);
            theWorld.objectCreated(obj);
            box2dWorkaround(obj);
        }

        onRectangle: {
            let cfg = JSON.parse(description);
            if (!canBeHandled(cfg)) theWorld.rectangleLoaded(x, y, width, height, description);

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
            entities.push(obj);
            theWorld.objectCreated(obj);
            box2dWorkaround(obj);
        }

        onPolyline: theWorld.polylineLoaded(points, description)
        onCircle: theWorld.circleLoaded(x, y, radius, description)
    }
}
