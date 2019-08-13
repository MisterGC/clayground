#ifndef CLAYGROUND_PHYSICS_PLUGIN
#define CLAYGROUND_PHYSICS_PLUGIN 
#include <QQmlExtensionPlugin>

class PhysicsPlugin: public QQmlExtensionPlugin 
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "clayground.physicsplugin")

public:
    void registerTypes(const char* uri) override;
};
#endif

