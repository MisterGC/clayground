#include "qmlfileobserver.h"
#include <QLoggingCategory>
#include <QFile>

QmlFileObserver::QmlFileObserver(const QString &qmlBaseDir, QObject *parent)
    : QObject(parent), qmlBaseDir_(qmlBaseDir)
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &QmlFileObserver::onFileChanged);
}

void QmlFileObserver::observeFile(const QString &file)
{
    const QString path = qmlBaseDir_ + "/" + file;
    QFile f(path);
    qDebug() << "File to observe: " << path << " exists " << f.exists();

    auto ok = fileObserver_.addPath(path);
    qDebug() << "Observed files: " << fileObserver_.files().join(";") << " ok " << ok;
}

void QmlFileObserver::onFileChanged(const QString &path)
{
    qDebug() << "File change!";
    fileObserver_.removePath(path);
    emit qmlFileChanged(path);
    fileObserver_.addPath(path);
}
