#include "qmlenginewrapper.h"
#include <QLoggingCategory>

QmlEngineWrapper::QmlEngineWrapper(QObject *parent)
    : QQmlApplicationEngine(parent)
{  }

void QmlEngineWrapper::clearCache()
{
    this->trimComponentCache();
    this->clearComponentCache();
    this->trimComponentCache();
}


