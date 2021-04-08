#include "claynetworkuser.h"
#include <QDebug>

ClayNetworkUser::ClayNetworkUser(QObject *parent) :QObject(parent)
{}

void ClayNetworkUser::classBegin(){}
void ClayNetworkUser::componentComplete(){start();}

void ClayNetworkUser::start(){

    setupUdp();
    auto tcpPort = setupTcp();

    QJsonObject obj{
        {"tcpPort", tcpPort},
        {"ipList", ""},
        {"userId", userId_}
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
    users_[userId_] = QString(datagram_);
}

QVariantMap ClayNetworkUser::allGroups() const
{
    return allGroups_;
}

QStringList ClayNetworkUser::groups() const
{
    return groups_;
}

QVariantMap ClayNetworkUser::allUsers() const
{
    return users_;
}

QString ClayNetworkUser::userId() const {
    return userId_;
}

Q_INVOKABLE QVariant ClayNetworkUser::userInfo(const QString &userId){
    return userInfoForId(userId);
}

Q_INVOKABLE QStringList ClayNetworkUser::usersInGroup(const QString &group) const {
    return allGroups_[group].toStringList();
}

void ClayNetworkUser::sendDirectMessage(const QString &msg, const QString &userId)
{
    if(!tcpSocketMap_.contains(userId)) {
        qWarning() << "Cannot send direct message, there is no user " << userId;
        return;
    }
    writeTcpMsg(tcpSocketMap_[userId], msg);
}

void ClayNetworkUser::sendMessage(const QString &msg)
{
    QSet<QString> relevantUsers;
    for (const auto& g: groups_){
        auto members = allGroups_[g].toStringList();
        for (const auto& m: members) relevantUsers.insert(m);
    }
    for (const auto& u: relevantUsers){
        if (tcpSocketMap_.contains(u))
            writeTcpMsg(tcpSocketMap_[u],msg);
    }
}

void ClayNetworkUser::joinGroup(const QString &groupId)
{
    if (groups_.contains(groupId)) return;

    groups_.append(groupId);
    auto glist = allGroups_[groupId].toStringList();
    if(!glist.contains(userId_)){
        glist.append(userId_);
        allGroups_[groupId]=glist;
        emit groupsChanged();
    }
}

void ClayNetworkUser::leaveGroup(const QString &groupId)
{
    if (groups_.contains(groupId)) return;

    groups_.removeAll(groupId);
    auto glist = allGroups_[groupId].toStringList();
    if(glist.contains(userId_)){
        glist.removeAll(userId_);
        allGroups_[groupId]=glist;
        emit groupsChanged();
    }
}

QString ClayNetworkUser::userInfoForId(const QString &userId) const
{
    if (!users_.contains(userId)) {
       qWarning() << userId_ << " doesn't know "  << userId;
       return "";
    }
    return users_[userId].toString();
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
    thread_ = new QThread(this);
    timer_.setInterval(interval_);
    timer_.moveToThread(thread_);
    thread_->start();
    connect(thread_, SIGNAL(started()), &timer_, SLOT(start()));

    udpSocket_ = new QUdpSocket(this);
    udpSocket_->bind(port_, QUdpSocket::ShareAddress);
    connect(udpSocket_, SIGNAL(readyRead()), this, SLOT(processDatagram()));
    connect(&timer_, SIGNAL(timeout()), this, SLOT(broadcastDatagram()));
}

void ClayNetworkUser::broadcastDatagram()
{
    //Broadcast user details
    udpSocket_->writeDatagram(datagram_, QHostAddress::Broadcast, port_);

    //Broadcast joined groups
    if(groups_.count()>0) {
        QJsonObject obj;
        obj["userId"] = userId_;
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
        auto userId = jsondoc["userId"].toString();
        if (userId == userId_) continue;

        if(!users_.contains(userId)){
            users_[userId]=QString(datagram);
            connectViaTcpOnDemand(userInfoForId(userId));
            emit usersChanged();
        }

        auto grStr = jsondoc["groups"].toString();
        if (grStr.isEmpty()) return;

        auto grps = grStr.split(",");
        for(const auto& group: grps)
        {
            auto glist = allGroups_[group].toStringList();
            if(!glist.contains(userId)){
                glist.append(userId);
                allGroups_[group]=glist;
                emit groupsChanged();
            }
        }
    }
}


///////////////////////// TCP SPECIFICS

int ClayNetworkUser::setupTcp(){
    auto tcpPort = port_+1;
    tcpServer_ = new QTcpServer(this);
    tcpSocket_ = new QTcpSocket(this);
    connect(tcpSocket_, SIGNAL(readyRead()), this, SLOT(readTcpMessage()));
    connect(tcpServer_, SIGNAL(newConnection()), this, SLOT(newTcpConnection()));
    while(tcpPort < port_+30 && !tcpServer_->listen(QHostAddress::Any, tcpPort))
        tcpPort++;
    return tcpPort;
}

void ClayNetworkUser::connectViaTcpOnDemand(const QString &userInfo)
{
    auto doc = QJsonDocument::fromJson(userInfo.toUtf8());
    auto obj = doc.object();
    if (!obj.contains("userId")) return;
    auto userId = obj["userId"].toString();

    if(tcpSocketMap_.count(userId) == 0)
    {
        auto ipList = obj["ipList"].toString().split(",");
        auto port = obj["tcpPort"].toInt();
        for(const auto& ip: ipList)
        {
            auto* socket = new QTcpSocket(this);
            socket->connectToHost(ip, port);
            if (socket->waitForConnected(1000))
            {
                connect(socket, SIGNAL(readyRead()), this, SLOT(readTcpMessage()));
                tcpSocketMap_[userId] = socket;
                emit connectedTo(userId);
                return;
            }
            else
                socket->deleteLater();
        }
    }
}

void ClayNetworkUser::newTcpConnection()
{
    auto *socket = tcpServer_->nextPendingConnection();
    tcpSocketUnnamedList_.append(socket);
    connect(socket, SIGNAL(readyRead()), this,SLOT(readTcpMessage()));
}

void ClayNetworkUser::writeTcpMsg(QTcpSocket *socket, const QString &msg)
{
    if(socket){
        QJsonObject obj{{"m", msg}};
        auto json = QJsonDocument(obj).toJson(QJsonDocument::Compact);
        socket->write(json.data());
        socket->flush();
        socket->waitForBytesWritten(1000);
    }
}

void ClayNetworkUser::readTcpMessage()
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
        processReceivedMessage(msg);
    }
}

