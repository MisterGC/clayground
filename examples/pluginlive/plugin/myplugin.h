// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef populator_plugin_h
#define populator_plugin_h 
#include <QQmlExtensionPlugin>
#include <QQmlEngine>

class MyPlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.mycomp.myplugin")
public:
    void registerTypes(const char* uri) override;
};
#endif

