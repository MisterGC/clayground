#include "clayrestarter.h"
#include <QProcess>
#include <QCoreApplication>
#include <QDebug>
#include <thread>
#include <iostream>

ClayRestarter::ClayRestarter(QObject *parent):
    QObject(parent),
    sbx_(nullptr)
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
            sbx_.reset(new QProcess());
            auto& p = *sbx_.get();
            connect(&p, &QProcess::readyReadStandardError, this, &ClayRestarter::onSbxOut);
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

void ClayRestarter::onSbxOut()
{
  sbx_->setReadChannel(QProcess::StandardError);
  auto msgs = sbx_->readAllStandardError();
  if (!msgs.isEmpty()) {
      auto isErr = (msgs.startsWith("ERROR") ||
          msgs.startsWith("WARN") ||
          msgs.startsWith("FATAL"));
      if (isErr) qWarning("%s", qUtf8Printable(msgs));
      else std::cout << msgs.toStdString() << std::endl;
  }
}
