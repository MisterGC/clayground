#ifndef CLAY_RESTARTER_H
#define CLAY_RESTARTER_H 
#include <QObject>
#include <condition_variable>
#include <mutex>
#include <atomic>
#include <QProcess>
#include <memory>

class ClayRestarter: public QObject 
{
    Q_OBJECT

public:
    ClayRestarter(QObject* parent = nullptr);
    ~ClayRestarter();

public slots:
    void run();

private slots:
    void onSbxOut();

signals:
    void restarted();

private:
    std::mutex mutex_;
    std::condition_variable restarterStopped_;
    std::atomic_bool shallStop_;
    std::unique_ptr<QProcess> sbx_;
};
#endif
