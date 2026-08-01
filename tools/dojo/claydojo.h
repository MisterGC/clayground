// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <clayfilesysobserver.h>
#include <utilityfunctions.h>

#include <QElapsedTimer>
#include <QLoggingCategory>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QTimer>
#include <atomic>
#include <condition_variable>
#include <deque>
#include <map>
#include <memory>
#include <mutex>

class ClayDojo: public QObject 
{
    Q_OBJECT

public:
    ClayDojo(QObject* parent = nullptr);
    ~ClayDojo();
    void addDynPluginDepedency(const QString &srcPath, const QString &binPath);
    // False when the file does not exist - the caller is expected to say so
    // and stop, rather than start a dojo that supervises nothing.
    bool addSandboxDir(const QString& sandboxFile);

public slots:
    void run();
    void triggerRestart(int sbxIdx = USE_FIRST_SBX_IDX);

private slots:
    void onSbxOutput();
    void onFileSysChange(const QString& path);
    void onTimeToRestart();

signals:
    void aboutToRestart();
    void restarted();

private:
    void writeDojoState(const QString& phase, int exitCode,
                       const QString& exitStatus,
                       bool backingOff, int backoffMs,
                       const QString& reason = {});
    void writeCrashArtifact(int exitCode, const QString& exitStatus);
    void appendOutputLine(const QString& line);

private:
    std::timed_mutex mutex_;
    std::condition_variable_any restarterStopped_;
    std::atomic_bool shallStop_;
    std::atomic_bool shallRestart_;
    // The respawn thread has left the loop for good. Without it the destructor
    // waits on a condition variable nobody will ever notify - which happens
    // both when the loop gives up and when run() was never called at all
    // (a command line rejected at the front door).
    std::atomic_bool restarterStarted_{false};
    std::atomic_bool restarterDone_{false};
    std::atomic_int sbxIdx_;
    std::unique_ptr<QProcess> sbx_;
    ClayFileSysObserver fileObserver_;
    std::map<QString, QString> sourceToBuildDir_;
    QStringList buildWaitList_;
    QStringList sandboxDirs_;
    int generation_ = 0;
    int rapidCrashCount_ = 0;
    // Whether any child ever ran long enough to count as working. Without it
    // the respawn loop retries a permanently broken invocation forever.
    bool everRanStably_ = false;
    // Combined stdout+stderr tail of the child - the usage text a rejected
    // command line prints goes to stdout, and losing it is exactly how a
    // broken invocation stayed invisible.
    std::deque<QString> recentOutput_;
    QTimer restart_;
    QLoggingCategory logCat_;
};
