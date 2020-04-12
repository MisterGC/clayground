/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
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
            for (let obj of objs) obj.destroy();
            objs = [];
        }

        function fetchComp(cfg) {
            let compStr = cfg["component"];
            if (!compStr.startsWith("qrc:"))
                compStr = theWorld._resPrefix + compStr;
            let comp = Qt.createComponent(compStr);
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
            let compStr = theWorld._resPrefix + cfg["component"];
            let comp = Qt.createComponent(compStr);
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
