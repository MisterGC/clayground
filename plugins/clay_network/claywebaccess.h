// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>

class ClayWebAccess : public QObject
{
    Q_OBJECT

public:
    ClayWebAccess(QObject* parent = nullptr);

public slots:
    int get(const QString& url);
    void onFinished(QNetworkReply *networkReply);

signals:
    void reply(const QString& text);
    void error(const QString& text);

private:
    QNetworkAccessManager networkManager_;
};
