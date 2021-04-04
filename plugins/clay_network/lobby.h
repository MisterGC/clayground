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
    Q_PROPERTY(QVariantMap apps READ getApps NOTIFY appsChanged) //All apps in the network
    Q_PROPERTY(QVariantMap groups READ getGroups NOTIFY groupsChanged) //All groups in the network
    Q_PROPERTY(QStringList connectedGroups READ getConnectedGroups NOTIFY connectedGroupsChanged) //Groups this app is connected to
    Q_PROPERTY(QString appUUID READ getAppUUID) //This app UUID
    Q_INTERFACES(QQmlParserStatus)
public:
    explicit Lobby(QObject *parent = nullptr);
    void classBegin(){}
    void componentComplete() {start();}
    void start();
    const QString appUUID = QUuid::createUuid().toString();
    QVariantMap getApps(){return QVariantMap(apps);}
    QString getAppUUID(){return appUUID;}
    Q_INVOKABLE void connectApp(const QString &app);
    Q_INVOKABLE void sendMsg(const QString &msg, const QString &UUID = "");
    Q_INVOKABLE QVariant getAppInfo(const QString &appUUID){return findAppByUUID(appUUID);}
    Q_INVOKABLE QStringList getAppsInGroup(const QString &group){return groups[group].toStringList();}

    //Groups/rooms
    Q_INVOKABLE void joinGroup(const QString &group);
    Q_INVOKABLE void leaveGroup(const QString &group);
    QVariantMap getGroups(){return QVariantMap(groups);}
    QStringList getConnectedGroups(){return groupList;}

signals:
    void appsChanged();
    void groupsChanged();
    void connectedGroupsChanged();
    void appsSharingGroupsChanged();
    void msgReceived(const QString &msg);
    void connectedTo(const QString &UUID);

private:
    QUdpSocket *udpSocket = nullptr;
    QTcpSocket *tcpSocket = nullptr;
    QTcpServer *tcpServer = nullptr;
    QMap<QString,QTcpSocket*> tcpSocketMap; //Map of the connected TCP sockets
    QStringList groupList; //Groups the app is connected to
    QMap<QString,QVariant>  groups; //Groups mapped in the network
    QList<QTcpSocket*> tcpSocketUnnamedList;
    QTimer timer;
    QThread *thread;
    int interval = 1000;
    int port = 3333;
    QByteArray datagram;
    QMap<QString,QVariant> apps;
    void writeTCPMsg(QTcpSocket* socket, const QString &msg);

    QString findAppByUUID(QString UUID);
    void processReceivedMessage(QString &msg);

private slots:
    void broadcastDatagram();
    void processDatagram();
    void newTCPConnection();
    void readTCPDatagram();

};

#endif // LOBBY_H
