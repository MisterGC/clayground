// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QLoggingCategory>

class ClayFileSysObserver: public QObject
{
    Q_OBJECT

public:
    explicit ClayFileSysObserver(QObject *parent = nullptr);

    // Observes directory recursively
    void observeDir(const QString& path);
    
    // Observes a single file
    void observeFile(const QString& path);

signals:
    void fileChanged(const QString& path);
    void fileAdded(const QString& path);
    void fileRemoved(const QString& path);

private slots:
    void onFileChanged(const QString& path);
    void onDirChanged(const QString& path);

private:
    void syncWithDir(const QString &path, bool initial = false);

private:
    QFileSystemWatcher fileObserver_;
    QLoggingCategory logCat_;
};
