/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
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
