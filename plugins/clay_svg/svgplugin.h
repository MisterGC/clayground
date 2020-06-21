// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAY_SVG_PLUGIN_H
#define CLAY_SVG_PLUGIN_H
#include <QQmlExtensionPlugin>
#include <QQmlEngine>

class SvgPlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.storytelling-turtle.SvgPlugin")

public:
    void registerTypes(const char* uri) override;
    void initializeEngine(QQmlEngine *engine, const char *uri) override;
};
#endif

