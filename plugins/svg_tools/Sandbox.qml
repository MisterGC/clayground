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
import Clayground.ScalingCanvas 1.0
import Clayground.SvgUtils 1.0

CoordCanvas
{
    id: theCanvas
    anchors.fill: parent
    pixelPerUnit: 50
    keyBoardNavigationEnabled: true

    worldXMin: 0
    worldXMax:  10
    worldYMin: 0
    worldYMax: 10

    SvgWriter {
        id: theWriter
        path: ClayLiveLoader.sandboxDir + "/../test.svg"
        Component.onCompleted: {
            begin(theCanvas.worldXMax - theCanvas.worldXMin,
                  theCanvas.worldYMax - theCanvas.worldYMin);
            rectangle("test", "{\"component\":\"Test.qml\"}", 5, 5, 2.5, 2.5);
            rectangle("test", "{\"component\":\"Test.qml\"}", 5, 5, 2.5, 2.5);
            end();
        }

    }

    SvgInspector
    {
        id: theSvgInspector
        property var objs: []

        Component.onCompleted: setSource(theWriter.path)
        onBegin: { console.log("Begin") }
        onRectangle: { console.log("Rectangle") }
    }
}
