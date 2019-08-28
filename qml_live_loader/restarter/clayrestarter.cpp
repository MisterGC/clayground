#include "clayrestarter.h"
#include <QProcess>
#include <QCoreApplication>
#include <QDebug>
#include <thread>

ClayRestarter::ClayRestarter(QObject *parent): QObject(parent)
{}

ClayRestarter::~ClayRestarter()
{
   shallStop_ = true;
   std::unique_lock<std::mutex> ul(mutex_);
   restarterStopped_.wait(ul);
}

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
            emit restarted();
            bool ps = false;
            while (!ps) {
                ps = p.waitForFinished(500);
                if (shallStop_) {
                    std::lock_guard<std::mutex> l(mutex_);
                    p.kill();
                    p.waitForFinished();
                    restarterStopped_.notify_one();
                    return;
                }
            }
        }
    });
    t.detach();
}
