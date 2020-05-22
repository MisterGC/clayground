// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "svgplugin.h"
#include "svgreader.h"
#include "svgwriter.h"
#include <QDebug>

void SvgPlugin::registerTypes(const char* uri)
{
    qmlRegisterType<SvgReader>(uri, 1, 0, "SvgReader");
    qmlRegisterType<SvgWriter>(uri, 1, 0, "SvgWriter");
}
