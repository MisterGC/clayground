// (c) Clayground Contributors - zlib license, see "LICENSE" file

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

