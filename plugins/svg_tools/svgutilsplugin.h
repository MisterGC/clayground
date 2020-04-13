// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef populator_plugin_h
#define populator_plugin_h 
#include <QQmlExtensionPlugin>
#include <QQmlEngine>

class SvgUtilsPlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.storytelling-turtle.SvgTraversalPlugin")
public:
    void registerTypes(const char* uri) override;
};
#endif

