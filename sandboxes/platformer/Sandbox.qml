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
import Clayground.GameController 1.0
import Clayground.Physics 1.0

CoordCanvas
{
    id: theWorld
    anchors.fill: parent
    worldXMax: 10
    worldYMax: 10
    pixelPerUnit: width / theWorld.worldXMax

    property bool standaloneApp: false
    readonly property string map: (standaloneApp ? ":/" : ClayLiveLoader.sandboxDir)
                         + "/map.svg"
    readonly property string resPrefix: theWorld.standaloneApp ? "qrc:/" : ""
    property var player: null

    onWidthChanged: {
        if (width > 0) {
            theSvgInspector.setSource(theWorld.map)
            theGameCtrl.selectKeyboard(Qt.Key_Up,
                                       Qt.Key_Down,
                                       Qt.Key_Left,
                                       Qt.Key_Right,
                                       Qt.Key_A,
                                       Qt.Key_S);
            player.desireX = Qt.binding(function() {return theGameCtrl.axisX;});
        }
    }

    World {
        id: physicsWorld
        gravity: Qt.point(0,15*9.81)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
    }

    //Reactivate on demand
    //DebugDraw {parent: coordSys; world: physicsWorld }

    Keys.forwardTo: theGameCtrl
    GameController {
        id: theGameCtrl
        anchors.fill: parent
        onButtonBPressedChanged:  if (buttonBPressed) player.jump();
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
            player = null;
            for (let obj of objs) obj.destroy();
            objs = [];
        }

        function fetchComp(cfg) {
            let compStr = cfg["component"];
            if (!compStr.startsWith("qrc:"))
                compStr = theWorld.resPrefix + compStr;
            let comp = Qt.createComponent(compStr);
            return comp;
        }

        function customInit(obj, cfg) {
            let initVals = cfg["initVals"];
            if (initVals){
                for (let p in initVals)
                    obj[p] = initVals[p];
            }
        }

        onPolygon: {
            let cfg = JSON.parse(description);
            let comp = fetchComp(cfg);
            let obj = comp.createObject(coordSys,
                                        {
                                            canvas: theWorld,
                                            world: physicsWorld,
                                            vertices: points,
                                            bodyType: Body.Dynamic,
                                            categories: Box.Category3,
                                            collidesWith: Box.Category1 | Box.Category2 | Box.Category3,
                                            fixedRotation: false,
                                            friction: 10,
                                            density: 100,
                                            resitution: 0,
                                            bullet: true
                                        });
            customInit(obj, cfg);
            objs.push(obj);
        }

        onRectangle: {
            let cfg = JSON.parse(description);
            let compStr = theWorld.resPrefix + cfg["component"];
            let comp = Qt.createComponent(compStr);
            let obj = comp.createObject(coordSys,
                                        {
                                            world: physicsWorld,
                                            xWu: x,
                                            yWu: y,
                                            widthWu: width,
                                            heightWu: height,
                                            color: "black"
                                        });
            obj.pixelPerUnit = Qt.binding( _ => {return theWorld.pixelPerUnit;} );
            objs.push(obj);
            if (compStr === (theWorld.resPrefix + "Player.qml")) {
                player = obj;
                theWorld.observedItem = player;
                player.spriteSource = theWorld.resPrefix + "player_animated.png"
            }
        }
    }
}
