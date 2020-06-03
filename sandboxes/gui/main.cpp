// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>


int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    if (QGuiApplication::platformName() == "offscreen") {
        QObject::connect(&engine,
                         &QQmlApplicationEngine::warnings,
                         [=] (const QList<QQmlError>& warnings) {
            for (auto& w: warnings) qCritical() << w.toString();
            exit(1);
        }
        );
    }
    engine.load(QUrl("qrc:/main.qml"));
    return app.exec();
}

