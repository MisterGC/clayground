// (c) Clayground Contributors - zlib license, see "LICENSE" file

#ifndef CLAY_RESTARTER_H
#define CLAY_RESTARTER_H 
#include <clayfilesysobserver.h>
#include <utilityfunctions.h>

#include <QLoggingCategory>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QTimer>
#include <atomic>
#include <condition_variable>
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
    std::timed_mutex mutex_;
    std::condition_variable_any restarterStopped_;
    std::atomic_bool shallStop_;
    std::atomic_bool shallRestart_;
    std::atomic_int sbxIdx_;
    std::unique_ptr<QProcess> sbx_;
    ClayFileSysObserver fileObserver_;
    std::map<QString, QString> sourceToBuildDir_;
    QStringList buildWaitList_;
    QTimer restart_;
    QLoggingCategory logCat_;
};
#endif
