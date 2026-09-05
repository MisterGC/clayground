// (c) Clayground Contributors - MIT License, see "LICENSE" file

#pragma once

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QMap>
#include <QVariantMap>
#include <QQmlComponent>

/**
 *  Class for accessing HTTP APIs.
 *  Likely to be replaced by one already available solution which is
 *  more mature.
 */
class ClayWebAccess : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    ClayWebAccess(QObject* parent = nullptr);

public slots:
    /**
     *  Performs an HTTP GET request, returns a unique request ID.
     *
     *  \a auth is a space separated auth spec: "Bearer <token>" or
     *  "Basic <user> <password>". \a headers are extra raw headers, e.g. an
     *  API key header. Every value - token, user, password, header value -
     *  may be given literally, as "env.<VARIABLE>" or as "file://<path>".
     */
    int get(const QString& url,
            const QString& auth = "",
            const QVariantMap& headers = QVariantMap());

    /** Performs an HTTP POST request, returns a unique request ID. */
    int post(const QString& url,
             const QString& json,
             const QString& auth = "",
             const QVariantMap& headers = QVariantMap());

signals:
    /** Signal emitted when a request is successfully processed. */
    void reply(int requestId, int returnCode, const QString& text);

    /** Signal emitted when a request encounters an error. */
    void error(int requestId, int returnCode, const QString& text);

private slots:
    void onFinished(QNetworkReply *networkReply);

private:
    QString resolveAuthString(const QString &authStr);
    void handleAuthorization(QNetworkRequest &req, const QString &authString);
    void applyHeaders(QNetworkRequest &req, const QVariantMap &headers);
    int remPendingRequest(QNetworkReply *reply);
    void handleNetworkError(QNetworkReply *reply, const QString &errorDetails);
    int sendRequest(QNetworkAccessManager::Operation operation,
                    const QString &url,
                    const QString &authString = "",
                    const QVariantMap &headers = QVariantMap(),
                    const QByteArray &data = QByteArray(),
                    const QString &contentType = ""
                    );

private:
    QNetworkAccessManager networkManager_;
    QMap<int, QNetworkReply*> pendingRequests_;
    int nextRequestId_ = 1;
};
