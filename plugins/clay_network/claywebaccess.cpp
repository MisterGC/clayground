#include <QtNetwork>

#include "claywebaccess.h"

ClayWebAccess::ClayWebAccess(QObject* parent)
{
    connect(&networkManager_, &QNetworkAccessManager::finished,
            this, &ClayWebAccess::onFinished);
}

int ClayWebAccess::get(const QString &url)
{
    return sendRequest(QNetworkAccessManager::GetOperation, url);
}

int ClayWebAccess::postJson(const QString &url, const QString& jsonData)
{
    auto data = jsonData.toUtf8();
    return postBinary(url, data, "application/json");
}

int ClayWebAccess::putJson(const QString &url, const QString& jsonData)
{
    auto data = jsonData.toUtf8();
    return putBinary(url, data, "application/json");
}

int ClayWebAccess::postBinary(const QString &url,
                              const QByteArray& data,
                              const QString& contentType)
{
    return sendRequest(QNetworkAccessManager::PostOperation, url, data, contentType);
}

int ClayWebAccess::putBinary(const QString &url,
                             const QByteArray& data,
                             const QString& contentType)
{
    return sendRequest(QNetworkAccessManager::PutOperation, url, data, contentType);
}

int ClayWebAccess::sendRequest(QNetworkAccessManager::Operation operation,
                               const QString &url,
                               const QByteArray &data,
                               const QString &contentType,
                               const QString &authString)
{
    auto req = QNetworkRequest(url);
    if (!contentType.isEmpty())
        req.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
    QNetworkReply *reply;

    QStringList authParts = authString.split(" ", Qt::SkipEmptyParts);
    if (authParts.size() == 2) {
        QString authType = authParts[0].toLower();
        QString authToken = authParts[1];
        if (authType == "basic") {
            // Set Basic authentication header
            QByteArray auth = authToken.toUtf8().toBase64();
            req.setRawHeader("Authorization", QString("Basic %1").arg(auth.data()).toUtf8());
        }
        else if (authType == "api-key") {
            // Set API key header
            req.setRawHeader("X-API-Key", authToken.toUtf8());
        }
        else if (authType == "oauth2") {
            // Set OAuth 2.0 access token header
            req.setRawHeader("Authorization", QString("Bearer %1").arg(authToken).toUtf8());
        }
    }

    switch (operation) {
        case QNetworkAccessManager::GetOperation:
            reply = networkManager_.get(req);
            break;
        case QNetworkAccessManager::PostOperation:
            reply = networkManager_.post(req, data);
            break;
        case QNetworkAccessManager::PutOperation:
            reply = networkManager_.put(req, data);
            break;
        default:
            return -1;
    }

    int requestId = nextRequestId_++;
    pendingRequests_[requestId] = reply;
    return requestId;
}


void ClayWebAccess::onFinished(QNetworkReply *networkReply)
{
    int requestId = -1;
    int returnCode = networkReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    auto text = QString::fromUtf8(networkReply->readAll());
    for (auto it = pendingRequests_.cbegin(); it != pendingRequests_.cend(); ++it)
    {
        if (it.value() == networkReply)
        {
            requestId = it.key();
            pendingRequests_.erase(it);
            break;
        }
    }

    if (networkReply->error() == QNetworkReply::NoError)
        emit reply(requestId, returnCode, text);
    else
        emit error(requestId, returnCode, text);

    networkReply->deleteLater();
}
