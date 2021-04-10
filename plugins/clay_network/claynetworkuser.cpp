#include "claynetworkuser.h"
#include <QDebug>

ClayNetworkUser::ClayNetworkUser(QObject *parent) :QObject(parent)
{}

void ClayNetworkUser::classBegin(){}
void ClayNetworkUser::componentComplete(){start();}

static const QString CLAY_NET_JSON_PROPERTY = "_CLAY_NET_";

void ClayNetworkUser::start(){

    auto tcpPort = setupTcp();

    QJsonObject obj{
        {CLAY_NET_JSON_PROPERTY, true},
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
    userInfo_ = doc.toJson(QJsonDocument::Compact);
    users_[userId_] = QString(userInfo_);

    startExplorationViaUdp();
}

QVariantMap ClayNetworkUser::groups() const
{
    return groups_;
}

QStringList ClayNetworkUser::memberships() const
{
    return memberships_;
}

QVariantMap ClayNetworkUser::users() const
{
    return users_;
}

QString ClayNetworkUser::userId() const {
    return userId_;
}

QVariant ClayNetworkUser::userInfo(const QString &userId){
    return userInfoForId(userId);
}

Q_INVOKABLE QStringList ClayNetworkUser::usersInGroup(const QString &group) const {
    return groups_[group].toStringList();
}

void ClayNetworkUser::sendDirectMessage(const QString &msg, const QString &userId)
{
    if (userId == userId_) { processReceivedMessage(msg); return; }
    if(!outTcpSocketMap_.contains(userId)) {
        qWarning() << "User " << userId_  << "doesn't know recipient " << userId;
        return;
    }
    writeTcpMsg(outTcpSocketMap_[userId], msg);
}

void ClayNetworkUser::sendMessage(const QString &msg)
{
    QSet<QString> relevantUsers;
    for (const auto& g: memberships_){
        auto members = groups_[g].toStringList();
        for (const auto& m: members) relevantUsers.insert(m);
    }
    for (const auto& u: relevantUsers){
        if (outTcpSocketMap_.contains(u))
            writeTcpMsg(outTcpSocketMap_[u],msg);
    }
}

void ClayNetworkUser::joinGroup(const QString &groupId)
{
    if (memberships_.contains(groupId)) return;

    memberships_.append(groupId);
    auto glist = groups_[groupId].toStringList();
    if(!glist.contains(userId_)){
        glist.append(userId_);
        groups_[groupId]=glist;
        emit membershipsChanged();
    }
}

void ClayNetworkUser::leaveGroup(const QString &groupId)
{
    if (memberships_.contains(groupId)) return;

    memberships_.removeAll(groupId);
    auto glist = groups_[groupId].toStringList();
    if(glist.contains(userId_)){
        glist.removeAll(userId_);
        groups_[groupId]=glist;
        emit membershipsChanged();
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

void ClayNetworkUser::processReceivedMessage(const QString &msg)
{
    auto m = msg;
    //TODO: deal with the problem when the msg contains the string "}{"
    m = "[" + m.replace("}{", "},{") + "]";
    auto jsondoc = QJsonDocument::fromJson(m.toStdString().data());
    auto arr = jsondoc.array();
    for(auto el: arr) {
        auto obj = el.toObject();
        emit msgReceived(obj["m"].toString());
    }
}


///////////////////////// UDP SPECIFICS

static constexpr auto BROADCAST_PORT = 45000u;

void ClayNetworkUser::startExplorationViaUdp()
{
    broadcastTimer_.setInterval(broadcastInterval_);

    udpSocket_ = new QUdpSocket(this);
    udpSocket_->bind(QHostAddress::Any, BROADCAST_PORT, QUdpSocket::ShareAddress
                         | QUdpSocket::ReuseAddressHint);
    connect(udpSocket_, SIGNAL(readyRead()), this, SLOT(processDatagram()));
    connect(&broadcastTimer_, SIGNAL(timeout()), this, SLOT(broadcastDatagram()));
    broadcastTimer_.start();
}

void ClayNetworkUser::broadcastDatagram()
{
    //Broadcast user details
    udpSocket_->writeDatagram(userInfo_, QHostAddress::Broadcast, BROADCAST_PORT);

    //Broadcast joined groups
    if(memberships_.count()>0) {
        QJsonObject obj{
            {CLAY_NET_JSON_PROPERTY, true},
            {"userId", userId_},
            {"groups", memberships_.join(",")},
        };
        QJsonDocument doc(obj);
        udpSocket_->writeDatagram(doc.toJson(QJsonDocument::Compact),
                                  QHostAddress::Broadcast, BROADCAST_PORT);
    }
}

void ClayNetworkUser::processDatagram()
{
    while (udpSocket_->hasPendingDatagrams())
    {
        QByteArray datagram;
        datagram.resize(udpSocket_->pendingDatagramSize());
        udpSocket_->readDatagram(datagram.data(), datagram.size());

        QJsonParseError err;
        auto jsondoc = QJsonDocument::fromJson(datagram, &err);

        // Keep it simple for the moment just ignore messages that cannot
        // be processed - reasons could be non clay network messages or corrupted
        // clay network messages but this is no problem as broadcasting is continous
        if (err.error != QJsonParseError::NoError) continue;
        if (jsondoc[CLAY_NET_JSON_PROPERTY].isUndefined()) continue;

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
            auto glist = groups_[group].toStringList();
            if(!glist.contains(userId)){
                glist.append(userId);
                groups_[group]=glist;
                emit membershipsChanged();
            }
        }
    }
}


///////////////////////// TCP SPECIFICS

int ClayNetworkUser::setupTcp(){
    tcpServer_ = new QTcpServer(this);
    connect(tcpServer_, SIGNAL(newConnection()), this, SLOT(newTcpConnection()));
    if (!tcpServer_->listen()){
        qCritical() << "Unable to setup tcp " << tcpServer_->errorString();
        return 0;
    }
    return tcpServer_->serverPort();
}

void ClayNetworkUser::connectViaTcpOnDemand(const QString &userInfo)
{
    auto doc = QJsonDocument::fromJson(userInfo.toUtf8());
    auto obj = doc.object();
    if (!obj.contains("userId")) return;
    auto userId = obj["userId"].toString();

    if(outTcpSocketMap_.count(userId) == 0)
    {
        auto ipList = obj["ipList"].toString().split(",");
        auto port = obj["tcpPort"].toInt();
        for(const auto& ip: ipList)
        {
            auto* socket = new QTcpSocket(this);
            socket->connectToHost(ip, port);
            if (socket->waitForConnected(1000))
            {
                outTcpSocketMap_[userId] = socket;
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
    inTcpSockets_.append(socket);
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
    for(int i = inTcpSockets_.size()-1;i>=0;i--) {
        auto& socket = *inTcpSockets_[i];
        if (!socket.bytesAvailable()) continue;
        auto msg = QString(socket.readAll());
        processReceivedMessage(msg);
    }
}

