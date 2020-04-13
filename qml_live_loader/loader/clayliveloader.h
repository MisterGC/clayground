// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef QML_ENGINE_WRAPPER_H
#define QML_ENGINE_WRAPPER_H
#include <clayfilesysobserver.h>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QSqlDatabase>
#include <QTimer>

class ClayLiveLoader: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sandboxFile READ sandboxFile NOTIFY sandboxFileChanged)
    Q_PROPERTY(QString sandboxDir READ sandboxDir NOTIFY sandboxDirChanged)
    Q_PROPERTY(QString altMessage READ altMessage NOTIFY altMessageChanged)

public:
    explicit ClayLiveLoader(QObject *parent = nullptr);

    QString sandboxFile() const;
    QString sandboxDir() const;
    void addDynImportDir(const QString& path);
    void addDynPluginDir(const QString& path);
    void show();
    QString altMessage() const;
    void setAltMessage(const QString &altMessage);

signals:
    void sandboxFileChanged();
    void sandboxDirChanged();
    void altMessageChanged();
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
    QString altMessage_;
};

#endif
