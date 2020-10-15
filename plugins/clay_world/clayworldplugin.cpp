// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "clayworldplugin.h"
#include <QQmlEngine>

ClayWorldPlugin::ClayWorldPlugin()
{
    Q_INIT_RESOURCE(clay_world);
}

void ClayWorldPlugin::registerTypes(const char* uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/ClayWorld.qml"),
                    uri, 1,0,"ClayWorld");
    qmlRegisterType(QUrl("qrc:/clayground/Minimap.qml"),
                    uri, 1,0,"Minimap");
}
