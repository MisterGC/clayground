#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFileSystemWatcher>
#include <QDir>
#include <QCommandLineParser>
#include <QQmlApplicationEngine>
#include <QVariant>
#include <QMetaObject>
#include <QDebug>
#include "qmlfileobserver.h"
#include "qmlenginewrapper.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName("Qml LiveLoader");
    QCoreApplication::setApplicationVersion("0.1");
    QCommandLineParser parser;
    QCommandLineOption opt("dynqmldir",
                           "Sets the directory that contains dynamic qml.",
                           "directory",
                           "<working directory>");
    parser.addOption(opt);
    parser.process(app);
    auto dynQmlDir = QDir::currentPath();
    if (parser.isSet("dynqmldir"))
        dynQmlDir = parser.value("dynqmldir");
    QQmlApplicationEngine engine;
    engine.addImportPath("plugins");
    engine.addImportPath(dynQmlDir);
    QmlFileObserver watcher(dynQmlDir);
    QmlEngineWrapper wrapper;
    wrapper.setEngine(&engine);
    engine.rootContext()->setContextProperty("FileObserver", &watcher);
    engine.rootContext()->setContextProperty("QmlCache", &wrapper);
    engine.load(QUrl("qrc:/main.qml"));
    if (engine.rootObjects().isEmpty()) return -1;

    return app.exec();
}
