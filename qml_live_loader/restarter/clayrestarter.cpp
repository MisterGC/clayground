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
                const auto err = p.errorString().toStdString();
                qCritical("Couldn't run live loader: %s",
                          qUtf8Printable(p.errorString()));
                break;
            }
            nrRestarts_++;
            emit nrRestartsChanged();
            p.waitForFinished(-1);
        }
        emit finished();
    });
    t.detach();
}

int ClayRestarter::nrRestarts() const
{
    return nrRestarts_;
}
