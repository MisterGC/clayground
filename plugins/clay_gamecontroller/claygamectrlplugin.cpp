// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "claygamectrlplugin.h"
#include <QQmlEngine>

ClayGameCtrlPlugin::ClayGameCtrlPlugin()
{
    Q_INIT_RESOURCE(clay_controller);
}

void ClayGameCtrlPlugin::registerTypes(const char* uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/GameController.qml"),uri, 1,0,"GameController");
}
