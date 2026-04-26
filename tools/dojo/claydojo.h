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
    void addSandboxDir(const QString& sandboxFile);

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
                       bool backingOff, int backoffMs);
    void writeCrashArtifact(int exitCode, const QString& exitStatus);
    void appendStderrLine(const QString& line);

private:
    std::timed_mutex mutex_;
    std::condition_variable_any restarterStopped_;
    std::atomic_bool shallStop_;
    std::atomic_bool shallRestart_;
    std::atomic_int sbxIdx_;
    std::unique_ptr<QProcess> sbx_;
    ClayFileSysObserver fileObserver_;
    std::map<QString, QString> sourceToBuildDir_;
    QStringList buildWaitList_;
    QStringList sandboxDirs_;
    int generation_ = 0;
    int rapidCrashCount_ = 0;
    std::deque<QString> recentStderr_;
    QTimer restart_;
    QLoggingCategory logCat_;
};
