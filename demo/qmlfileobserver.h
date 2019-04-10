#ifndef QML_FILE_OBSERVER_H
#define QML_FILE_OBSERVER_H 
#include <QObject>
#include <QFileSystemWatcher>

class QmlFileObserver: public QObject
{
    Q_OBJECT
public:
    QmlFileObserver(const QString& qmlBaseDir, QObject* parent = nullptr);

public slots:
    QString observedPath() const;
    void observeFile(const QString& file);

private slots:
    void onFileChanged(const QString& path);

signals:
    void qmlFileChanged(const QString& path);

private:
    QString qmlBaseDir_;
    QFileSystemWatcher fileObserver_;
};
#endif
