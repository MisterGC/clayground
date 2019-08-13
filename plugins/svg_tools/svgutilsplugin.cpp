#include "svgutilsplugin.h"
#include <QDebug>

void SvgUtilsPlugin::registerTypes(const char* uri)
{
    qmlRegisterType<SvgInspector>(uri, 1, 0, "SvgInspector");
}
