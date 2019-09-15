#include "clayliveloader.h"
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLibrary>
#include <QQmlContext>
#include <QSqlDriver>
#include <QSqlError>
#include <QSqlQuery>
#include <QThread>

ClayLiveLoader::ClayLiveLoader(QObject *parent)
    : QObject(parent),
      sandboxFile_(""),
      statsDb_(QSqlDatabase::addDatabase("QSQLITE")),
      reload_(this),
      altMessage_("N/A")
{
    using Cll = ClayLiveLoader;
    using Cfo = ClayFileSysObserver;

    connect(&fileObserver_, &Cfo::fileChanged, this, &Cll::onFileChanged);
    connect(&fileObserver_, &Cfo::fileAdded, this, &Cll::onFileAdded);
    connect(&fileObserver_, &Cfo::fileRemoved, this, &Cll::onFileRemoved);
    connect(&engine_, &QQmlEngine::warnings, this, &Cll::onEngineWarnings);

    engine_.rootContext()->setContextProperty("ClayLiveLoader", this);
    engine_.addImportPath("plugins");
    engine_.setOfflineStoragePath(QDir::homePath() + "/.clayground");

    reload_.setSingleShot(true);
    connect(&reload_, &QTimer::timeout, this, &Cll::onTimeToRestart);

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

QString ClayLiveLoader::altMessage() const
{
    return altMessage_;
}

void ClayLiveLoader::setAltMessage(const QString &altMessage)
{
    if (altMessage != altMessage_) {
        altMessage_ = altMessage;
        emit altMessageChanged();
    }
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

    fileObserver_.observeDir(path);
}

void ClayLiveLoader::show()
{
    engine_.load(QUrl("qrc:/clayground/main.qml"));
}

void ClayLiveLoader::onTimeToRestart()
{
    const auto sbxF = sandboxFile();
    setSandboxFile("");
    clearCache();
    setSandboxFile(sbxF);
    emit restarted();
}

void ClayLiveLoader::onFileChanged(const QString &path)
{
    if (isQmlPlugin(path)) QGuiApplication::quit();
    // Use timer to trigger restart
    // so that multiple changes within a (very) short
    // period of time don't cause multiple restarts
    reload_.start(100);
}

void ClayLiveLoader::onFileAdded(const QString &path)
{
    onFileChanged(path);
}

void ClayLiveLoader::onFileRemoved(const QString &path)
{
    onFileChanged(path);
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
    engine_.collectGarbage();
    engine_.trimComponentCache();
    engine_.clearComponentCache();
    storeErrors("");
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
