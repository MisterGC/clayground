#include "claynetworkuser.h"
#include <iostream>

ClayNetworkUser::ClayNetworkUser(QObject *parent) :QObject(parent)
{}

void ClayNetworkUser::classBegin(){}
void ClayNetworkUser::componentComplete(){start();}

void ClayNetworkUser::start(){

    setupUdp();
    auto tcpPort = setupTcp();

    QJsonObject obj{
        {"localHostName", QHostInfo::localHostName()},
        {"tcpPort", tcpPort},
        {"ipList", ""},
        {"UUID", userId_}
    };

    auto allAddr = QNetworkInterface::allAddresses();
    for(const auto& h: allAddr)
    {
      if(h.protocol() == QAbstractSocket::IPv4Protocol)
        obj["ipList"] = obj["ipList"].toString()
                +(obj["ipList"].toString().isEmpty()?"":",")
                +h.toString();
    }

    QJsonDocument doc(obj);
    datagram_ = doc.toJson(QJsonDocument::Compact);
    users_[userId_] = datagram_;
}

QVariantMap ClayNetworkUser::allGroups() const
{
    return QVariantMap(allGroups_);
}

QStringList ClayNetworkUser::groups() const
{
    return groups_;
}

QVariantMap ClayNetworkUser::allUsers() const
{
    return QVariantMap(users_);
}

QString ClayNetworkUser::userId() const {
    return userId_;
}

Q_INVOKABLE QVariant ClayNetworkUser::userInfo(const QString &userId){
    return userById(userId);
}

Q_INVOKABLE QStringList ClayNetworkUser::usersInGroup(const QString &group) const {
    return allGroups_[group].toStringList();
}

void ClayNetworkUser::sendDirectMessage(const QString &msg, const QString &uuid)
{
    if(!uuid.size()) return;
    writeTCPMsg(tcpSocketMap_[uuid], msg);
}

void ClayNetworkUser::sendMessage(const QString &msg)
{
    auto sockets = tcpSocketMap_.values();
    for(auto* socket: sockets)
        writeTCPMsg(socket,msg);
}

void ClayNetworkUser::joinGroup(const QString &group)
{
    groups_.append(group);
    auto glist = allGroups_[group].toStringList();
    if(!glist.contains(userId_)){
        glist.append(userId_);
        allGroups_[group]=glist;
        emit groupsChanged();
    }
    emit groupsChanged();
}

void ClayNetworkUser::leaveGroup(const QString &id)
{
    groups_.removeAll(id);
    //TODO: Disconnect from other that doesn't share a group anymore
    emit groupsChanged();
}

void ClayNetworkUser::writeTCPMsg(QTcpSocket *socket, const QString &msg)
{    
    if(socket){
        QJsonObject obj;
        obj["m"] = msg;
        auto json = QJsonDocument(obj).toJson(QJsonDocument::Compact);
        socket->write(json.data());
        socket->flush();
        socket->waitForBytesWritten(1000);
    }
}

QString ClayNetworkUser::userById(const QString &userId) const
{
    auto keys = users_.keys();
    for(auto& user: keys){
        if(user.contains(userId)) return user;
    }
    return "";
}

void ClayNetworkUser::processReceivedMessage(QString &msg)
{
    //TODO: deal with the problem when the msg contains the string "}{"
    msg = "[" + msg.replace("}{", "},{") + "]";
    auto jsondoc = QJsonDocument::fromJson(msg.toStdString().data());
    auto arr = jsondoc.array();
    for(auto el: arr) {
        auto obj = el.toObject();
        emit msgReceived(obj["m"].toString());
    }
}


///////////////////////// UDP SPECIFICS

void ClayNetworkUser::setupUdp()
{
    thread_.reset(new QThread(this));
    timer_.setInterval(interval_);
    timer_.moveToThread(thread_.get());
    thread_->start();
    connect(thread_.get(), SIGNAL(started()), &timer_, SLOT(start()));

    udpSocket_.reset(new QUdpSocket(this));
    udpSocket_->bind(port_, QUdpSocket::ShareAddress);
    connect(&timer_, SIGNAL(timeout()), this, SLOT(broadcastDatagram()));
    connect(udpSocket_.get(), SIGNAL(readyRead()), this,SLOT(processDatagram()));
}

