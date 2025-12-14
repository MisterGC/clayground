// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayfilesysobserver.h"
#include "utilityfunctions.h"
#include <QDirIterator>
#include <QFileInfo>
#include <QDebug>
#include <QtGlobal>

ClayFileSysObserver::ClayFileSysObserver(QObject *parent) :
    QObject(parent),
    logCat_(LIVE_LOADER_CAT)
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &ClayFileSysObserver::onFileChanged);
    connect(&fileObserver_, &QFileSystemWatcher::directoryChanged,
            this, &ClayFileSysObserver::onDirChanged);
}

void ClayFileSysObserver::observeDir(const QString &path)
{
    if (!QDir(path).exists()) {
        qCWarning(logCat_) << "Directory" << path << "doesn't exist";
        return;
    }
    // Skip if already watching this directory (avoid duplicate sync)
    if (fileObserver_.directories().contains(path)) {
        return;
    }
    syncWithDir(path, true);
}

void ClayFileSysObserver::observeFile(const QString &path)
{
    QFileInfo fileInfo(path);
    if (!fileInfo.exists()) {
        qCWarning(logCat_) << "File" << path << "doesn't exist";
        return;
    }

    // Skip if already watching this file
    if (fileObserver_.files().contains(path)) {
        return;
    }

    if (fileObserver_.addPath(path)) {
        qCInfo(logCat_).noquote() << "Now watching file:" << path;
    } else {
        qCWarning(logCat_) << "File" << path << "couldn't be added for observation";
    }

    // If it's a symlink, also watch the target
    if (fileInfo.isSymLink()) {
        QString targetPath = fileInfo.canonicalFilePath();
        if (!targetPath.isEmpty() && QFileInfo::exists(targetPath) &&
            !fileObserver_.files().contains(targetPath)) {
            if (fileObserver_.addPath(targetPath)) {
                qCInfo(logCat_).noquote() << "Also watching symlink target:" << targetPath;
            } else {
                qCWarning(logCat_) << "Symlink target" << targetPath << "couldn't be added for observation";
            }
        }
    }
}

void ClayFileSysObserver::syncWithDir(const QString& path, bool initial)
{
    auto& fo = fileObserver_;
    if (!QDir(path).exists()) {
        fo.removePath(path);
        return;
    }

    const auto allFiles = fo.files();
    const auto allDirs = fo.directories();
    QDirIterator it(path, QDir::NoDot|QDir::NoDotDot|QDir::Files|QDir::Dirs,
                    QDirIterator::Subdirectories);
    qCInfo(logCat_).noquote() << "Observed directory:" << path;
    qCInfo(logCat_).noquote() << "Files:";
    while (it.hasNext()) {
        it.next();
        auto fp = it.filePath();
        // Skip if already being watched
        if (allFiles.contains(fp) || allDirs.contains(fp)) continue;
        if (!fo.addPath(fp)) {
            qCWarning(logCat_) << "Path" << fp << "couldn't be added for observation";
        }
        auto relativePath = QDir(path).relativeFilePath(fp);
        qCInfo(logCat_).noquote() << "- " << relativePath;
        if (!initial) emit fileAdded(fp);
    }
}

void ClayFileSysObserver::onDirChanged(const QString &path)
{
    syncWithDir(path);
}

void ClayFileSysObserver::onFileChanged(const QString &path)
{
    auto fi = QFileInfo(path);
    if (fi.exists()) {
        emit fileChanged(path);

        // Workaround bug on Linux file observation
        // otherwise further changes won't retrigger
        fileObserver_.addPath(path);
    }
    else {
        fileObserver_.removePath(path);
        emit fileRemoved(path);
    }
}
