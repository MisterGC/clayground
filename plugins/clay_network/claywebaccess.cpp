// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#include <QtNetwork>

#include "claywebaccess.h"

ClayWebAccess::ClayWebAccess(QObject* parent)
{
    connect(&networkManager_, &QNetworkAccessManager::finished,
            this, &ClayWebAccess::onFinished);
}

int ClayWebAccess::get(const QString &url)
{
    auto req = QNetworkRequest(url);
    networkManager_.get(req);
    // TODO Return id of request
    return 0;
}

void ClayWebAccess::onFinished(QNetworkReply *networkReply)
{
    auto text = QString::fromUtf8(networkReply->readAll());
    if (networkReply->error() == QNetworkReply::NoError)
        emit reply(text);
    else
        emit error(text);
    networkReply->deleteLater();
}
