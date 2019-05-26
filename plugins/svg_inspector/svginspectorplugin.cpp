#include "svginspectorplugin.h"
#include <QDebug>

void SvgInspectorPlugin::registerTypes(const char* uri)
{
    qDebug() << "I was called";
    qmlRegisterType<SvgInspector>(uri, 1, 0, "SvgInspector");
}
