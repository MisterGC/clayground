// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.addImportPath(QCoreApplication::applicationDirPath() + "/plugins");
    engine.load(QUrl("qrc:/main.qml"));
    return app.exec();
}

