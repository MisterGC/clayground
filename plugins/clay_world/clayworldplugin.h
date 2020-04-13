// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAYGROUND_WORLD_PLUGIN
#define CLAYGROUND_WORLD_PLUGIN
#include <QQmlExtensionPlugin>

class ClayWorldPlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "clayground.worldplugin")

public:
    void registerTypes(const char* uri) override;
};
#endif

