// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAYGROUND_COMMON_PLUGIN
#define CLAYGROUND_COMMON_PLUGIN
#include <QQmlExtensionPlugin>

class ClayCommonPlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "clayground.commonplugin")

public:
    ClayCommonPlugin();

    void registerTypes(const char* uri) override;
};
#endif

