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

int ClayWebAccess::get(const QString &url,
                       const QString& auth,
                       const QVariantMap& headers)
{
    return sendRequest(QNetworkAccessManager::GetOperation,
                       url,
                       auth,
                       headers);
}

int ClayWebAccess::post(const QString &url,
                        const QString& json,
                        const QString& auth,
                        const QVariantMap& headers)
{
    return sendRequest(QNetworkAccessManager::PostOperation,
                       url,
                       auth,
                       headers,
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

void ClayWebAccess::handleAuthorization(QNetworkRequest &req, const QString &authString)
{
    // The scheme is the first word, the credential is everything after it.
    // Splitting by hand instead of by QString::split keeps a Basic password
    // that contains spaces intact - it is the last field and never a
    // delimiter.
    auto schemeEnd = authString.indexOf(' ');
    if (schemeEnd < 0) return;
    auto authType = authString.left(schemeEnd);
    auto credential = authString.mid(schemeEnd + 1).trimmed();
    if (credential.isEmpty()) return;

    if (authType == "Bearer") {
        auto resAuth = resolveAuthString(credential);
        req.setRawHeader("Authorization",
                         QString("Bearer %1").arg(resAuth).toUtf8());
    }
    else if (authType == "Basic") {
        // "<user> <password>", space separated rather than the ":" of the
        // header itself: a "file://" reference contains a colon and would
        // otherwise be split in the middle. Each field is resolved on its
        // own, so a password can come from a file while the user stays inline.
        auto userEnd = credential.indexOf(' ');
        auto user = userEnd < 0 ? credential : credential.left(userEnd);
        auto password = userEnd < 0 ? QString() : credential.mid(userEnd + 1);
        auto pair = QString("%1:%2").arg(resolveAuthString(user),
                                         resolveAuthString(password));
        req.setRawHeader("Authorization", "Basic " + pair.toUtf8().toBase64());
    }
    else {
        qWarning() << "Skipping unsupported auth type: " << authString;
    }
}

void ClayWebAccess::applyHeaders(QNetworkRequest &req, const QVariantMap &headers)
{
    for (auto it = headers.cbegin(); it != headers.cend(); ++it)
    {
        auto value = resolveAuthString(it.value().toString());
        if (it.key().isEmpty() || value.isEmpty()) continue;
        req.setRawHeader(it.key().toUtf8(), value.toUtf8());
    }
}

int ClayWebAccess::sendRequest(QNetworkAccessManager::Operation operation,
                               const QString &url,
                               const QString &authString,
                               const QVariantMap &headers,
                               const QByteArray &data,
                               const QString &contentType)
{
    auto req = QNetworkRequest(QUrl(url));
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    if (!contentType.isEmpty())
        req.setHeader(QNetworkRequest::ContentTypeHeader, contentType);

    handleAuthorization(req, authString);
    applyHeaders(req, headers);

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
#ifndef __EMSCRIPTEN__
        connect(reply, &QNetworkReply::sslErrors, this, [this](const QList<QSslError> &errors) {
            QStringList errorMessages;
            for (const auto &error : errors) {
                errorMessages << QString("SSL error: %1").arg(error.errorString());
            }
            handleNetworkError(qobject_cast<QNetworkReply*>(sender()),
                               errorMessages.join("\n"));
        });
#endif
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
