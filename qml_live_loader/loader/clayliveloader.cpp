#include "clayliveloader.h"
#include <QDirIterator>
#include <QFileInfo>
#include <QDebug>
#include <QQmlContext>
#include <QGuiApplication>
#include <QLibrary>
#include <QSqlDriver>
#include <QSqlError>
#include <QSqlQuery>

ClayLiveLoader::ClayLiveLoader(QObject *parent)
    : QObject(parent),
      sandboxFile_(""),
      statsDb_(QSqlDatabase::addDatabase("QSQLITE"))
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &ClayLiveLoader::onFileChanged);
    connect(&engine_, &QQmlEngine::warnings,
            this, &ClayLiveLoader::onEngineWarnings);
    engine_.rootContext()->setContextProperty("ClayLiveLoader", this);
    engine_.addImportPath("plugins");
    engine_.setOfflineStoragePath(QDir::homePath() + "/.clayground");
    clearCache();
}

bool ClayLiveLoader::isQmlPlugin(const QString& path) const
{
    return QLibrary::isLibrary(path);
}

void ClayLiveLoader::storeValue(const QString &key, const QString &value)
{
   if (!statsDb_.isOpen()) {
       statsDb_.setDatabaseName(engine_.offlineStorageDatabaseFilePath("clayrtdb") + ".sqlite");
       if (!statsDb_.open()) qFatal("Cannot access offline storage!");
   }

   QSqlQuery query;
   query.prepare("INSERT OR REPLACE INTO keyvalue (key, value) VALUES (:k, :v)");
   query.bindValue(":k", key);
   query.bindValue(":v", value);
   if (!query.exec())
       qCritical("Failed to update value in database: %s",
                 qUtf8Printable(query.lastError().text()));
}

void ClayLiveLoader::storeErrors(const QString &errors)
{
   storeValue("lastErrorMsg", errors);
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

    if (!engine_.importPathList().contains(path))
        engine_.addImportPath(path);

    dynImportDirs_.insert(path);
    resyncOnDemand(path);
}

void ClayLiveLoader::show()
{
    engine_.load(QUrl("qrc:/clayground/main.qml"));
}

void ClayLiveLoader::onFileChanged(const QString &path)
{
    if (isQmlPlugin(path)) QGuiApplication::quit();

    resyncOnDemand(path);
    const auto sbxF = sandboxFile();
    setSandboxFile("");
    clearCache();
    setSandboxFile(sbxF);
    emit restarted();
}

void ClayLiveLoader::onEngineWarnings(const QList<QQmlError> &warnings)
{
   QString errors = "";
   for (auto& w: warnings)
       errors += (w.toString() + "\n");
   storeErrors(errors);
}

void ClayLiveLoader::clearCache()
{
    engine_.trimComponentCache();
    engine_.clearComponentCache();
    engine_.trimComponentCache();
    storeErrors("");
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
    if (QDir(path).exists())
    {
        for (auto& f: fo.files())
            if (f.startsWith(oDir)) fo.removePath(f);
        QDirIterator it(oDir, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            auto fp = it.filePath();
            fo.addPath(fp);
        }
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
        sandboxFile_ = path;
        emit sandboxFileChanged();
        emit sandboxDirChanged();
    }
}
