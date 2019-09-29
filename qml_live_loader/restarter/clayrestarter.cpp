#include "clayrestarter.h"
#include <utilityfunctions.h>

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QProcess>
#include <iostream>
#include <thread>

ClayRestarter::ClayRestarter(QObject *parent):
    QObject(parent),
    shallStop_(false),
    shallRestart_(false),
    sbx_(nullptr),
    logCat_(LIVE_LOADER_CAT)
{
    connect(&fileObserver_, &ClayFileSysObserver::fileChanged, this, &ClayRestarter::onFileSysChange);
    connect(&fileObserver_, &ClayFileSysObserver::fileAdded, this, &ClayRestarter::onFileSysChange);
    connect(&fileObserver_, &ClayFileSysObserver::fileRemoved, this, &ClayRestarter::onFileSysChange);

    restart_.setSingleShot(true);
    connect(&restart_, &QTimer::timeout, this, &ClayRestarter::onTimeToRestart);
}

ClayRestarter::~ClayRestarter()
{
   shallStop_ = true;
   std::unique_lock<std::mutex> ul(mutex_);
   restarterStopped_.wait(ul);
}

void ClayRestarter::addDynPluginDepedency(const QString& srcPath,
                                     const QString& binPath)
{
    qCDebug(logCat_) << "New dyn plugin dir: " << srcPath << " " << binPath;
    if (!QDir(srcPath).exists() || !QDir(binPath).exists()){
        qCritical("Both source and bin path of plugin must exist (%s, %s)",
                  qUtf8Printable(srcPath), qUtf8Printable(binPath));
        return;
    }
    fileObserver_.observeDir(srcPath);
    fileObserver_.observeDir(binPath);
    sourceToBuildDir_[srcPath]=binPath;
    qCDebug(logCat_) << "Added plugin dependency " << srcPath << " , " << binPath;
}

void ClayRestarter::run()
{
    std::thread t([this] {
        const auto loaderCmd = QString("%1/clayliveloader").arg(QCoreApplication::applicationDirPath());
        while(true) {
            sbx_.reset(new QProcess());
            auto& p = *sbx_.get();
            connect(&p, &QProcess::readyReadStandardError, this, &ClayRestarter::onSbxOutput);
            if (buildWaitList_.empty())
                p.start(loaderCmd, QCoreApplication::arguments());
            else {
                auto msg = buildWaitList_.join(";");
                p.start(loaderCmd,
                        {QString("--%1").arg(MESSAGE_ARG),
                         QString("\"Waiting for plugin dirs %2 to be updated.\"")
                         .arg(msg)});
            }
            if (!p.waitForStarted(5000)) {
                const auto err = p.errorString().toStdString();
                qCritical("Couldn't run live loader: %s",
                          qUtf8Printable(p.errorString()));
                break;
            }
            emit restarted();
            auto ps = false;
            while (!ps) {
                ps = p.waitForFinished(500);
                if (shallStop_) {
                    std::lock_guard<std::mutex> l(mutex_);
                    p.kill();
                    p.waitForFinished();
                    restarterStopped_.notify_one();
                    return;
                }
                if (shallRestart_) {
                    p.kill();
                    shallRestart_ = false;
                    break;
                }
            }
        }
    });
    t.detach();
}

void ClayRestarter::onSbxOutput()
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

void ClayRestarter::onFileSysChange(const QString &path)
{
   auto dir = QFileInfo(path).absoluteDir();
   if (!dir.exists()) {
       qCritical("Cannot process dir that doesn't exist: %s",
                 qUtf8Printable(dir.path()));
   }
   auto p = dir.path();
   qCDebug(logCat_) << "FileSys changed " << p;
   auto sourceDir = QString();
   for (auto& s: sourceToBuildDir_)
       if (p.startsWith(s.first)) {
          sourceDir = s.first;
          break;
       }
   if (!sourceDir.isEmpty()) {
       auto b = sourceToBuildDir_[sourceDir];
       if (!buildWaitList_.contains(b)) {
           buildWaitList_.append(b);
           restart_.start(RAPID_CHANGE_CATCHTIME);
       }
       qCDebug(logCat_) << "Source dir changed -> wait for build " << p;
   }
   else
   {
       auto binDir = QString();
       for (auto& b: sourceToBuildDir_)
           if (p.startsWith(b.second)){
               binDir = b.second;
               break;
           }
       if (buildWaitList_.contains(binDir)) {
           qCDebug(logCat_) << "Build dir updated " << p;
           buildWaitList_.removeAll(binDir);
           if (buildWaitList_.empty()) restart_.start(RAPID_CHANGE_CATCHTIME);
       }
   }
}

void ClayRestarter::onTimeToRestart()
{
    shallRestart_ = true;
}
