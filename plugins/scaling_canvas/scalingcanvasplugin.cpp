// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "scalingcanvasplugin.h"
#include <QQmlEngine>

void ScalingCanvasPlugin::registerTypes(const char *uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/CoordCanvas.qml"),uri, 1,0,"CoordCanvas");
    qmlRegisterType(QUrl("qrc:/clayground/ScalingPoly.qml"),uri, 1,0,"ScalingPoly");
    qmlRegisterType(QUrl("qrc:/clayground/ScalingRectangle.qml"),uri, 1,0,"ScalingRectangle");
    qmlRegisterType(QUrl("qrc:/clayground/ScalingText.qml"),uri, 1,0,"ScalingText");
}
