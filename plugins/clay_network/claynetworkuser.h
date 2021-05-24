#pragma once

#include <QAbstractSocket>
#include <QHash>
#include <QHostAddress>
#include <QQmlComponent>
#include "server.h"

class PeerManager;

class ClayNetworkUser : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString userId READ userId) //Id identifying the user within the network
    Q_PROPERTY(QString _appData WRITE setAppData READ appData) //data which is used for app specific logic

public:
    ClayNetworkUser();

    QString userId() const;
    bool hasConnection(const QHostAddress &senderIp, int senderPort = -1) const;
    void setAppData(const QString &appData);
    QString appData() const;


public slots:
    void sendDirectMessage(const QString& userId, const QString &message);
    void broadcastMessage(const QString& message);

signals:
    void newMessage(const QString &from, const QString &message);
    void appDataUpdate(const QString &user, const QString &data);
    void newParticipant(const QString &user);
    void participantLeft(const QString &user);

private slots:
    void newConnection(Connection *conn);
    void connectionError(QAbstractSocket::SocketError socketError);
    void disconnected();
    void readyForUse();

private:
    void removeConnection(Connection *connection);

private:
    PeerManager *peerManager;
    Server server;
    QMultiHash<QHostAddress, Connection *> peers;
    QString appData_;
};
