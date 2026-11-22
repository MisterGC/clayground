// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <clayfilesysobserver.h>
#include <dojoignore.h>
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
    QString instanceName() const;
    void setInstanceName(const QString &name);
    // --restore-view (#569): the first load comes back to the view the last
    // process saved for the sandbox.
    bool restoreView() const { return restoreView_; }
    void setRestoreView(bool on) { restoreView_ = on; }
    // --paused (#572): the time control starts paused, before the first root
    bool startPaused() const { return startPaused_; }
    void setStartPaused(bool paused) { startPaused_ = paused; }
    int numRestarts() const;
    // --lab-src (#570): the directory put first on every engine's import path
    // and the kernel source directory watched for edits; empty when not set.
    void setLabSource(const QString& importDir, const QString& sourceDir);
    QString labSrcImportDir() const { return labSrcImportDir_; }
    QString labSrcDir() const { return labSrcDir_; }
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
    void reloadIgnoreFor(const QString &sandboxDir);
    void bakeShaders(const QString &sandboxDir);

    ClayFileSysObserver fileObserver_;
    DojoIgnore ignore_;
    QString ignoreFile_;
    QVector<QUrl> allSbxs_;
    int sbxIdx_ = USE_NONE_SBX_IDX;
    QSqlDatabase statsDb_;
    QTimer reload_;
    QString altMessage_;
    QString instanceName_;
    bool restoreView_ = false;
    bool startPaused_ = false;
    int numRestarts_ = 0;
    QString labSrcImportDir_;
    QString labSrcDir_;
};
