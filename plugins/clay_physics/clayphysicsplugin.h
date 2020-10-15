// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAYGROUND_PHYSICS_PLUGIN
#define CLAYGROUND_PHYSICS_PLUGIN 
#include <QQmlExtensionPlugin>

class ClayPhysicsPlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "clayground.physicsplugin")

public:
    ClayPhysicsPlugin();
    void registerTypes(const char* uri) override;
};
#endif

