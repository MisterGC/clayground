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
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QCommandLineParser>
#include <QDebug>

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);

    QCommandLineParser parser;
    const auto IMPORT_DIR_ARG = QString("importdir");
    parser.addOption({IMPORT_DIR_ARG,
                      "<bin/plugins> directory created by the build of the actual plugin.",
                      "<dir/to/bin/plugins>"});
    parser.process(app);
    auto importDir = parser.value(IMPORT_DIR_ARG);
    if (importDir.isEmpty()) parser.showHelp(1);

    QQmlApplicationEngine engine;
    engine.addImportPath(importDir);
    engine.load(QUrl("qrc:/main.qml"));
    return app.exec();
}

