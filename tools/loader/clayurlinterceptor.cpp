// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayurlinterceptor.h"
#include <QDebug>
#include <QUrlQuery>

ClayUrlInterceptor::ClayUrlInterceptor()
    : m_cacheRevision(0)
{
}

QUrl ClayUrlInterceptor::intercept(const QUrl &url, DataType type)
{
    // Only intercept QML and JavaScript files
    if (type != QmlFile && type != JavaScriptFile) {
        return url;
    }
    
    // Don't intercept Qt resource files or non-file URLs
    if (!url.isLocalFile() || url.scheme() != "file") {
        return url;
    }
    
    // Don't intercept if already has our cache-busting parameter
    QUrlQuery existingQuery(url);
    if (existingQuery.hasQueryItem("clay_rev")) {
        return url;
    }
    
    // Only intercept files in the sandbox directory
    QString urlPath = url.toLocalFile();
    if (!urlPath.contains("/examples/") && !urlPath.contains("/plugins/")) {
        return url;
    }
    
    QMutexLocker locker(&m_mutex);
    
    // Add cache-busting parameter to force reload
    QUrl modifiedUrl = url;
    QUrlQuery query(modifiedUrl);
    query.addQueryItem("clay_rev", QString::number(m_cacheRevision));
    modifiedUrl.setQuery(query);
    
    qDebug() << "Clay intercepted:" << url.fileName() << "-> rev" << m_cacheRevision;
    
    return modifiedUrl;
}

void ClayUrlInterceptor::resetCache()
{
    QMutexLocker locker(&m_mutex);
    m_cacheRevision++;
    qDebug() << "Cache revision incremented to:" << m_cacheRevision;
}