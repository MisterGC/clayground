// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <clayfilesysobserver.h>
#include <utilityfunctions.h>
#include <QObject>
#include <QSqlDatabase>
#include <QTimer>
#include <QUrl>

class ClayLiveLoader: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl sandboxUrl READ sandboxUrl NOTIFY sandboxUrlChanged)
    Q_PROPERTY(QString sandboxDir READ sandboxDir NOTIFY sandboxDirChanged)
    Q_PROPERTY(QStringList sandboxes READ sandboxes NOTIFY sandboxesChanged)
    Q_PROPERTY(QString altMessage READ altMessage NOTIFY altMessageChanged)
    Q_PROPERTY(int numRestarts READ numRestarts NOTIFY restarted)

public:
    explicit ClayLiveLoader(QObject *parent = nullptr);
    ~ClayLiveLoader();

    QUrl sandboxUrl() const;
    QString sandboxDir() const;
    void setSbxIndex(int sbxIdx);
    void addSandboxes(const QStringList &sbxFiles);
    QStringList sandboxes() const;
    void addDynImportDirs(const QStringList &dirs);
    void addDynPluginDir(const QString& path);
    QString altMessage() const;
    void setAltMessage(const QString &altMessage);
    int numRestarts() const;
    void postMessage(const QString& message);

public slots:
    void restartSandbox(uint8_t sbxIdx);

signals:
    void sandboxUrlChanged();
    void sandboxDirChanged();
    void sandboxesChanged();
    void altMessageChanged();
    void restarted();
    void messagePosted(const QString& message);

private slots:
    void onFileChanged(const QString& path);
    void onFileAdded(const QString& path);
    void onFileRemoved(const QString& path);
    void onTimeToRestart();

private:
    void addDynImportDir(const QString& path);
    void setSbxUrl(const QUrl &url);
    void clearCache();
    bool isQmlPlugin(const QString &path) const;
    void storeValue(const QString& key, const QString& value);
    void storeErrors(const QString& errors);
    bool restartIfDifferentSbx(const QString &path);

private:
    ClayFileSysObserver fileObserver_;
    QVector<QUrl> allSbxs_;
    int sbxIdx_ = USE_NONE_SBX_IDX;
    QSqlDatabase statsDb_;
    QTimer reload_;
    QString altMessage_;
    int numRestarts_ = 0;
};
