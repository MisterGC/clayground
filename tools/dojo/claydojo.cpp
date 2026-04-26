// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claydojo.h"
#include <utilityfunctions.h>

#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSaveFile>
#include <algorithm>
#include <climits>
#include <iostream>
#include <thread>
#include <chrono>

// Exit within this window after start counts as a "rapid" termination
// (loader most likely crashed at/near load time rather than ran stably).
static constexpr int RAPID_EXIT_WINDOW_MS = 3000;
// A child that stayed alive at least this long resets the rapid-crash count.
static constexpr int STABLE_RUN_MS = 10000;
// Backoff ceiling — we never sleep longer than this between respawns.
static constexpr int BACKOFF_MAX_MS = 30000;
// After this many rapid crashes in a row we persist a crash.json artifact
// so an external agent can read a machine-readable summary.
static constexpr int CRASH_REPORT_THRESHOLD = 3;
// Stderr ring buffer size for crash-report snippets.
static constexpr size_t STDERR_BUFFER_MAX_LINES = 200;

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

void ClayDojo::addSandboxDir(const QString& sandboxFile)
{
    QFileInfo fi(sandboxFile);
    if (!fi.exists()) return;
    auto const dir = fi.absoluteDir().absolutePath();
    if (!sandboxDirs_.contains(dir))
        sandboxDirs_.append(dir);
}

void ClayDojo::appendStderrLine(const QString& line)
{
    recentStderr_.push_back(line);
    while (recentStderr_.size() > STDERR_BUFFER_MAX_LINES)
        recentStderr_.pop_front();
}

static void writeJsonAtomic(const QString& path, const QJsonObject& obj)
{
    QDir dir = QFileInfo(path).absoluteDir();
    if (!dir.exists()) dir.mkpath(".");
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
    file.commit();
}

void ClayDojo::writeDojoState(const QString& phase, int exitCode,
                              const QString& exitStatus,
                              bool backingOff, int backoffMs)
{
    if (sandboxDirs_.isEmpty()) return;

    QJsonObject state;
    state["role"] = "dojo";
    state["pid"] = static_cast<qint64>(QCoreApplication::applicationPid());
    state["generation"] = generation_;
    state["phase"] = phase;
    state["rapidCrashCount"] = rapidCrashCount_;
    state["backingOff"] = backingOff;
    if (backingOff) state["backoffMs"] = backoffMs;
    if (exitCode != INT_MIN) state["lastExitCode"] = exitCode;
    if (!exitStatus.isEmpty()) state["lastExitStatus"] = exitStatus;
    state["updatedAt"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);

    for (auto const& dir: sandboxDirs_)
        writeJsonAtomic(dir + "/.clay/inspect/dojo.json", state);
}

void ClayDojo::writeCrashArtifact(int exitCode, const QString& exitStatus)
{
    if (sandboxDirs_.isEmpty()) return;

    QJsonObject crash;
    crash["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
    crash["generation"] = generation_;
    crash["rapidCrashCount"] = rapidCrashCount_;
    crash["exitCode"] = exitCode;
    crash["exitStatus"] = exitStatus;

    QJsonArray stderrTail;
    for (auto const& line: recentStderr_)
        stderrTail.append(line);
    crash["stderrTail"] = stderrTail;

    for (auto const& dir: sandboxDirs_)
        writeJsonAtomic(dir + "/.clay/inspect/crash.json", crash);
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
            ++generation_;
            writeDojoState("starting_child", INT_MIN, {}, false, 0);
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
                writeDojoState("start_failed", INT_MIN, p.errorString(), false, 0);
                break;
            }
            QElapsedTimer childRunTime;
            childRunTime.start();
            writeDojoState("child_running", INT_MIN, {}, false, 0);
            emit restarted();
            auto ps = false;
            auto killedByUs = false;
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
                    killedByUs = true;
                    if (shallStop_) {
                        writeDojoState("stopped", p.exitCode(), "killed", false, 0);
                        restarterStopped_.notify_one();
                        return;
                    }
                    if (shallRestart_) {
                        shallRestart_ = false;
                        // User-intent restart (file change): reset backoff.
                        rapidCrashCount_ = 0;
                        break;
                    }
                }
            }

            // Child exited on its own (not killed by us). Classify as rapid
            // crash / normal exit and apply backoff before respawning.
            if (!killedByUs) {
                int exitCode = p.exitCode();
                bool crashed = (p.exitStatus() == QProcess::CrashExit);
                qint64 lived = childRunTime.elapsed();
                bool rapid = crashed || lived < RAPID_EXIT_WINDOW_MS;

                QString status = crashed ? "crash" :
                                 (exitCode == 0 ? "normal" : "error_exit");

                // A child that ran stably before exiting proves the startup
                // path is not fragile — clear any prior rapid-crash tally.
                if (lived >= STABLE_RUN_MS)
                    rapidCrashCount_ = 0;

                if (rapid)
                    ++rapidCrashCount_;

                int backoffMs = 0;
                if (rapidCrashCount_ > 0) {
                    // 500ms, 1s, 2s, 4s, ... capped
                    qint64 scaled = 500LL * (1LL << std::min(rapidCrashCount_ - 1, 6));
                    backoffMs = static_cast<int>(std::min<qint64>(scaled, BACKOFF_MAX_MS));
                }

                writeDojoState(rapid ? "child_crashed" : "child_exited",
                               exitCode, status, backoffMs > 0, backoffMs);

                if (rapidCrashCount_ >= CRASH_REPORT_THRESHOLD)
                    writeCrashArtifact(exitCode, status);

                if (backoffMs > 0) {
                    // Sleep in small slices so shallStop_/shallRestart_
                    // can break the wait promptly.
                    auto constexpr SLICE_MS = 100;
                    int waited = 0;
                    while (waited < backoffMs) {
                        std::this_thread::sleep_for(std::chrono::milliseconds(SLICE_MS));
                        waited += SLICE_MS;
                        if (shallStop_) {
                            writeDojoState("stopped", exitCode, "stopped_during_backoff",
                                           false, 0);
                            std::lock_guard<std::timed_mutex> l(mutex_);
                            restarterStopped_.notify_one();
                            return;
                        }
                        if (shallRestart_) {
                            shallRestart_ = false;
                            rapidCrashCount_ = 0;
                            break;
                        }
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
        auto const text = QString::fromUtf8(msgs);
        for (auto const& line: text.split('\n', Qt::SkipEmptyParts))
            appendStderrLine(line);
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
