// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "svgutilsplugin.h"
#include "svginspector.h"
#include "svgwriter.h"
#include <QDebug>

void SvgUtilsPlugin::registerTypes(const char* uri)
{
    qmlRegisterType<SvgInspector>(uri, 1, 0, "SvgInspector");
    qmlRegisterType<SvgWriter>(uri, 1, 0, "SvgWriter");
}
