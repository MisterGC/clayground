#ifndef CLAY_RESTARTER_H
#define CLAY_RESTARTER_H 
#include "clayfilesysobserver.h"
#include <QObject>
#include <condition_variable>
#include <mutex>
#include <atomic>
#include <QProcess>
#include <QTimer>
#include <QStringList>
#include <QLoggingCategory>
#include <memory>
#include <map>

class ClayRestarter: public QObject 
{
    Q_OBJECT

public:
    ClayRestarter(QObject* parent = nullptr);
    ~ClayRestarter();
    void addDynPluginDepedency(const QString &srcPath, const QString &binPath);

public slots:
    void run();

private slots:
    void onSbxOutput();
    void onFileSysChange(const QString& path);
    void onTimeToRestart();

signals:
    void restarted();

private:
    std::mutex mutex_;
    std::condition_variable restarterStopped_;
    std::atomic_bool shallStop_;
    std::atomic_bool shallRestart_;
    std::unique_ptr<QProcess> sbx_;
    ClayFileSysObserver fileObserver_;
    std::map<QString, QString> sourceToBuildDir_;
    QStringList buildWaitList_;
    QTimer restart_;
    QLoggingCategory logCat_;
};
#endif
