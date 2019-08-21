#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFileSystemWatcher>
#include <QDir>
#include <QCommandLineParser>
#include <QQmlApplicationEngine>
#include <QVariant>
#include <QMetaObject>
#include <QDebug>
#include "clayliveloader.h"

void processCmdLineArgs(const QGuiApplication& app, ClayLiveLoader& loader)
{
    QCommandLineParser parser;

    const QString DYN_IMPORT_DIR = "dynimportdir";

    parser.addOption({DYN_IMPORT_DIR,
                      "Adds a directory that contains parts of a QML App that ."
                      "may change while the app is running. This can be a part "
                      "with used QML files as well as a dir containing a plugin.",
                      "directory",
                      "<working directory>"});

    parser.process(app);
    if (parser.isSet(DYN_IMPORT_DIR))
    {
        for (auto& val: parser.values(DYN_IMPORT_DIR))
        {
            QDir dir(val);
            if (!dir.exists()) parser.showHelp(1);
            qDebug() << "Add import dir." << val;
            loader.addDynImportDir(val);
        }
    }
    else
    {
        // TODO Set current working directory
        // as import dir
    }
}

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName("Qml LiveLoader");
    QCoreApplication::setApplicationVersion("0.1");

    QQmlApplicationEngine engine;
    engine.addImportPath("plugins");

    ClayLiveLoader liveLoader(engine);
    processCmdLineArgs(app, liveLoader);
    engine.load(QUrl("qrc:/clayground/main.qml"));

    return app.exec();
}
