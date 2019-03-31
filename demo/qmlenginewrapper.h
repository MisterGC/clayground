#ifndef QML_ENGINE_WRAPPER_H
#define QML_ENGINE_WRAPPER_H
#include <QQmlApplicationEngine>
class QmlEngineWrapper : public QQmlApplicationEngine
{
    Q_OBJECT

public:
    explicit QmlEngineWrapper(QObject *parent = nullptr);
    Q_INVOKABLE void clearCache();
};
#endif
