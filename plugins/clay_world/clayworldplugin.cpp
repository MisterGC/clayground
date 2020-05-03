// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "clayworldplugin.h"
#include <QQmlEngine>

void ClayWorldPlugin::registerTypes(const char* uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/ClayWorld.qml"),
                    uri, 1,0,"ClayWorld");
    qmlRegisterType(QUrl("qrc:/clayground/Minimap.qml"),
                    uri, 1,0,"Minimap");
}
