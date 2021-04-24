// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "clayphysicsplugin.h"
#include <QQmlEngine>

ClayPhysicsPlugin::ClayPhysicsPlugin()
{
    Q_INIT_RESOURCE(clay_physics);
}

void ClayPhysicsPlugin::registerTypes(const char* uri)
{
    qmlRegisterType(QUrl("qrc:/clayground/PhysicsItem.qml"),uri, 1,0,"PhysicsItem");
    qmlRegisterType(QUrl("qrc:/clayground/ImageBoxBody.qml"),uri, 1,0,"ImageBoxBody");
    qmlRegisterType(QUrl("qrc:/clayground/RectBoxBody.qml"),uri, 1,0,"RectBoxBody");
    qmlRegisterType(QUrl("qrc:/clayground/VisualizedPolyBody.qml"),uri, 1,0,"VisualizedPolyBody");
    qmlRegisterType(QUrl("qrc:/clayground/CollisionTracker.qml"),uri, 1,0,"CollisionTracker");
    qmlRegisterSingletonType(QUrl("qrc:/clayground/PhysicsUtils.qml"),
                    uri, 1,0,"ClayPhysics");
}
