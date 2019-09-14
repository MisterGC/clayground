#ifndef QML_ENGINE_WRAPPER_H
#define QML_ENGINE_WRAPPER_H
#include "clayfilesysobserver.h"
#include <QObject>
#include <QQmlApplicationEngine>
#include <QSqlDatabase>
#include <QTimer>

class ClayLiveLoader: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sandboxFile READ sandboxFile NOTIFY sandboxFileChanged)
    Q_PROPERTY(QString sandboxDir READ sandboxDir NOTIFY sandboxDirChanged)

public:
    explicit ClayLiveLoader(QObject *parent = nullptr);

    QString sandboxFile() const;
    QString sandboxDir() const;
    void addDynImportDir(const QString& path);
    void show();

signals:
    void sandboxFileChanged();
    void sandboxDirChanged();
    void restarted();

private slots:
    void onFileChanged(const QString& path);
    void onFileAdded(const QString& path);
    void onFileRemoved(const QString& path);
    void onEngineWarnings(const QList<QQmlError>& warnings);
    void onTimeToRestart();

private:
    void setSandboxFile(const QString &path);
    void clearCache();
    bool isQmlPlugin(const QString &path) const;
    void storeValue(const QString& key, const QString& value);
    void storeErrors(const QString& errors);

private:
    QQmlApplicationEngine engine_;
    ClayFileSysObserver fileObserver_;
    QString sandboxFile_;
    QSqlDatabase statsDb_;
    QTimer reload_;
};

#endif
