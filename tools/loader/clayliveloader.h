// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <utilityfunctions.h>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QSqlDatabase>
#include <QUrl>

class ClayLiveLoader: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl sandboxUrl READ sandboxUrl NOTIFY sandboxUrlChanged)
    Q_PROPERTY(QString sandboxDir READ sandboxDir NOTIFY sandboxDirChanged)
    Q_PROPERTY(QStringList sandboxes READ sandboxes NOTIFY sandboxesChanged)
    Q_PROPERTY(QString altMessage READ altMessage NOTIFY altMessageChanged)

public:
    explicit ClayLiveLoader(QObject *parent = nullptr);

    QUrl sandboxUrl() const;
    QString sandboxDir() const;
    void setSbxIndex(int sbxIdx);
    void addSandboxes(const QStringList &sbxFiles);
    QStringList sandboxes() const;
    void addDynImportDirs(const QStringList &dirs);
    void addDynPluginDir(const QString& path);
    void show();
    QString altMessage() const;
    void setAltMessage(const QString &altMessage);
    void postMessage(const QString& message);

public slots:
    void restartSandbox(uint8_t sbxIdx);
    void fadeOutAndQuit();

signals:
    void sandboxUrlChanged();
    void sandboxDirChanged();
    void sandboxesChanged();
    void altMessageChanged();
    void messagePosted(const QString& message);
    void fadeOutRequested();

private slots:
    void onEngineWarnings(const QList<QQmlError>& warnings);

private:
    void addDynImportDir(const QString& path);
    void setSbxUrl(const QUrl &url);
    void clearCache();
    void storeValue(const QString& key, const QString& value);
    void storeErrors(const QString& errors);

private:
    QQmlApplicationEngine engine_;
    QVector<QUrl> allSbxs_;
    int sbxIdx_ = USE_NONE_SBX_IDX;
    QSqlDatabase statsDb_;
    QString altMessage_;
};
