// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "claystorageplugin.h"
#include <QQmlEngine>

ClayStoragePlugin::ClayStoragePlugin()
{
    Q_INIT_RESOURCE(clay_storage);
}


void ClayStoragePlugin::registerTypes(const char* uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/KeyValueStore.qml"),
                    uri, 1,0,"KeyValueStore");
}
