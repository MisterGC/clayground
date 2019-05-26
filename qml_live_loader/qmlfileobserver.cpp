#include "qmlfileobserver.h"
#include <QLoggingCategory>
#include <QFile>

QmlReloadTrigger::QmlReloadTrigger(const QString &qmlBaseDir, QObject *parent)
    : QObject(parent), qmlBaseDir_(qmlBaseDir)
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &QmlReloadTrigger::onFileChanged);
}

void QmlReloadTrigger::observePath(const QString& qmlBaseDir)
{
   if (qmlBaseDir_ != qmlBaseDir)
   {
       fileObserver_.removePaths(fileObserver_.files());
       fileObserver_.removePaths(fileObserver_.directories());
       qmlBaseDir_ = qmlBaseDir;
   }
}

QString QmlReloadTrigger::observedPath() const
{
   return qmlBaseDir_;
}

void QmlReloadTrigger::observeFile(const QString& file)
{
    const QString path = qmlBaseDir_ + "/" + file;
    QFile f(path);
    auto ok = fileObserver_.addPath(path);
    if (!ok) qCritical() << "Unable to observe " << path;
}

void QmlReloadTrigger::onFileChanged(const QString &path)
{
    // INFO Re-add file as otherwise (at least on Linux)
    // further changes are not recognized
    fileObserver_.removePath(path);
    emit qmlFileChanged(path);
    fileObserver_.addPath(path);
}
