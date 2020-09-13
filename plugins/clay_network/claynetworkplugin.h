// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAYGROUND_NETWORK_PLUGIN
#define CLAYGROUND_NETWORK_PLUGIN
#include <QQmlExtensionPlugin>

class ClayNetworkPlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "clayground.networkplugin")

public:
    void registerTypes(const char* uri) override;
};
#endif

