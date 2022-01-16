// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

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
