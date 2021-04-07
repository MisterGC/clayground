#pragma once

#include <QObject>
#include <qqml.h>
#include <QtNetwork>
#include <QMap>
#include <QVariant>
#include <memory>

class ClayNetworkUser : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString userId READ userId) //Id identifying the user within the network
    Q_PROPERTY(QStringList groups READ groups NOTIFY groupsChanged) //Groups this user is connected to
    Q_PROPERTY(QVariantMap allUsers READ allUsers NOTIFY usersChanged) //All users in the network
    Q_PROPERTY(QVariantMap allGroups READ allGroups NOTIFY allGroupdsChanged) //All groups in the network
    Q_INTERFACES(QQmlParserStatus)

public:
    explicit ClayNetworkUser(QObject *parent = nullptr);
    void classBegin();
    void componentComplete();
    void start();

    QVariantMap allUsers() const;
    QString userId() const;
    Q_INVOKABLE void connectToUserViaTCP(const QString &userId);
    Q_INVOKABLE void sendDirectMessage(const QString &msg, const QString &userId = "");
    Q_INVOKABLE void sendMessage(const QString &msg);
    Q_INVOKABLE QVariant userInfo(const QString &userId);
    Q_INVOKABLE QStringList usersInGroup(const QString &group) const;

    // Channels
    Q_INVOKABLE void joinGroup(const QString &groupId);
    Q_INVOKABLE void leaveGroup(const QString &groupId);
    QVariantMap allGroups() const;
    QStringList groups() const;

signals:
    void usersChanged();
    void groupsChanged();
    void allGroupdsChanged();
    void appsSharingGroupsChanged();
    void msgReceived(const QString &msg);
    void connectedTo(const QString &UUID);

private:
    void writeTCPMsg(QTcpSocket* socket, const QString &msg);
    QString userById(const QString& uuid) const;
    void processReceivedMessage(QString &msg);
    int setupTcp();
    void setupUdp();

private slots:
    void broadcastDatagram();
    void processDatagram();
    void newTCPConnection();
    void readTCPDatagram();

private:
    const QString userId_ = QUuid::createUuid().toString();
    std::unique_ptr<QUdpSocket> udpSocket_ = nullptr;
    std::unique_ptr<QTcpSocket> tcpSocket_ = nullptr;
    std::unique_ptr<QTcpServer> tcpServer_ = nullptr;
    QMap<QString,QTcpSocket*> tcpSocketMap_; //Map of the connected TCP sockets
    QStringList groups_; //Groups the user is connected to
    QMap<QString,QVariant>  allGroups_; //Groups mapped in the network
    QList<QTcpSocket*> tcpSocketUnnamedList_;
    QTimer timer_;
    std::unique_ptr<QThread> thread_;
    int interval_ = 1000;
    int port_ = 3333;
    QByteArray datagram_;
    QMap<QString, QVariant> users_;
};
