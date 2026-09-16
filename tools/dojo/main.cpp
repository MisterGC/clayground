// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "utilityfunctions.h"
#include "claydojo.h"
#include "claystorage.h"
#include <QTimer>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QCoreApplication>
#include <QDebug>
#include <QCommandLineParser>
#include <iostream>

// Returns false when the command line is unusable. The dojo forwards its own
// arguments verbatim to clayliveloader, so anything it accepts here but does
// not understand fails in the child instead - which used to mean a child that
// printed usage to stdout, exited 0, and got respawned with backoff forever
// while the HUD reported all systems up (issue #166). Fail at the front door.
bool processCmdLineArgs(const QGuiApplication& app, ClayDojo& restarter)
{
    QCommandLineParser parser;
    addCommonArgs(parser);
    parser.process(app);

    auto const stray = parser.positionalArguments();
    if (!stray.isEmpty()) {
        std::cerr << "ClayDojo: unexpected argument '"
                  << stray.first().toStdString() << "'." << std::endl;
        if (stray.first().endsWith(".qml", Qt::CaseInsensitive))
            std::cerr << "ClayDojo: a sandbox is registered with --"
                      << SBX_ARG << " " << stray.first().toStdString()
                      << std::endl;
        std::cerr << parser.helpText().toStdString();
        return false;
    }

    if (parser.isSet(DYN_PLUGIN_ARG)) {
        for (auto const& val: parser.values(DYN_PLUGIN_ARG))
        {
            qDebug() << "Found dynplugin" << val;
            auto const dynPlugDirs = val.split(",");
            if (dynPlugDirs.length() != 2) parser.showHelp();
            restarter.addDynPluginDepedency(dynPlugDirs[0], dynPlugDirs[1]);
        }
    }
    if (parser.isSet(SBX_ARG)) {
        for (auto const& sbx: parser.values(SBX_ARG)) {
            // A sandbox that isn't there registers no directory, so the dojo
            // would supervise nothing and write no dojo.json - invisible from
            // the outside. Say it here instead.
            if (!restarter.addSandboxDir(sbx)) {
                std::cerr << "ClayDojo: sandbox file not found: "
                          << sbx.toStdString() << std::endl;
                return false;
            }
        }
    }
    return true;
}

int main(int argc, char *argv[])
{
    // Fallback path for GPU timestamp collection; inherited by the spawned
    // clayliveloader child so QQuick3DRenderStats can report GPU times.
    qputenv("QSG_RHI_PROFILE", "1");

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("ClayDojo");
    QGuiApplication::setApplicationVersion(CLAY_DOJO_VERSION);

    QQmlApplicationEngine engine;
    // Absolute, off the binary rather than off the working directory. The
    // relative form below only resolves when the dojo is launched from
    // build/bin, so every documented invocation - all of which run it from
    // the repo root - found no Clayground modules at all and loaded a blank
    // white sandbox. clayrender always did it this way; these did not.
    engine.addImportPath(QCoreApplication::applicationDirPath() + "/qml");
    engine.addImportPath("qml");
    ClayScene::applyStorageDir(&engine);

    ClayDojo dojo;
    if (!processCmdLineArgs(app, dojo))
        return 1;
    engine.rootContext()->setContextProperty("ClayDojo", &dojo);
    engine.load(QUrl("qrc:/clayground/main.qml"));

    QTimer::singleShot(0, &dojo, SLOT(run()));

    return app.exec();
}
