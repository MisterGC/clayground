#include "lobby.h"

Lobby::Lobby(QObject *parent) :
    QObject(parent)
{
   // start();
}

void Lobby::start(){

    thread = new QThread(this);
    timer.setInterval(interval);
    timer.moveToThread(thread);
    thread->start();
    connect(thread,SIGNAL(started()),&timer,SLOT(start()));

    int tcpPort = port+1;
    tcpServer = new QTcpServer(this);
    tcpSocket = new QTcpSocket(this);

    connect(tcpSocket, SIGNAL(readyRead()), this,SLOT(readTCPDatagram()));

    // whenever a user connects, it will emit signal
    connect(tcpServer, SIGNAL(newConnection()),
            this, SLOT(newTCPConnection()));

    while(tcpPort<port+10&&!tcpServer->listen(QHostAddress::Any, tcpPort))
        tcpPort++;

    udpSocket = new QUdpSocket(this);
    udpSocket->bind(port,QUdpSocket::ShareAddress);
    connect(&timer, SIGNAL(timeout()), this, SLOT(broadcastDatagram()));
    connect(udpSocket, SIGNAL(readyRead()), this,SLOT(processDatagram()));

    QJsonObject obj;
    obj["organizationName"] = QCoreApplication::organizationName();
    obj["organizationDomain"] = QCoreApplication::organizationDomain();
    obj["applicationName"] = QCoreApplication::applicationName();
    obj["applicationPid"] = QCoreApplication::applicationPid();
    obj["localHostName"] = QHostInfo::localHostName();
    obj["tcpPort"] = tcpPort;
    obj["ipList"] = "";
    obj["UUID"] = appUUID;

    for(QHostAddress h: QNetworkInterface::allAddresses()){
      if(h.protocol()==QAbstractSocket::IPv4Protocol)
        obj["ipList"] = obj["ipList"].toString()
                +(obj["ipList"].toString().isEmpty()?"":",")
                +h.toString();
    }

    QJsonDocument doc(obj);
    datagram = doc.toJson(QJsonDocument::Compact);
}

void Lobby::connectApp(const QString &app)
{
    QJsonDocument doc = QJsonDocument::fromJson(app.toUtf8());
    QJsonObject obj = doc.object();

    for(const QString &ip:obj["ipList"].toString().split(","))
    {
        QTcpSocket *socket = new QTcpSocket(this);

        socket->connectToHost(ip,obj["tcpPort"].toInt());
        if (socket->waitForConnected(1000)){
            connect(socket, SIGNAL(readyRead()), this,SLOT(readTCPDatagram()));
            tcpSocketMap[obj["UUID"].toString()]=socket;
            socket->write(("setUUID="+appUUID).toStdString().data());
            socket->flush();
            socket->waitForBytesWritten(1000);
            emit connectedTo(obj["UUID"].toString());
            return;
        }
    }
    qDebug()<<"not connected";
}

void Lobby::sendMsg(const QString &msg, const QString &UUID)
{
    if(UUID.size()) //Send to a specific node
        writeTCPMsg(tcpSocketMap[UUID],msg);
    else //Broadcast
        foreach (QTcpSocket *socket, tcpSocketMap.values()) {
            writeTCPMsg(socket,msg);
        }

}

void Lobby::joinGroup(const QString &group)
{
    groupList.append(group);
}

void Lobby::leaveGroup(const QString &group)
{
    groupList.removeAll(group);
}

void Lobby::writeTCPMsg(QTcpSocket *socket, const QString &msg)
{
    if(socket){
        socket->write(msg.toStdString().data());
        socket->flush();
        socket->waitForBytesWritten(1000);
    }
}

void Lobby::broadcastDatagram()
{
    //Broadcast app details
    udpSocket->writeDatagram(datagram, QHostAddress::Broadcast, port);


    //Broadcast joined groups
    QJsonObject obj;
    obj["UUID"] = appUUID;
    obj["groups"] = groupList.join(",");
    QJsonDocument doc(obj);
    udpSocket->writeDatagram(doc.toJson(QJsonDocument::Compact), QHostAddress::Broadcast, port);
}

void Lobby::processDatagram()
{
    while (udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(udpSocket->pendingDatagramSize());
        udpSocket->readDatagram(datagram.data(), datagram.size());


        //TODO Process the app and groups datagrams, when there's another app on the same group, it need to
        // be added to br conneted to this



        if(datagram==this->datagram)
            continue;

        if(!apps.count(datagram)){
            apps[datagram]=QVariant(true);
            emit appsChanged();
        }

    }
}

void Lobby::newTCPConnection()
{
    QTcpSocket *socket = tcpServer->nextPendingConnection();
    tcpSocketUnnamedList.append(socket);
    connect(socket, SIGNAL(readyRead()), this,SLOT(readTCPDatagram()));
}

void Lobby::readTCPDatagram()
{
    foreach (QTcpSocket *socket, tcpSocketMap.values()) {
        QString msg = socket->readAll();
        emit msgReceived(msg);
    }

    //TODO: If a socket gets too long in this list it should ask for its UUID or close the connection
    for(int i = tcpSocketUnnamedList.size()-1;i>=0;i--) {
        QTcpSocket *socket=tcpSocketUnnamedList[i];
        QString msg = socket->readAll();
        if(msg.startsWith("setUUID=")){
                tcpSocketMap[msg.replace("setUUID=","")]=socket;
                tcpSocketUnnamedList.removeAt(i);
                emit connectedTo(msg.replace("setUUID=",""));
        }
        else
            emit msgReceived(msg);
    }
}
