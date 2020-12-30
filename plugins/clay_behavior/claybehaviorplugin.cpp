// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "claycommonplugin.h"
#include <QQmlEngine>

ClayCommonPlugin::ClayCommonPlugin()
{
    Q_INIT_RESOURCE(clay_common);
}

void ClayCommonPlugin::registerTypes(const char* uri)
{
    qmlRegisterSingletonType(QUrl("qrc:/clayground/Clayground.qml"),
                    uri, 1,0,"Clayground");
}
