// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "svgplugin.h"
#include "svgreader.h"
#include "svgwriter.h"
#include "imageprovider.h"
#include <QDebug>
#include <QQmlContext>

void SvgPlugin::registerTypes(const char* uri)
{ }

void SvgPlugin::initializeEngine(QQmlEngine *engine, const char */*uri*/)
{
    auto provider = new ImageProvider();
    engine->addImageProvider(QLatin1String("claysvg"), provider);
    engine->rootContext()->setContextProperty("ClaySvgImageProvider", provider);
}

