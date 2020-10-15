// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAY_CANVAS_PLUGIN_H
#define CLAY_CANVAS_PLUGIN_H
#include <QQmlExtensionPlugin>

class ClayCanvasPlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.storytelling-turtle.ClayCanvasPlugin")

public:
    ClayCanvasPlugin();
    void registerTypes(const char* uri) override;
};
#endif

