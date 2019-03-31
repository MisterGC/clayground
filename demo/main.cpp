#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFileSystemWatcher>
#include <QDir>
#include "qmlenginewrapper.h"
#include "qmlfileobserver.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

    QGuiApplication app(argc, argv);
    QmlEngineWrapper wrapper;
    QmlFileObserver watcher(QDir::currentPath() + "/qml");
    wrapper.rootContext()->setContextProperty("QmlCache", &wrapper);
    wrapper.rootContext()->setContextProperty("FileObserver", &watcher);

    wrapper.load(QUrl("qml/main.qml"));
    if (wrapper.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
