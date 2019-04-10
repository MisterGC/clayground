#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFileSystemWatcher>
#include <QDir>
#include <QCommandLineParser>
#include "qmlenginewrapper.h"
#include "qmlfileobserver.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

    QGuiApplication app(argc, argv);

    QmlEngineWrapper engine;
    QmlFileObserver watcher(QDir::currentPath() + "/qml");
    engine.rootContext()->setContextProperty("FileObserver", &watcher);
    engine.rootContext()->setContextProperty("QmlCache", &engine);
    engine.addImportPath(QDir::currentPath() + "/qml");

    engine.load(QUrl("qrc:/main.qml"));
    if (engine.rootObjects().isEmpty()) return -1;

    return app.exec();
}
