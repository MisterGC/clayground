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
        auto msg = QString("Dir %1 doesn't exist.").arg(path).toStdString();
        qFatal("%s", msg.c_str());
    }
    syncWithDir(path, true);
}

void ClayFileSysObserver::observeFile(const QString &path)
{
    QFileInfo fileInfo(path);
    if (fileInfo.exists()) {
        // Watch both the symlink and the actual file
        if (!fileObserver_.addPath(path)) {
            qCritical("File %s couldn't be added for observation!", qUtf8Printable(path));
        } else {
            qCInfo(logCat_).noquote() << "Now watching file:" << path;
        }
        
        // If it's a symlink, also watch the target
        if (fileInfo.isSymLink()) {
            QString targetPath = fileInfo.canonicalFilePath();
            if (!targetPath.isEmpty() && QFileInfo::exists(targetPath)) {
                if (!fileObserver_.addPath(targetPath)) {
                    qCritical("Symlink target %s couldn't be added for observation!", qUtf8Printable(targetPath));
                } else {
                    qCInfo(logCat_).noquote() << "Also watching symlink target:" << targetPath;
                }
            }
        }
    } else {
        qCritical("File %s doesn't exist!", qUtf8Printable(path));
    }
}

void ClayFileSysObserver::syncWithDir(const QString& path, bool initial)
{
    auto& fo = fileObserver_;
    if (QDir(path).exists())
    {
        const auto allFiles = fo.files();
        QDirIterator it(path, QDir::NoDot|QDir::NoDotDot|QDir::Files|QDir::Dirs,
                        QDirIterator::Subdirectories);
        qCInfo(logCat_).noquote() << "Observed directory:" << path;
        qCInfo(logCat_).noquote() << "Files:";
        while (it.hasNext()) {
            it.next();
            auto fp = it.filePath();
            if (allFiles.contains(fp)) continue;
            if (!fo.addPath(fp))
                qCritical("Path %s couldn't be added for observation!",
                          qUtf8Printable(fp));
            auto relativePath = QDir(path).relativeFilePath(fp);
            qCInfo(logCat_).noquote() << "- " << relativePath;
            if (!initial) emit fileAdded(fp);
        }
    }
    else
        fo.removePath(path);
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
