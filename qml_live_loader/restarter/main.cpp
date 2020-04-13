// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "utilityfunctions.h"
#include "clayrestarter.h"
#include <QTimer>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QDebug>
#include <QCommandLineParser>

void processCmdLineArgs(const QGuiApplication& app, ClayRestarter& restarter)
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
    QGuiApplication::setApplicationName("ClayRestarter");
    QGuiApplication::setApplicationVersion("0.1");

    QQmlApplicationEngine engine;
    engine.setOfflineStoragePath(QDir::homePath() + "/.clayground");

    ClayRestarter restarter;
    processCmdLineArgs(app, restarter);
    engine.rootContext()->setContextProperty("ClayRestarter", &restarter);
    engine.load(QUrl("qrc:/clayground/main.qml"));

    QTimer::singleShot(0, &restarter, SLOT(run()));

    return app.exec();
}