void ClayNetworkUser::broadcastDatagram()
{
    //Broadcast app details
    udpSocket_->writeDatagram(datagram_, QHostAddress::Broadcast, port_);

    //Broadcast joined groups
    if(allGroups_.count()>0) {
        QJsonObject obj;
        obj["UUID"] = userId_;
        obj["groups"] = groups_.join(",");
        QJsonDocument doc(obj);
        udpSocket_->writeDatagram(doc.toJson(QJsonDocument::Compact), QHostAddress::Broadcast, port_);
    }
}

void ClayNetworkUser::processDatagram()
{
    while (udpSocket_->hasPendingDatagrams())
    {
        QByteArray datagram;
        datagram.resize(udpSocket_->pendingDatagramSize());
        udpSocket_->readDatagram(datagram.data(), datagram.size());

        auto jsondoc = QJsonDocument::fromJson(datagram);
        auto uuid = jsondoc["UUID"].toString();
        if (uuid == userId_) continue;

        if(!users_.count(datagram)){
            users_[datagram]=QVariant(true);
            emit usersChanged();
        }

        if(!jsondoc["groups"].isUndefined())
        {
            auto grps = jsondoc["groups"].toString().split(",");
            for(const auto& group: grps)
            {
                auto glist = allGroups_[group].toStringList();
                if(!glist.contains(uuid)){
                    glist.append(uuid);
                    allGroups_[group]=glist;
                    emit groupsChanged();
                }
                connectToUserViaTCP(userById(uuid));
                emit groupsChanged();
            }
            continue;
        }
    }
}


///////////////////////// TCP SPECIFICS

int ClayNetworkUser::setupTcp(){
    auto tcpPort = port_+1;
    tcpServer_.reset(new QTcpServer(this));
    tcpSocket_.reset(new QTcpSocket(this));
    connect(tcpSocket_.get(), SIGNAL(readyRead()), this,SLOT(readTCPDatagram()));
    connect(tcpServer_.get(), SIGNAL(newConnection()), this, SLOT(newTCPConnection()));
    while(tcpPort < port_+10 && !tcpServer_->listen(QHostAddress::Any, tcpPort))
        tcpPort++;
    return tcpPort;
}

void ClayNetworkUser::connectToUserViaTCP(const QString &userId)
{
    auto doc = QJsonDocument::fromJson(userId.toUtf8());
    auto obj = doc.object();
    auto uuid = obj["UUID"].toString();

    if(tcpSocketMap_.count(uuid) == 0)
    {
        auto ipList = obj["ipList"].toString().split(",");
        for(const auto& ip: ipList)
        {
            // TODO Fix leak
            auto* socket = new QTcpSocket(this);
            socket->connectToHost(ip, obj["tcpPort"].toInt());
            if (socket->waitForConnected(1000))
            {
                connect(socket, SIGNAL(readyRead()), this, SLOT(readTCPDatagram()));
                tcpSocketMap_[uuid] = socket;
                socket->write(("setUUID="+userId_).toStdString().data());
                socket->flush();
                socket->waitForBytesWritten(1000);
                emit connectedTo(uuid);
                return;
            }
        }
    }
}

void ClayNetworkUser::newTCPConnection()
{
    auto *socket = tcpServer_->nextPendingConnection();
    tcpSocketUnnamedList_.append(socket);
    connect(socket, SIGNAL(readyRead()), this,SLOT(readTCPDatagram()));
}

void ClayNetworkUser::readTCPDatagram()
{
    auto sockets = tcpSocketMap_.values();
    for (auto *socket: sockets) {
        auto msg = QString(socket->readAll());
        processReceivedMessage(msg);
    }

    //TODO: If a socket gets too long in this list it should ask for its UUID or close the connection
    for(int i = tcpSocketUnnamedList_.size()-1;i>=0;i--) {
        auto* socket=tcpSocketUnnamedList_[i];
        auto msg = QString(socket->readAll());
        if(msg.startsWith("setUUID=")){
                tcpSocketMap_[msg.replace("setUUID=","")]=socket;
                tcpSocketUnnamedList_.removeAt(i);
                emit connectedTo(msg.replace("setUUID=",""));
        }
        else
            processReceivedMessage(msg);
    }
}

