// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "claybehaviorplugin.h"
#include <QQmlEngine>

ClayBehaviorPlugin::ClayBehaviorPlugin()
{
    Q_INIT_RESOURCE(clay_behavior);
}

void ClayBehaviorPlugin::registerTypes(const char* uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/Move.qml"),uri, 1,0,"Move");
    qmlRegisterType(QUrl("qrc:/clayground/MoveTo.qml"),uri, 1,0,"MoveTo");
    qmlRegisterType(QUrl("qrc:/clayground/FollowPath.qml"),uri, 1,0,"FollowPath");
    qmlRegisterType(QUrl("qrc:/clayground/RectTrigger.qml"),uri, 1,0,"RectTrigger");
}
