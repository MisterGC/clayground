// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayliveloader.h"
#include <utilityfunctions.h>

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
    engine_.addImportPath("qml");
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

void ClayLiveLoader::restartSandbox(uint8_t sbxIdx)
{
    storeValue("command", QString("restart %1").arg(sbxIdx));
}

int ClayLiveLoader::numRestarts() const
{
    return numRestarts_;
}

void ClayLiveLoader::postMessage(const QString &message)
{
   emit messagePosted(message);
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

void ClayLiveLoader::addDynImportDirs(const QStringList& dirs)
{
    for (auto const& dir: dirs) {
        if (QDir(dir).exists()) addDynImportDir(dir);
        else
        {
            qCritical() << "Tried to add import dir '" << dir
                        << "' but this directory doesn't exist.";
        }
    }
}

void ClayLiveLoader::addSandboxes(const QStringList &sbxFiles)
{
    auto const cnt = allSbxs_.size();
    for (auto const& sbx: sbxFiles) {
        QFileInfo sbxTest(sbx);
        if (sbxTest.exists()) {
            qInfo() << "\n\nAdd Sandbox: " << sbx;
            auto const dir = sbxTest.absoluteDir().absolutePath();
            fileObserver_.observeDir(dir);
            auto const url = QUrl::fromLocalFile(sbxTest.filePath());
            allSbxs_ << url;
            qInfo() << "\n";
        }
        else
            qCritical() << "File " << sbx << " doesn't exist -> don't add sbx.";
    }

    if (allSbxs_.size() != cnt) emit sandboxesChanged();
    if (allSbxs_.isEmpty())
        qFatal("No sandbox specified or available -> cannot use any.'");
}

QStringList ClayLiveLoader::sandboxes() const
{
   QStringList lst;
   for (auto const& sbx: allSbxs_) lst << sbx.toString();
   return lst;
}


void ClayLiveLoader::addDynImportDir(const QString &path)
{
    if (!engine_.importPathList().contains(path)){
        engine_.addImportPath(path);
        fileObserver_.observeDir(path);
    }
}

void ClayLiveLoader::addDynPluginDir(const QString &path)
{
    if (!engine_.importPathList().contains(path))
        engine_.addImportPath(path);
}

void ClayLiveLoader::show()
{
    engine_.load(QUrl("qrc:/clayground/main.qml"));
}

void ClayLiveLoader::onTimeToRestart()
{
    auto const idx = sbxIdx_;
    setSbxIndex(USE_NONE_SBX_IDX);
    clearCache();
    setSbxIndex(idx);
    numRestarts_++;
    emit restarted();
}

bool ClayLiveLoader::restartIfDifferentSbx(const QString& path)
{
    auto const dir = QFileInfo(path).absoluteDir().absolutePath();
    for (size_t i = 0; i<allSbxs_.size(); ++i)
    {
       const auto& el = allSbxs_[static_cast<qsizetype>(i)];
       if(!el.isLocalFile()) continue;
       auto const sbxDir = QFileInfo(el.toLocalFile())
               .absoluteDir().absolutePath();
       if (sbxDir == dir)
       {
           if (i == sbxIdx_) break;
           else {
               restartSandbox(i);
               return true;
           }
       }
    }
    return false;
}

void ClayLiveLoader::onFileChanged(const QString &path)
{
    if (restartIfDifferentSbx(path)) return;
    if (isQmlPlugin(path)) QGuiApplication::quit();
    reload_.start(RAPID_CHANGE_CATCHTIME);
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
   for (auto const& w: warnings)
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


QUrl ClayLiveLoader::sandboxUrl() const
{
    return sbxIdx_ >= 0 ? allSbxs_[sbxIdx_] : QUrl();
}

QString ClayLiveLoader::sandboxDir() const
{
    QFileInfo info(sandboxUrl().toLocalFile());
    return info.absolutePath();
}

void ClayLiveLoader::setSbxIndex(int sbxIdx)
{
    if (sbxIdx >= allSbxs_.size()){
        qCritical() << "Sbx Idx out of bounds " << sbxIdx << " len " << allSbxs_.size();
        return;
    }

    if (sbxIdx_ != sbxIdx){
        sbxIdx_ = sbxIdx;
        auto sbxDir = QFileInfo(sandboxDir());
        if (sbxDir.exists()) addDynImportDir(sandboxDir());
        qputenv("CLAYGROUND_SBX_DIR", sandboxDir().toUtf8());
        emit sandboxUrlChanged();
        emit sandboxDirChanged();
    }
}
