#include "populatorplugin.h"
#include <QDebug>

void PopulatorPlugin::registerTypes(const char* uri)
{
    qDebug() << "I was called";
    qmlRegisterType<Populator>(uri, 1, 0, "Populator");
}
