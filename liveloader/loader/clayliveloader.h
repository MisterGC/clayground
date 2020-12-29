// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef QML_ENGINE_WRAPPER_H
#define QML_ENGINE_WRAPPER_H
#include <clayfilesysobserver.h>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QSqlDatabase>
#include <QTimer>
#include <QUrl>

class ClayLiveLoader: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl sandboxUrl READ sandboxUrl NOTIFY sandboxUrlChanged)
    Q_PROPERTY(QString sandboxDir READ sandboxDir NOTIFY sandboxDirChanged)
    Q_PROPERTY(QString altMessage READ altMessage NOTIFY altMessageChanged)
    Q_PROPERTY(int numRestarts READ numRestarts NOTIFY restarted)

public:
    explicit ClayLiveLoader(QObject *parent = nullptr);

    QUrl sandboxUrl() const;
    QString sandboxDir() const;
    void addDynImportDir(const QString& path);
    void addDynPluginDir(const QString& path);
    void show();
    QString altMessage() const;
    void setAltMessage(const QString &altMessage);
    int numRestarts() const;
    void postMessage(const QString& message);

signals:
    void sandboxUrlChanged();
    void sandboxDirChanged();
    void altMessageChanged();
    void restarted();
    void messagePosted(const QString& message);

private slots:
    void onFileChanged(const QString& path);
    void onFileAdded(const QString& path);
    void onFileRemoved(const QString& path);
    void onEngineWarnings(const QList<QQmlError>& warnings);
    void onTimeToRestart();

private:
    void setSandboxUrl(const QUrl &path);
    void clearCache();
    bool isQmlPlugin(const QString &path) const;
    void storeValue(const QString& key, const QString& value);
    void storeErrors(const QString& errors);

private:
    QQmlApplicationEngine engine_;
    ClayFileSysObserver fileObserver_;
    QUrl sandboxUrl_;
    QSqlDatabase statsDb_;
    QTimer reload_;
    QString altMessage_;
    int numRestarts_ = 0;
};

#endif
