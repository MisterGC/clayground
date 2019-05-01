#include "liveloaderplugin.h"
#include <QQmlContext>

LiveLoaderPlugin::LiveLoaderPlugin(QObject *parent):
    QQmlExtensionPlugin(parent),
    observer_("")
{ }

void LiveLoaderPlugin::registerTypes(const char *uri)
{
    Q_UNUSED(uri);
    //TODO Register exposed type
    //qmlRegisterType<MyExposableType>(uri, 1, 0, "TypeNameInQml");

    // Create a corresponding qmldir with content:
    // module <ModuleName>
    // plugin <pluginlibraryname>
}


void LiveLoaderPlugin::initializeEngine(QQmlEngine *engine, const char *uri)
{
    Q_UNUSED(uri);
    wrapper_.setEngine(engine);
    engine->rootContext()->setContextProperty("QmlCache", &wrapper_);
    auto observedPath = engine->rootContext()->contextProperty("liveLoaderPath").toString();
    observer_.observePath(observedPath);
    engine->rootContext()->setContextProperty("FileObserver", &observer_);
}
