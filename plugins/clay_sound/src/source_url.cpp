// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "source_url.h"

#include <QQmlContext>
#include <QQmlEngine>

namespace clay::sound {

QUrl resolveSourceUrl(QObject *ctx, const QUrl &url)
{
    if (url.isEmpty() || url.isLocalFile() || url.scheme() == QLatin1String("file"))
        return url;
    if (auto *qctx = ctx ? QQmlEngine::contextForObject(ctx) : nullptr)
        return qctx->resolvedUrl(url);
    return url;
}

bool isLocalSourceUrl(const QUrl &url)
{
    if (url.isEmpty()) return true;
    if (url.isLocalFile()) return true;
    const auto s = url.scheme();
    return s.isEmpty()
        || s == QLatin1String("file")
        || s == QLatin1String("qrc");
}

QString sourceUrlToLocalPath(const QUrl &url)
{
    if (url.isLocalFile()) return url.toLocalFile();
    if (url.scheme() == QLatin1String("qrc")) return QStringLiteral(":") + url.path();
    return url.toString();
}

} // namespace clay::sound
