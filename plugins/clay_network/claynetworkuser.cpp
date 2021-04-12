#include "claynetworkuser.h"
#include <QDebug>
#include <QtConcurrent/QtConcurrent>

ClayNetworkUser::ClayNetworkUser(QObject *parent) :QObject(parent)
{}

void ClayNetworkUser::classBegin(){}
void ClayNetworkUser::componentComplete(){start();}

constexpr auto CLAY_NET_JSON_PROPERTY = "_CLAY_NET_";
constexpr auto TCP_PORT_PROPERTY = "tcpPort";
constexpr auto IP_LIST_PROPERTY = "ipList";
constexpr auto USER_ID_PROPERTY = "userId";

// TODO Make it configurable
constexpr auto TIME_OUT_INTERVAL_MS = 10000u; //Interval used for all TCP ops

void ClayNetworkUser::start(){

    auto tcpPort = setupTcp();

    QJsonObject obj{
        {CLAY_NET_JSON_PROPERTY, true},
        {TCP_PORT_PROPERTY, tcpPort},
        {IP_LIST_PROPERTY, ""},
        {USER_ID_PROPERTY, userId_}
    };

    auto allAddr = QNetworkInterface::allAddresses();
    for(const auto& h: allAddr)
    {
      if(h.protocol() == QAbstractSocket::IPv4Protocol)
        obj[IP_LIST_PROPERTY] = obj[IP_LIST_PROPERTY].toString()
                +(obj[IP_LIST_PROPERTY].toString().isEmpty()?"":",")
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
    if (userId == userId_) { emit msgReceived(msg); return; }
    if(!tcpSocketPerUser_.contains(userId)) {
        qWarning() << "User " << userId_  << "doesn't know recipient " << userId;
        return;
    }
    encodeAndWriteTcp(msg, userId);
}

void ClayNetworkUser::sendMessage(const QString &msg)
{
    QSet<QString> relevantUsers;
    for (const auto& g: memberships_){
        auto members = groups_[g].toStringList();
        for (const auto& m: members) relevantUsers.insert(m);
    }
    for (const auto& u: relevantUsers){
        if (tcpSocketPerUser_.contains(u)){
            auto data = msg.toUtf8();
            encodeAndWriteTcp(msg, u);
        }
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
            {USER_ID_PROPERTY, userId_},
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

        auto userId = jsondoc[USER_ID_PROPERTY].toString();
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
    if (!tcpServer_->listen(QHostAddress::AnyIPv4)){
        qCritical() << "Unable to setup tcp " << tcpServer_->errorString();
        return 0;
    }
    return tcpServer_->serverPort();
}

void ClayNetworkUser::connectViaTcpOnDemand(const QString &userInfo)
{
    auto doc = QJsonDocument::fromJson(userInfo.toUtf8());
    auto obj = doc.object();
    if (!obj.contains(USER_ID_PROPERTY)) return;
    auto userId = obj[USER_ID_PROPERTY].toString();

    if(tcpSocketPerUser_.count(userId) == 0)
    {
        auto ipList = obj[IP_LIST_PROPERTY].toString().split(",");
        auto port = obj[TCP_PORT_PROPERTY].toInt();
        for(const auto& ip: ipList)
        {
            auto* socket = new QTcpSocket(this);
            socket->connectToHost(ip, port);
            // TODO Cover by configurable timeout
            if (socket->waitForConnected(TIME_OUT_INTERVAL_MS))
            {
                auto data = userId_.toUtf8();
                writeTcp(*socket, data);
                tcpSocketPerUser_[userId] = socket;
                emit connectedTo(userId);
                return;
            }
            else
                socket->deleteLater();
            connect(socket, SIGNAL(disconnected()), this, SLOT(onTcpDisconnected()));
        }
    }
}

void ClayNetworkUser::newTcpConnection()
{
    auto *socket = tcpServer_->nextPendingConnection();
    if (!socket->waitForReadyRead(TIME_OUT_INTERVAL_MS)){
        qCritical() << "Waiting for other's userId timed out - no connection :(";
        return;
    }
    auto userId = QString::fromUtf8(socket->readAll());
    tcpSocketPerUser_[userId] = socket;
    connect(socket, SIGNAL(readyRead()), this, SLOT(readTcpMessage()));
    connect(socket, SIGNAL(disconnected()), this, SLOT(onTcpDisconnected()));
}

void ClayNetworkUser::encodeAndWriteTcp(QString msg, const QString& recipientId) {
    auto unsupportedMsg = (msg.contains(QChar::LineFeed) || msg.contains(QChar::CarriageReturn));
    if (unsupportedMsg) {
        qWarning() << "Message contains linebreak, this is not supported " << msg;
        return;
    }

    auto* socket = tcpSocketPerUser_[recipientId];
    auto sepMsg = (msg + "\n");
    QtConcurrent::run([this, socket, sepMsg](){
        auto data = sepMsg.toUtf8();
        writeTcp(*socket, data);
    });
}

void ClayNetworkUser::writeTcp(QTcpSocket& socket, QByteArray &data)
{
    socket.write(data.data());
    socket.flush();
    // TODO Make this configurable based on the amount of data
    // and network bandwidth
    socket.waitForBytesWritten(TIME_OUT_INTERVAL_MS);
}

void ClayNetworkUser::readTcpMessage()
{
    auto& socket = *qobject_cast<QTcpSocket*>(sender());
    while (socket.canReadLine()){
        auto msg = QString::fromUtf8(socket.readLine());
        emit msgReceived(msg);
    }
}

void ClayNetworkUser::onTcpDisconnected()
{
    auto socket = qobject_cast<QTcpSocket*>(sender());
    QString usrId;
    auto uids = tcpSocketPerUser_.keys();
    for (const auto& uid: uids){
        auto s = tcpSocketPerUser_[uid];
        if (s == socket) usrId = uid;
    }
    if (!usrId.isEmpty()){
        tcpSocketPerUser_.take(usrId)->deleteLater();
        users_.remove(usrId);
        emit disconnectedFrom(usrId);
    }
}
