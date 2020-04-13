// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "myplugin.h"
#include "mycomponent.h"
#include <QDebug>

void MyPlugin::registerTypes(const char* uri)
{
    qmlRegisterType<MyComponent>(uri, 1, 0, "MyComponent");
}
