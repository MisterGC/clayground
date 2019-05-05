#include "qmlenginewrapper.h"
#include <QLoggingCategory>

QmlEngineWrapper::QmlEngineWrapper(QObject *parent)
    :QObject(parent)
{  }

void QmlEngineWrapper::clearCache()
{
    if (engine_)
    {
        engine_->trimComponentCache();
        engine_->clearComponentCache();
        engine_->trimComponentCache();
    }
}

void QmlEngineWrapper::setEngine(QQmlEngine *engine)
{
   engine_ = engine;
}


