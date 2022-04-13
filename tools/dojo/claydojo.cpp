// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claydojo.h"
#include <utilityfunctions.h>

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QProcess>
#include <iostream>
#include <thread>
#include <chrono>

ClayDojo::ClayDojo(QObject *parent):
    QObject(parent),
    shallStop_(false),
    shallRestart_(false),
    sbxIdx_(USE_FIRST_SBX_IDX),
    sbx_(nullptr),
    logCat_(LIVE_LOADER_CAT)
{
    using Cdo = ClayDojo;
    using Cfo = ClayFileSysObserver;

    connect(&fileObserver_, &Cfo::fileChanged, this, &Cdo::onFileSysChange);
    connect(&fileObserver_, &Cfo::fileAdded,   this, &Cdo::onFileSysChange);
    connect(&fileObserver_, &Cfo::fileRemoved, this, &Cdo::onFileSysChange);

    restart_.setSingleShot(true);
    connect(&restart_, &QTimer::timeout, this, &Cdo::onTimeToRestart);
}

ClayDojo::~ClayDojo()
{
   std::unique_lock<std::timed_mutex> ul(mutex_);
   shallStop_ = true;
   restarterStopped_.wait(ul);
}

void ClayDojo::addDynPluginDepedency(const QString& srcPath,
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

void ClayDojo::run()
{
    std::thread t([this] {
        const auto loaderCmd = QString("%1/clayliveloader").arg(QCoreApplication::applicationDirPath());
        while(true) {
            {
                std::lock_guard<std::timed_mutex> l(mutex_);
                // Ensure that delete gets called after pending signal processing
                if (sbx_.get()) {
                    auto& p = *sbx_.release();
                    disconnect(&p, &QProcess::readyReadStandardError, this, &ClayDojo::onSbxOutput);
                    p.deleteLater();
                }
            }
            sbx_.reset(new QProcess());
            auto& p = *sbx_.get();
            connect(&p, &QProcess::readyReadStandardError, this, &ClayDojo::onSbxOutput);
            if (buildWaitList_.empty()){
                auto args = QCoreApplication::arguments();
                args << QString("--%1").arg(SBX_INDEX_ARG) << QString::number(sbxIdx_);
                p.start(loaderCmd, args);
            }
            else {
                auto const msg = buildWaitList_.join(";");
                p.start(loaderCmd,
                        {QString("--%1").arg(MESSAGE_ARG),
                         QString("\"Waiting for plugin dirs %2 to be updated.\"")
                         .arg(msg)});
            }
            auto constexpr MAX_START_WAIT_TIME = 5000;
            if (!p.waitForStarted(MAX_START_WAIT_TIME)) {
                auto const err = p.errorString().toStdString();
                qCritical("Couldn't run live loader: %s",
                          qUtf8Printable(p.errorString()));
                break;
            }
            emit restarted();
            auto ps = false;
            while (!ps)
            {
                auto constexpr TIME_FOR_ACTION_IN_OTHER_THREAD = 50;
                std::this_thread::sleep_for(std::chrono::milliseconds(TIME_FOR_ACTION_IN_OTHER_THREAD));
                std::lock_guard<std::timed_mutex> l(mutex_);
                auto constexpr MAX_TIME_PER_TRY = 100;
                ps = p.waitForFinished(MAX_TIME_PER_TRY);
                auto timeToStopSbx = (shallStop_ || shallRestart_);
                if (timeToStopSbx)
                {
                    emit aboutToRestart();
                    p.kill();
                    p.waitForFinished();
                    if (shallStop_) {
                        restarterStopped_.notify_one();
                        return;
                    }
                    if (shallRestart_) {
                        shallRestart_ = false;
                        break;
                    }
                }
            }
        }
    });
    t.detach();
}

void ClayDojo::triggerRestart(int sbxIdx)
{
   sbxIdx_ = sbxIdx;
   shallRestart_ = true;
}

void ClayDojo::onSbxOutput()
{
    auto constexpr MAX_TIME_PER_TRY = 250;
    if (!mutex_.try_lock_for(std::chrono::milliseconds(MAX_TIME_PER_TRY))) return;
    std::lock_guard<std::timed_mutex> l(mutex_, std::adopt_lock);
    sbx_->setReadChannel(QProcess::StandardError);
    auto const msgs = sbx_->readAll();
    if (!msgs.isEmpty()) {
        auto isErr = (msgs.startsWith("ERROR") ||
                      msgs.startsWith("WARN") ||
                      msgs.startsWith("FATAL"));
        if (isErr)  qWarning("%s", qUtf8Printable(msgs));
        else  std::cout << msgs.toStdString() << std::endl;
    }
}

void ClayDojo::onFileSysChange(const QString &path)
{
   auto const dir = QFileInfo(path).absoluteDir();
   if (!dir.exists()) {
       qCritical("Cannot process dir that doesn't exist: %s",
                 qUtf8Printable(dir.path()));
   }
   auto const p = dir.path();
   qCDebug(logCat_) << "FileSys changed " << p;
   auto sourceDir = QString();
   for (auto const& s: sourceToBuildDir_)
       if (p.startsWith(s.first)) {
          sourceDir = s.first;
          break;
       }
   if (!sourceDir.isEmpty()) {
       auto const& b = sourceToBuildDir_[sourceDir];
       if (!buildWaitList_.contains(b)) {
           buildWaitList_.append(b);
           restart_.start(RAPID_CHANGE_CATCHTIME);
       }
       qCDebug(logCat_) << "Source dir changed -> wait for build " << p;
   }
   else
   {
       auto binDir = QString();
       for (auto const& b: sourceToBuildDir_)
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

void ClayDojo::onTimeToRestart()
{
    shallRestart_ = true;
}
