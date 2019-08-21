#include "clayliveloader.h"
#include <QDirIterator>
#include <QFileInfo>
#include <QDebug>
#include <QQmlContext>
#include <QQmlEngine>

ClayLiveLoader::ClayLiveLoader(QQmlEngine &engine,
                               QObject *parent)
    : QObject(parent),
     engine_(engine),
     sandboxFile_("")
{
    engine.rootContext()->setContextProperty("ClayLiveLoader", this);
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &ClayLiveLoader::onFileChanged);
}

void ClayLiveLoader::addDynImportDir(const QString &path)
{
    if (!QDir(path).exists()) {
        auto msg = QString("Dir %1 doesn't exist.").arg(path).toStdString();
        qFatal("%s", msg.c_str());
    }
    QFileInfo sbxTest(QString("%1/Sandbox.qml").arg(path));
    if (sbxTest.exists()) {
        if (!sandboxFile_.isEmpty()) qWarning("Sanbox has been set been set before.");
        setSandboxFile(sbxTest.filePath());
    }
    if (dynImportDirs_.find(path) == dynImportDirs_.end())
        engine_.addImportPath(path);
    dynImportDirs_.insert(path);
    resyncOnDemand(path);
}

void ClayLiveLoader::onFileChanged(const QString &path)
{
    qDebug() << "On file changed";
    resyncOnDemand(path);
    const auto sbxF = sandboxFile();
    setSandboxFile("");
    clearCache();
    setSandboxFile(sbxF);
}

void ClayLiveLoader::clearCache()
{
    engine_.trimComponentCache();
    engine_.clearComponentCache();
    engine_.trimComponentCache();
}


QString ClayLiveLoader::observedDir(const QString& path) const
{
    for (auto& dir: dynImportDirs_) if (path.startsWith(dir)) return dir;
    return "";
}

void ClayLiveLoader::resyncOnDemand(const QString& path)
{
    auto& fo = fileObserver_;
    auto oDir = observedDir(path);
    static int i = 0;
    qDebug() << "Observed dir " << i++ << " " << oDir;
    if (QDir(path).exists())
    {
        if (path != oDir) return;
        qDebug() << "Resyncing";
        for (auto& f: fo.files())
            if (f.startsWith(oDir)) fo.removePath(f);
        QDirIterator it(oDir, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) fo.addPath(it.next());
        for (auto& f: fo.files()) qDebug() << "Observing " << f;
    }
    else if (QFileInfo(path).exists())
    {
        // Workaround bug on Linux file observation
        // otherwise further changes won't retrigger
        fo.removePath(path);
        fo.addPath(path);
    }
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

void ClayLiveLoader::setSandboxFile(const QString& path)
{
    if (path != sandboxFile_){
        qDebug() << "SBX: " << path;
        sandboxFile_ = path;
        emit sandboxFileChanged();
        emit sandboxDirChanged();
    }
}
