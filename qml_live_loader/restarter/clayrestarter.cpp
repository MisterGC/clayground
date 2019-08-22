#include "clayrestarter.h"
#include <QProcess>
#include <QCoreApplication>
#include <QDebug>
#include <thread>

ClayRestarter::ClayRestarter(QObject *parent): QObject(parent)
{}

void ClayRestarter::run()
{
    std::thread t([this] {
        const auto loaderCmd = QString("%1/clayliveloader").arg(QCoreApplication::applicationDirPath());
        while(true) {
            QProcess p;
            p.start(loaderCmd, QCoreApplication::arguments());
            if (!p.waitForStarted(5000)) {
                qCritical(p.errorString().toUtf8());
                break;
            }
            p.waitForFinished(-1);
        }
        emit finished();
    });
    t.detach();
}
