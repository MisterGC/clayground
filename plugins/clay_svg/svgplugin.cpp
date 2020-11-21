// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "svgplugin.h"
#include "svgreader.h"
#include "svgwriter.h"
#include "imageprovider.h"
#include <QDebug>

SvgPlugin::SvgPlugin()
{
    Q_INIT_RESOURCE(svg);
}

void SvgPlugin::registerTypes(const char* uri)
{
    qmlRegisterType<SvgReader>(uri, 1, 0, "SvgReader");
    qmlRegisterType<SvgWriter>(uri, 1, 0, "SvgWriter");
    qmlRegisterType(QUrl("qrc:/clayground/SvgImageSource.qml"),
                    uri, 1,0,"SvgImageSource");
}

void SvgPlugin::initializeEngine(QQmlEngine *engine, const char */*uri*/)
{
    engine->addImageProvider(QLatin1String("claysvg"), new ImageProvider());
}
