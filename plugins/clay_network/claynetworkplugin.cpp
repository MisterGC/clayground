// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include <QQmlEngine>
#include "claynetworkplugin.h"
#include "claynetworknode.h"

ClayNetworkPlugin::ClayNetworkPlugin()
{
    Q_INIT_RESOURCE(clay_network);
}

void ClayNetworkPlugin::registerTypes(const char* uri)
{
    qmlRegisterType<ClayNetworkNode>(uri, 1, 0, "ClayNetworkNode");
    qmlRegisterType(QUrl("qrc:/clayground/ClayNetworkUser.qml"),uri, 1,0,"ClayNetworkUser");
}
