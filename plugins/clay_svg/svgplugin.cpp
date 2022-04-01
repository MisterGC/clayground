// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "svgplugin.h"
#include "svgreader.h"
#include "svgwriter.h"
#include "imageprovider.h"
#include <QDebug>
#include <QQmlContext>

Clayground_SvgPlugin::Clayground_SvgPlugin(QObject *parent):
    QQmlEngineExtensionPlugin(parent)
{
    volatile auto registration = &qml_register_types_Clayground_Svg;
    Q_UNUSED(registration);
}

void Clayground_SvgPlugin::initializeEngine(QQmlEngine *engine, const char */*uri*/)
{
    auto provider = new ImageProvider();
    engine->addImageProvider(QLatin1String("claysvg"), provider);
    engine->rootContext()->setContextProperty("ClaySvgImageProvider", provider);
}
