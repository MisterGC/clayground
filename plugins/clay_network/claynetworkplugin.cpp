// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "claynetworkplugin.h"
#include <QQmlEngine>

void ClayNetworkPlugin::registerTypes(const char* uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/NetworkDummy.qml"),
                    uri, 1,0,"NetworkDummy");
}
