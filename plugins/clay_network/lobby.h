#ifndef LOBBY_H
#define LOBBY_H

#include <QObject>
#include <qqml.h>
#include <QtNetwork>
#include <QMap>
#include <QVariant>

class Lobby : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantMap apps_ READ apps NOTIFY appsChanged) //All apps in the network
    Q_PROPERTY(QVariantMap groups READ groups NOTIFY groupsChanged) //All groups in the network
    Q_PROPERTY(QStringList connectedGroups READ connectedGroups NOTIFY connectedGroupsChanged) //Groups this app is connected to
    Q_PROPERTY(QString appUUID READ appUuid) //This app UUID
    Q_INTERFACES(QQmlParserStatus)

public:
    explicit Lobby(QObject *parent = nullptr);
    void classBegin(){}
    void componentComplete() {start();}
    void start();

    QVariantMap apps() const;
    QString appUuid() const;
    Q_INVOKABLE void connectApp(const QString &app);
    Q_INVOKABLE void sendMsg(const QString &msg, const QString &uuid = "");
    Q_INVOKABLE QVariant appInfo(const QString &appUUID);
    Q_INVOKABLE QStringList appsInGroup(const QString &group) const;

    //Groups/rooms
    Q_INVOKABLE void joinGroup(const QString &group);
    Q_INVOKABLE void leaveGroup(const QString &group);
    QVariantMap groups() const;
    QStringList connectedGroups() const;

signals:
    void appsChanged();
    void groupsChanged();
    void connectedGroupsChanged();
    void appsSharingGroupsChanged();
    void msgReceived(const QString &msg);
    void connectedTo(const QString &UUID);

private:
    void writeTCPMsg(QTcpSocket* socket, const QString &msg);
    QString findAppByUUID(QString uuid);
    void processReceivedMessage(QString &msg);

private slots:
    void broadcastDatagram();
    void processDatagram();
    void newTCPConnection();
    void readTCPDatagram();

private:
    const QString appUUID = QUuid::createUuid().toString();
    QUdpSocket *udpSocket_ = nullptr;
    QTcpSocket *tcpSocket_ = nullptr;
    QTcpServer *tcpServer_ = nullptr;
    QMap<QString,QTcpSocket*> tcpSocketMap_; //Map of the connected TCP sockets
    QStringList groupList_; //Groups the app is connected to
    QMap<QString,QVariant>  groups_; //Groups mapped in the network
    QList<QTcpSocket*> tcpSocketUnnamedList_;
    QTimer timer_;
    QThread *thread_;
    int interval_ = 1000;
    int port_ = 3333;
    QByteArray datagram_;
    QMap<QString,QVariant> apps_;
};

#endif // LOBBY_H
