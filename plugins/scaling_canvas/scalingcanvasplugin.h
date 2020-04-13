// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef SCALING_CANVAS_PLUGIN_H
#define SCALING_CANVAS_PLUGIN_H 
#include <QQmlExtensionPlugin>

class ScalingCanvasPlugin: public QQmlExtensionPlugin 
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.storytelling-turtle.ScalingCanvasPlugin")

public:
    void registerTypes(const char* uri) override;
};
#endif

