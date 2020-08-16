// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "claycanvasplugin.h"
#include <QQmlEngine>

void ClayCanvasPlugin::registerTypes(const char *uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/ClayCanvas.qml"),uri, 1,0,"ClayCanvas");
    qmlRegisterType(QUrl("qrc:/clayground/Poly.qml"),uri, 1,0,"Poly");
    qmlRegisterType(QUrl("qrc:/clayground/Rectangle.qml"),uri, 1,0,"Rectangle");
    qmlRegisterType(QUrl("qrc:/clayground/Text.qml"),uri, 1,0,"Text");
    qmlRegisterType(QUrl("qrc:/clayground/Image.qml"),uri, 1,0,"Image");
}
