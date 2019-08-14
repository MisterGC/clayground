#include "qmlfileobserver.h"
#include <QLoggingCategory>
#include <QFile>

QmlReloadTrigger::QmlReloadTrigger(const QString &qmlBaseDir, QObject *parent)
    : QObject(parent), qmlBaseDir_(qmlBaseDir)
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &QmlReloadTrigger::onFileChanged);
}

QString QmlReloadTrigger::observedPath() const
{
    return qmlBaseDir_;
}

void QmlReloadTrigger::observe(const std::vector<QString> &files)
{
    for (auto& relP: files)
    {
        auto path = qmlBaseDir_ + "/" + relP;
        QFile f(path);
        auto ok = fileObserver_.addPath(path);
        if (!ok) qCritical() << "Unable to observe " << path;
    }
}

void QmlReloadTrigger::onFileChanged(const QString &path)
{
    // INFO Re-add file as otherwise (at least on Linux)
    // further changes are not recognized
    fileObserver_.removePath(path);
    emit qmlFileChanged(path);
    fileObserver_.addPath(path);
}
