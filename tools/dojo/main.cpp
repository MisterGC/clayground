// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "utilityfunctions.h"
#include "claydojo.h"
#include <QTimer>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QDebug>
#include <QCommandLineParser>

void processCmdLineArgs(const QGuiApplication& app, ClayDojo& restarter)
{
    QCommandLineParser parser;
    addCommonArgs(parser);
    parser.process(app);
    if (parser.isSet(DYN_PLUGIN_ARG)) {
        for (auto& val: parser.values(DYN_PLUGIN_ARG))
        {
            qDebug() << "Found dynplugin" << val;
            auto dynPlugDirs = val.split(",");
            if (dynPlugDirs.length() != 2) parser.showHelp();
            restarter.addDynPluginDepedency(dynPlugDirs[0], dynPlugDirs[1]);
        }
    }
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("ClayDojo");
    QGuiApplication::setApplicationVersion("0.2");

    QQmlApplicationEngine engine;
    engine.addImportPath("qml");
    engine.setOfflineStoragePath(QDir::homePath() + "/.clayground");

    ClayDojo dojo;
    processCmdLineArgs(app, dojo);
    engine.rootContext()->setContextProperty("ClayDojo", &dojo);
    engine.load(QUrl("qrc:/clayground/main.qml"));

    QTimer::singleShot(0, &dojo, SLOT(run()));

    return app.exec();
}
