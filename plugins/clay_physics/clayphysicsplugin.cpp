// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "clayphysicsplugin.h"
#include <QQmlEngine>

void ClayPhysicsPlugin::registerTypes(const char* uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/PhysicsItem.qml"),uri, 1,0,"PhysicsItem");
    qmlRegisterType(QUrl("qrc:/clayground/VisualizedBoxBody.qml"),uri, 1,0,"VisualizedBoxBody");
    qmlRegisterType(QUrl("qrc:/clayground/VisualizedPolyBody.qml"),uri, 1,0,"VisualizedPolyBody");
}
