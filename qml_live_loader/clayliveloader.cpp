#include "clayliveloader.h"
#include <QDirIterator>
#include <QFileInfo>
#include <QDebug>

ClayLiveLoader::ClayLiveLoader(QQmlEngine &engine,
                               const QString& sandboxFile,
                               QObject *parent)
    : QObject(parent),
     engine_(engine),
     sandboxFile_(sandboxFile)
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &ClayLiveLoader::onFileChanged);
}

void ClayLiveLoader::clearCache()
{
    engine_.trimComponentCache();
    engine_.clearComponentCache();
    engine_.trimComponentCache();
}

void ClayLiveLoader::observeQmlDir(const QString &pathToDir)
{
    if (!QDir(pathToDir).exists()) {
        auto msg = QString("Dir %1 doesn't exist.").arg(pathToDir).toStdString();
        qFatal("%s", msg.c_str());
    }
   resyncOnDemand(pathToDir);
}

void ClayLiveLoader::onFileChanged(const QString &path)
{
    // INFO Re-add file as otherwise (at least on Linux)
    // further changes are not recognized
    fileObserver_.removePath(path);
    resyncOnDemand(path);
    doActionsBasedOnType(path);
    fileObserver_.addPath(path);
}

void ClayLiveLoader::resyncOnDemand(const QString& path)
{
    if (QDir(path).exists())
    {
        for (auto& f: qmlFilesPerDir_[path]) fileObserver_.removePath(f);
        qmlFilesPerDir_[path].clear();
        QDirIterator it(path, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) fileObserver_.addPath(it.next());
    }
}

void ClayLiveLoader::doActionsBasedOnType(const QString& /*path*/)
{
    const auto sbxF = sandboxFile();
    setSandboxFile("");
    // TODO Rebuild if it is about
    // a plugin
//    for (auto& kv: qmlFilesPerDir_){
//        if (path.startsWith(kv.first)) {

//            return;
//        }
//    }
    clearCache();
    setSandboxFile(sbxF);
}

QString ClayLiveLoader::sandboxFile() const
{
    return sandboxFile_;
}

QString ClayLiveLoader::sandboxDir() const
{
    QFileInfo info(sandboxFile_);
    return info.absolutePath();
}

void ClayLiveLoader::setSandboxFile(const QString &sandboxFilePath)
{
    if (sandboxFilePath != sandboxFile_){
        sandboxFile_ = sandboxFilePath;
        emit sandboxFileChanged();
    }
}
