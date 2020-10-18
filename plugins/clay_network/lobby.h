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
    Q_PROPERTY(QVariantMap apps READ getApps NOTIFY appsChanged)
    Q_INTERFACES(QQmlParserStatus)
public:
    explicit Lobby(QObject *parent = nullptr);
    void classBegin(){}
    void componentComplete() {start();}
    void start();
    QVariantMap getApps(){return QVariantMap(apps);}
    Q_INVOKABLE void connectApp(const QString &app);
    Q_INVOKABLE void sendMsg(const QString &msg, const QString &UUID = "");
    const QString appUUID = QUuid::createUuid().toString();

    //Groups/rooms
    Q_INVOKABLE void joinGroup(const QString &group);
    Q_INVOKABLE void leaveGroup(const QString &group);

signals:
    void appsChanged();
    void msgReceived(const QString &msg);
    void connectedTo(const QString &UUID);

private:
    QUdpSocket *udpSocket = nullptr;
    QTcpSocket *tcpSocket = nullptr;
    QTcpServer *tcpServer = nullptr;
    QMap<QString,QTcpSocket*> tcpSocketMap; //Map of the connected TCP sockets
    QStringList groupList; //Groups the app is connected to
    QList<QTcpSocket*> tcpSocketUnnamedList;
    QTimer timer;
    QThread *thread;
    int interval = 1000;
    int port = 3333;
    QByteArray datagram;
    QMap<QString,QVariant> apps;
    void writeTCPMsg(QTcpSocket* socket, const QString &msg);

    QString findAppByUUID(QString UUID);

private slots:
    void broadcastDatagram();
    void processDatagram();
    void newTCPConnection();
    void readTCPDatagram();

};

#endif // LOBBY_H
