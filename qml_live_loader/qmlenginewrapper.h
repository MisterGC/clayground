#ifndef QML_ENGINE_WRAPPER_H
#define QML_ENGINE_WRAPPER_H
#include <QQmlEngine>
class QmlEngineWrapper: public QObject
{
    Q_OBJECT

public:
    explicit QmlEngineWrapper(QObject *parent = nullptr);
    Q_INVOKABLE void clearCache();
    void setEngine(QQmlEngine* engine);

private:
    QQmlEngine* engine_ = nullptr;
};
#endif
