#ifndef QML_FILE_OBSERVER_H
#define QML_FILE_OBSERVER_H 
#include <QObject>
#include <QFileSystemWatcher>
#include <vector>

class QmlReloadTrigger: public QObject
{
    Q_OBJECT

public:
    QmlReloadTrigger(const QString& qmlBaseDir, QObject* parent = nullptr);

public slots:
    QString observedPath() const;
    void observe(const std::vector<QString>& files);

private slots:
    void onFileChanged(const QString& path);

signals:
    void qmlFileChanged(const QString& path);

private:
    QString qmlBaseDir_;
    QFileSystemWatcher fileObserver_;
};
#endif
