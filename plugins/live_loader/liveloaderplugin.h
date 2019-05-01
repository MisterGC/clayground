#ifndef LIVE_LOADER_PLUGIN_H
#define LIVE_LOADER_PLUGIN_H 
#include <QQmlExtensionPlugin>
#include "qmlenginewrapper.h"
#include "qmlfileobserver.h"

class LiveLoaderPlugin: public QQmlExtensionPlugin 
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.storytelling-turtle.LiveLoaderPlugin")

public:
    LiveLoaderPlugin(QObject* parent = nullptr);
    void registerTypes(const char* uri) override;
    void initializeEngine(QQmlEngine *engine, const char *uri) override;

private:
    QmlEngineWrapper wrapper_;
    QmlFileObserver observer_;
};
#endif

