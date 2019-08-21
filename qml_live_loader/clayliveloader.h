#ifndef QML_ENGINE_WRAPPER_H
#define QML_ENGINE_WRAPPER_H
#include <QQmlEngine>
#include <QObject>
#include <QFileSystemWatcher>
#include <vector>
#include <set>

class ClayLiveLoader: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sandboxFile READ sandboxFile NOTIFY sandboxFileChanged)
    Q_PROPERTY(QString sandboxDir READ sandboxDir NOTIFY sandboxDirChanged)

public:
    explicit ClayLiveLoader(QQmlEngine& engine,
                            QObject *parent = nullptr);

    QString sandboxFile() const;
    QString sandboxDir() const;
    void addDynImportDir(const QString& path);
    void loadEntryQml();

signals:
    void sandboxFileChanged();
    void sandboxDirChanged();

private slots:
    void onFileChanged(const QString& path);

private:
    void setSandboxFile(const QString &path);
    void resyncOnDemand(const QString &path);
    QString observedDir(const QString &path) const;
    void clearCache();

private:
    QQmlEngine& engine_;
    QFileSystemWatcher fileObserver_;
    QString sandboxFile_;
    std::set<QString> dynImportDirs_;
};

#endif
