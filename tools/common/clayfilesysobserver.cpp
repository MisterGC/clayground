// (c) Clayground Contributors - zlib license, see "LICENSE" file

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
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &ClayFileSysObserver::onFileChanged);
}

void ClayFileSysObserver::observeDir(const QString &path)
{
    if (!QDir(path).exists()) {
        auto msg = QString("Dir %1 doesn't exist.").arg(path).toStdString();
        qFatal("%s", msg.c_str());
    }
    syncWithDir(path, true);
}

void ClayFileSysObserver::syncWithDir(const QString& path, bool initial)
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
            if (!fo.addPath(fp))
                qCritical("Path %s couldn't be added for observation!",
                          qUtf8Printable(fp));
            qCDebug(logCat_) << "Observing: " << fp;
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
