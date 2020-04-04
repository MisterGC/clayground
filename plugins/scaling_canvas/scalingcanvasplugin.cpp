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
#include "scalingcanvasplugin.h"
#include <QQmlEngine>

void ScalingCanvasPlugin::registerTypes(const char *uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/CoordCanvas.qml"),uri, 1,0,"CoordCanvas");
    qmlRegisterType(QUrl("qrc:/clayground/ScalingPoly.qml"),uri, 1,0,"ScalingPoly");
    qmlRegisterType(QUrl("qrc:/clayground/ScalingRectangle.qml"),uri, 1,0,"ScalingRectangle");
    qmlRegisterType(QUrl("qrc:/clayground/ScalingText.qml"),uri, 1,0,"ScalingText");
}
