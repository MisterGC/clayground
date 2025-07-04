// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QQmlAbstractUrlInterceptor>
#include <QUrl>
#include <QDateTime>
#include <QMutex>

class ClayUrlInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    ClayUrlInterceptor();
    
    QUrl intercept(const QUrl &url, DataType type) override;
    
    void resetCache();
    
private:
    mutable QMutex m_mutex;
    qint64 m_cacheRevision;
};