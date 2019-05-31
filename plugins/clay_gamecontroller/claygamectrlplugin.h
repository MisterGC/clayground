#ifndef CLAY_GAMECONTROLLER
#define CLAY_GAMECONTROLLER 
#include <QQmlExtensionPlugin>

class ClayGameCtrlPlugin: public QQmlExtensionPlugin 
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.storytelling-turtle.ClayGameCtrlPlugin")

public:
    void registerTypes(const char* uri) override;
};
#endif

