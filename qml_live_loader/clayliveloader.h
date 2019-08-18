#ifndef QML_ENGINE_WRAPPER_H
#define QML_ENGINE_WRAPPER_H
#include <QQmlEngine>
#include <QObject>
#include <QFileSystemWatcher>
#include <vector>
#include <set>
#include <map>

class ClayLiveLoader: public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sandboxFile READ sandboxFile NOTIFY sandboxFileChanged)
    Q_PROPERTY(QString sandboxDir READ sandboxDir)

public:
    explicit ClayLiveLoader(QQmlEngine& engine,
                            const QString& sandboxFile,
                            QObject *parent = nullptr);
    void observeQmlDir(const QString& pathToDir);
    QString sandboxFile() const;
    QString sandboxDir() const;
    void setSandboxFile(const QString &sandboxFile);
    void clearCache();

signals:
    void sandboxFileChanged();

private slots:
    void onFileChanged(const QString& path);

private:
    void resyncOnDemand(const QString &path);
    void doActionsBasedOnType(const QString& path);

private:
    QQmlEngine& engine_;
    QFileSystemWatcher fileObserver_;
    QString sandboxFile_;
    std::map<QString, std::set<QString>> qmlFilesPerDir_;
};

#endif
