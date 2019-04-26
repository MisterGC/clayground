#ifndef populator_plugin_h
#define populator_plugin_h 
#include <QQmlExtensionPlugin>
#include <QQmlEngine>
#include "populator.h"

class PopulatorPlugin: public QQmlExtensionPlugin 
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.storytelling-turtle.PopulatorPlugin")
public:
    void registerTypes(const char* uri) override;
};
#endif

