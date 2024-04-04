// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QQmlEngineExtensionPlugin>
#include <QQmlEngine>

extern void qml_register_types_Clayground_Ios();
Q_GHS_KEEP_REFERENCE(qml_register_types_Clayground_Ios);

class Clayground_IosPlugin: public QQmlEngineExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)

public:
    Clayground_IosPlugin(QObject* parent = nullptr);
    void initializeEngine(QQmlEngine *engine, const char *uri) override;
};
