// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QMap>
#include <QQmlComponent>

class ClayWebAccess : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    ClayWebAccess(QObject* parent = nullptr);

public slots:
    int get(const QString& url);
    int postJson(const QString& url, const QString& jsonData);
    int putJson(const QString& url, const QString& jsonData);
    int postBinary(const QString& url,
                   const QByteArray& data,
                   const QString& contentType = "");
    int putBinary(const QString& url,
                  const QByteArray& data,
                   const QString& contentType = "");
    void onFinished(QNetworkReply *networkReply);

private:
    int sendRequest(QNetworkAccessManager::Operation operation,
                    const QString &url,
                    const QByteArray &data = QByteArray(),
                    const QString &contentType = "");

signals:
    void reply(int requestId, int returnCode, const QString& text);
    void error(int requestId, int returnCode, const QString& text);

private:
    QNetworkAccessManager networkManager_;
    QMap<int, QNetworkReply*> pendingRequests_;
    int nextRequestId_ = 1;
};
