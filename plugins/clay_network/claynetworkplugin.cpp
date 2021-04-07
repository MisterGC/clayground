// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include <QQmlEngine>
#include "claynetworkplugin.h"
#include "claynetworkuser.h"

void ClayNetworkPlugin::registerTypes(const char* uri)
{
    qmlRegisterType<ClayNetworkUser>(uri, 1, 0, "ClayNetworkUser");
}
