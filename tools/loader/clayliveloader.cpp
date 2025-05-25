// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayliveloader.h"
#include <utilityfunctions.h>

#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlContext>
#include <QSqlDriver>
#include <QSqlError>
#include <QSqlQuery>

ClayLiveLoader::ClayLiveLoader(QObject *parent)
    : QObject(parent),
      statsDb_(QSqlDatabase::addDatabase("QSQLITE")),
      altMessage_("N/A")
{
    using Cll = ClayLiveLoader;

    connect(&engine_, &QQmlEngine::warnings, this, &Cll::onEngineWarnings);

    engine_.rootContext()->setContextProperty("ClayLiveLoader", this);
    engine_.addImportPath("qml");
    engine_.setOfflineStoragePath(QDir::homePath() + "/.clayground");

    clearCache();
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
