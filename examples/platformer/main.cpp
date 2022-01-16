// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    auto runAsAutoTest = QGuiApplication::platformName() == "minimal";
    if (runAsAutoTest) {
        QObject::connect(&engine,
                         &QQmlApplicationEngine::warnings,
                         [=] (const QList<QQmlError>& warnings) {
            for (auto& w: warnings) qCritical() << w.toString();
            exit(1);
        }
        );
    }

    engine.addImportPath(QCoreApplication::applicationDirPath() + "/qml");
    engine.load(QUrl("qrc:/main.qml"));
    return app.exec();
}

