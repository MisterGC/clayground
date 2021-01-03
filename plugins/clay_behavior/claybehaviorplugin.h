// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAYGROUND_BEHAVIOR_PLUGIN
#define CLAYGROUND_BEHAVIOR_PLUGIN
#include <QQmlExtensionPlugin>

class ClayBehaviorPlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "clayground.behaviorplugin")

public:
    ClayBehaviorPlugin();

    void registerTypes(const char* uri) override;
};
#endif

