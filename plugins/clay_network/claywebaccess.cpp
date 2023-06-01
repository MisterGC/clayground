// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "claywebaccess.h"

#include <QtNetwork>
#include <QMetaEnum>
#include <QProcessEnvironment>
#include <QString>
#include <QStringList>
#include <QFile>

ClayWebAccess::ClayWebAccess(QObject* parent)
{
    connect(&networkManager_, &QNetworkAccessManager::finished,
            this, &ClayWebAccess::onFinished);
}

int ClayWebAccess::get(const QString &url, const QString& auth)
{
    return sendRequest(QNetworkAccessManager::GetOperation,
                       url,
                       auth);
}

int ClayWebAccess::post(const QString &url,
                        const QString& json,
                        const QString& auth)
{
    return sendRequest(QNetworkAccessManager::PostOperation,
                       url,
                       auth,
                       json.toUtf8(),
                       "application/json");
}

constexpr char ENV_PREFIX[] = "env.";
constexpr char FILE_PREFIX[] = "file://";

QString ClayWebAccess::resolveAuthString(const QString& authStr)
{
    if (authStr.startsWith(ENV_PREFIX))
    {
        auto variableName = authStr.mid(sizeof(ENV_PREFIX) - 1);
        auto env = QProcessEnvironment::systemEnvironment();
        auto value = env.value(variableName);
        return value;
    }
    else if (authStr.startsWith(FILE_PREFIX))
    {
        auto fileName = authStr.mid(sizeof(FILE_PREFIX) - 1);
        QFile file(fileName);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text))
        {
            QTextStream stream(&file);
            auto value = stream.readAll();
            file.close();
            return value.trimmed();
        }
        else
        {
            qWarning() << "Failed to open file:" << fileName;
        }
    }

    return authStr;
}

int ClayWebAccess::remPendingRequest(QNetworkReply* reply)
{
    int requestId = -1;
    for (auto it = pendingRequests_.cbegin(); it != pendingRequests_.cend(); ++it)
    {
        if (it.value() == reply)
        {
            requestId = it.key();
            pendingRequests_.erase(it);
            break;
        }
    }
    return requestId;
}

void ClayWebAccess::handleNetworkError(QNetworkReply* reply, const QString& errorDetails) {
    auto reqId = remPendingRequest(reply);
    auto errorStr = QString("Request to URL %1 failed: %2").
                    arg(reply->url().toString(), errorDetails);
    constexpr int HTTP_BAD_REQUEST = 400;
    emit error(reqId, HTTP_BAD_REQUEST, errorStr);
}

int ClayWebAccess::sendRequest(QNetworkAccessManager::Operation operation,
                               const QString &url,
                               const QString &authString,
                               const QByteArray &data,
                               const QString &contentType)
{
    auto req = QNetworkRequest(url);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    if (!contentType.isEmpty())
        req.setHeader(QNetworkRequest::ContentTypeHeader, contentType);

    auto authParts = authString.split(" ", Qt::SkipEmptyParts);
    if (authParts.size() == 2) {
        auto authType = authParts[0];
        auto authStr = authParts[1];
        if (authType == "Bearer") {
            auto resAuth = resolveAuthString(authStr);
            req.setRawHeader("Authorization",
                             QString("Bearer %1").arg(resAuth).toUtf8());
        }
        else {
            qWarning() << "Skipping unsupported auth type: " << authString;
        }
    }

    qDebug() << "Request URL:" << req.url().toString();

    QList<QByteArray> headers = req.rawHeaderList();
    qDebug() << "Request Headers:";
    foreach (const QByteArray& header, headers) {
        qDebug() << header << ":" << req.rawHeader(header);
    }

    QNetworkReply *reply = nullptr;
    switch (operation) {
        case QNetworkAccessManager::GetOperation:
            reply = networkManager_.get(req);
            break;
        case QNetworkAccessManager::PostOperation:
            reply = networkManager_.post(req, data);
            break;
        default:
            return -1;
    }

    if (reply)
    {
        // Register error handlers, they are invoked before the request
        // is handled in the finshed slot for the network manager
        connect(reply, &QNetworkReply::errorOccurred, this, [this](QNetworkReply::NetworkError code){
            auto metaEnum = QMetaEnum::fromType<QNetworkReply::NetworkError>();
            auto reply = qobject_cast<QNetworkReply*>(sender());
            auto errDetails = QString("%1 %2")
                                  .arg(metaEnum.valueToKey(code),
                                       reply->errorString());
            handleNetworkError(reply,errDetails);
        });
        connect(reply, &QNetworkReply::sslErrors, this, [this](const QList<QSslError> &errors) {
            QStringList errorMessages;
            for (const auto &error : errors) {
                errorMessages << QString("SSL error: %1").arg(error.errorString());
            }
            handleNetworkError(qobject_cast<QNetworkReply*>(sender()),
                               errorMessages.join("\n"));
        });
    }

    auto requestId = nextRequestId_++;
    pendingRequests_[requestId] = reply;
    return requestId;
}

void ClayWebAccess::onFinished(QNetworkReply *networkReply)
{
    auto requestId = remPendingRequest(networkReply);
    if (requestId != -1)
    {
        auto returnCode = networkReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        auto text = QString::fromUtf8(networkReply->readAll());
        if (networkReply->error() == QNetworkReply::NoError)
            emit reply(requestId, returnCode, text);
        else
        {
            auto errStr = QString("%1 %2").arg(text, networkReply->errorString());
            emit error(requestId, returnCode, errStr);
        }
    }
    networkReply->deleteLater();
}
