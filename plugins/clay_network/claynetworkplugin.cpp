// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include <QQmlEngine>
#include "claynetworkplugin.h"
#include "lobby.h"

void ClayNetworkPlugin::registerTypes(const char* uri)
{
    qmlRegisterType<Lobby>(uri, 1, 0, "Lobby");
}
