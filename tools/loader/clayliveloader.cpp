// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayliveloader.h"
#include <utilityfunctions.h>

#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLibrary>
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

    reload_.setSingleShot(true);
    connect(&reload_, &QTimer::timeout, this, &Cll::onTimeToRestart);

    clearCache();
}

ClayLiveLoader::~ClayLiveLoader()
{
}

bool ClayLiveLoader::isQmlPlugin(const QString& path) const
{
    return QLibrary::isLibrary(path);
}

QStringList ClayLiveLoader::sandboxes() const
{
    QStringList sbxs;
    for (auto const& url: allSbxs_)
    {
        sbxs << url.toLocalFile();
    }
    return sbxs;
}

void ClayLiveLoader::addDynImportDirs(const QStringList &dirs)
{
    for (auto const& dir: dirs)
    {
        addDynImportDir(dir);
    }
}

QString ClayLiveLoader::altMessage() const
{
    return altMessage_;
}

void ClayLiveLoader::setAltMessage(const QString &altMessage)
{
    altMessage_ = altMessage;
    emit altMessageChanged();
}

int ClayLiveLoader::numRestarts() const
{
    return numRestarts_;
}

void ClayLiveLoader::postMessage(const QString &message)
{
    emit messagePosted(message);
}

void ClayLiveLoader::restartSandbox(uint8_t sbxIdx)
{
    setSbxIndex(sbxIdx);
}

void ClayLiveLoader::storeValue(const QString &key, const QString &value)
{
    if (!statsDb_.isOpen())
    {
        auto const theDbName = "/tmp/claystats.db";
        statsDb_.setDatabaseName(theDbName);
        if (!statsDb_.open()) {
            qCritical() << statsDb_.lastError() << "Cannot open database:" << theDbName;
            return;
        }
        QSqlQuery crtTable("CREATE TABLE IF NOT EXISTS items (k string primary key, v string)", statsDb_);
        if (crtTable.lastError().text().size()>1) qCritical() << crtTable.lastError();
    }
    QSqlQuery insItem(statsDb_);
    insItem.prepare("INSERT OR REPLACE INTO items VALUES(:k,:v)");
    insItem.bindValue(":k", key);
    insItem.bindValue(":v", value);
    insItem.exec();
    if (insItem.lastError().text().size()>1) qCritical() << insItem.lastError();
}

void ClayLiveLoader::storeErrors(const QString& errors)
{
    storeValue("errors", errors);
}

void ClayLiveLoader::addSandboxes(const QStringList &sbxFiles)
{
    for (auto const& sbx: sbxFiles)
    {
        QFileInfo sbxTest(sbx);
        if (!sbxTest.exists())
        {
            qInfo() << "\n\nSandbox file" << sbx << "doesn't exist.\n";
            continue;
        }
        else
        {
            qInfo() << "\n\nAdd Sandbox: " << sbx;
            auto const dir = sbxTest.absoluteDir().absolutePath();
            fileObserver_.observeDir(dir);
            
            // Also watch the sandbox file itself
            fileObserver_.observeFile(sbxTest.absoluteFilePath());
            
            auto const url = QUrl::fromLocalFile(sbxTest.filePath());
            allSbxs_ << url;
            qInfo() << "\n";
        }
    }
    emit sandboxesChanged();
}

void ClayLiveLoader::addDynImportDir(const QString &path)
{
    fileObserver_.observeDir(path);
}

void ClayLiveLoader::addDynPluginDir(const QString &path)
{
    // Just observe the directory for changes
    fileObserver_.observeDir(path);
}

void ClayLiveLoader::onTimeToRestart()
{
    qInfo() << "Reloading sandbox...";
    
    // Clear cache first
    clearCache();
    
    // Increment restart counter
    numRestarts_++;
    
    // Simply emit the restarted signal
    emit restarted();
    
    qInfo() << "Sandbox reloaded, total restarts:" << numRestarts_;
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
    qInfo() << "File changed:" << path;
    
    if (restartIfDifferentSbx(path)) {
        qInfo() << "Switching to different sandbox";
        return;
    }
    
    if (isQmlPlugin(path)) {
        qInfo() << "Plugin changed, quitting application";
        QGuiApplication::quit();
        return;
    }
    
    // Check if this is the current sandbox file
    if (sbxIdx_ >= 0 && sbxIdx_ < allSbxs_.size()) {
        auto currentUrl = allSbxs_[sbxIdx_];
        if (currentUrl.isLocalFile() && currentUrl.toLocalFile() == path) {
            qInfo() << "Current sandbox file changed, scheduling reload in" << RAPID_CHANGE_CATCHTIME << "ms";
        }
    }
    
    reload_.start(RAPID_CHANGE_CATCHTIME);
}

void ClayLiveLoader::onFileAdded(const QString &path)
{
    qInfo() << "++ FILE ADDED" << path;
    if (isQmlPlugin(path)) QGuiApplication::quit();
}

void ClayLiveLoader::onFileRemoved(const QString &path)
{
    qInfo() << "-- FILE REMOVED" << path;
    if (isQmlPlugin(path)) QGuiApplication::quit();
}


void ClayLiveLoader::clearCache()
{
    // In the new architecture, cache clearing is handled by HotReloadContainer
    // This method is kept for compatibility but does minimal work
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
        
        // Explicitly watch the sandbox file
        if (sbxIdx_ >= 0 && sbxIdx_ < allSbxs_.size()) {
            auto url = allSbxs_[sbxIdx_];
            if (url.isLocalFile()) {
                QString path = url.toLocalFile();
                fileObserver_.observeFile(path);
            }
        }
        
        emit sandboxUrlChanged();
        emit sandboxDirChanged();
    }
}