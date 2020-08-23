// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "claynetworkplugin.h"
#include <QQmlEngine>
#include "lobby.h"

void ClayNetworkPlugin::registerTypes(const char* uri)
{
    qmlRegisterType<Lobby>(uri, 1, 0, "Lobby");
}
