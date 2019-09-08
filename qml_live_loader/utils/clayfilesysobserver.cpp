#include "clayfilesysobserver.h"
#include <QDirIterator>
#include <QFileInfo>
#include <QDebug>

ClayFileSysObserver::ClayFileSysObserver(QObject *parent) : QObject(parent)
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &ClayFileSysObserver::onFileChanged);
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &ClayFileSysObserver::onFileChanged);
}

void ClayFileSysObserver::observeDir(const QString &path)
{
    if (!QDir(path).exists()) {
        auto msg = QString("Dir %1 doesn't exist.").arg(path).toStdString();
        qFatal("%s", msg.c_str());
    }
    onDirChanged(path);
}

void ClayFileSysObserver::onDirChanged(const QString &path)
{
    auto& fo = fileObserver_;
    if (QDir(path).exists())
    {
        const auto allFiles = fo.files();
        QDirIterator it(path, QDir::Files|QDir::Dirs, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            auto fp = it.filePath();
            if (allFiles.contains(fp)) continue;
            fo.addPath(fp);
            emit fileAdded(fp);
        }
    }
    else
        fo.removePath(path);
}

void ClayFileSysObserver::onFileChanged(const QString &path)
{
    auto fi = QFileInfo(path);
    if (fi.exists())
        emit fileChanged(path);
    else {
        fileObserver_.removePath(path);
        emit fileRemoved(path);
    }
}
