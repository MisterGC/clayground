// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include <QDebug>
#include <QQmlContext>
#include "iosplugin.h"

Clayground_IosPlugin::Clayground_IosPlugin(QObject *parent):
    QQmlEngineExtensionPlugin(parent)
{
    volatile auto registration = &qml_register_types_Clayground_Ios;
    Q_UNUSED(registration);
}

void Clayground_IosPlugin::initializeEngine(QQmlEngine *engine, const char */*uri*/)
{
    // TODO: Integrate mirror/accessor class here
    //engine->rootContext()->setContextProperty("ClaySvgImageProvider", provider);
}
