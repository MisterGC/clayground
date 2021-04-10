#pragma once

#include <QObject>
#include <qqml.h>
#include <QtNetwork>
#include <QMap>
#include <QVariant>

class ClayNetworkUser : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString userId READ userId) //Id identifying the user within the network
    Q_PROPERTY(QStringList memberships READ memberships NOTIFY membershipsChanged) //Groups this user is connected to
    Q_PROPERTY(QVariantMap users READ users NOTIFY usersChanged) //All users in the network
    Q_PROPERTY(QVariantMap groups READ groups NOTIFY groupsChanged) //All groups in the network
    Q_INTERFACES(QQmlParserStatus)

public:
    explicit ClayNetworkUser(QObject *parent = nullptr);
    void classBegin();
    void componentComplete();
    void start();

    QVariantMap users() const;
    QString userId() const;
    Q_INVOKABLE void sendDirectMessage(const QString &msg, const QString &userId = "");
    Q_INVOKABLE void sendMessage(const QString &msg);
    Q_INVOKABLE QStringList usersInGroup(const QString &group) const;

    // Channels
    Q_INVOKABLE void joinGroup(const QString &groupId);
    Q_INVOKABLE void leaveGroup(const QString &groupId);
    QVariantMap groups() const;
    QStringList memberships() const;

signals:
    void usersChanged();
    void membershipsChanged();
    void groupsChanged();
    void msgReceived(const QString &msg);
    void connectedTo(const QString &otherUser);

private:
    QString userInfoForId(const QString& uuid) const;
    QVariant userInfo(const QString &userId);
    int setupTcp();
    void connectViaTcpOnDemand(const QString &userInfo);
    void processReceivedMessage(const QString &msg);
    void startExplorationViaUdp();
    void writeTcpMsg(QTcpSocket* socket, const QString &msg);

private slots:
    void broadcastDatagram();
    void processDatagram();
    void newTcpConnection();
    void readTcpMessage();

private:
    const QString userId_ = QUuid::createUuid().toString();
    QUdpSocket* udpSocket_ = nullptr; // Used for exploration within network
    QTcpServer* tcpServer_ = nullptr; // Used for actual p2p communication

    // TODO use only one socket (map) wait for id when incoming conn.
    QMap<QString,QTcpSocket*> outTcpSocketMap_; // Used to send messages
    QList<QTcpSocket*> inTcpSockets_; // Used to receive messages

    QStringList memberships_; //Groups the user is connected to
    QVariantMap groups_; //Groups mapped in the network

    QTimer timer_;
    int interval_ = 1000;
    QByteArray datagram_;
    QVariantMap users_;
};
