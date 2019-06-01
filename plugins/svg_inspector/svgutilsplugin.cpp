#include "svgutilsplugin.h"
#include <QDebug>

void SvgUtilsPlugin::registerTypes(const char* uri)
{
    qDebug() << "I was called";
    qmlRegisterType<SvgInspector>(uri, 1, 0, "SvgInspector");
}
