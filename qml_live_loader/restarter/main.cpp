#include "clayrestarter.h"
#include <QTimer>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("ClayRestarter");
    QGuiApplication::setApplicationVersion("0.1");

    QQmlApplicationEngine engine;
    engine.setOfflineStoragePath(QDir::homePath() + "/.clayground");

    ClayRestarter restarter;
    engine.rootContext()->setContextProperty("ClayRestarter", &restarter);
    engine.load(QUrl("qrc:/clayground/main.qml"));

    QTimer::singleShot(0, &restarter, SLOT(run()));

    return app.exec();
}
