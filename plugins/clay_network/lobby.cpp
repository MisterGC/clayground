#include "lobby.h"

Lobby::Lobby(QObject *parent) :QObject(parent)
{}

void Lobby::start(){

    thread_ = new QThread(this);
    timer_.setInterval(interval_);
    timer_.moveToThread(thread_);
    thread_->start();
    connect(thread_,SIGNAL(started()),&timer_,SLOT(start()));

    auto tcpPort = port_+1;
    tcpServer_ = new QTcpServer(this);
    tcpSocket_ = new QTcpSocket(this);

    connect(tcpSocket_, SIGNAL(readyRead()), this,SLOT(readTCPDatagram()));

    // whenever a user connects, it will emit signal
    connect(tcpServer_, SIGNAL(newConnection()),
            this, SLOT(newTCPConnection()));

    while(tcpPort<port_+10 && !tcpServer_->listen(QHostAddress::Any, tcpPort))
        tcpPort++;

    udpSocket_ = new QUdpSocket(this);
    udpSocket_->bind(port_,QUdpSocket::ShareAddress);
    connect(&timer_, SIGNAL(timeout()), this, SLOT(broadcastDatagram()));
    connect(udpSocket_, SIGNAL(readyRead()), this,SLOT(processDatagram()));

    using QCA = QCoreApplication;
    QJsonObject obj{
        {"organizationName", QCA::organizationName()},
        {"organizationDomain", QCA::organizationDomain()},
        {"applicationName", QCA::applicationName()},
        {"applicationPid", QCA::applicationPid()},
        {"localHostName", QHostInfo::localHostName()},
        {"tcpPort", tcpPort},
        {"ipList", ""},
        {"UUID", appUUID}
    };

    auto allAddr = QNetworkInterface::allAddresses();
    for(const auto& h: allAddr)
    {
      if(h.protocol()==QAbstractSocket::IPv4Protocol)
        obj["ipList"] = obj["ipList"].toString()
                +(obj["ipList"].toString().isEmpty()?"":",")
                +h.toString();
    }

    QJsonDocument doc(obj);
    datagram_ = doc.toJson(QJsonDocument::Compact);
    apps_[datagram_]=QVariant(true);
}

QVariantMap Lobby::groups() const
{
    return QVariantMap(groups_);
}

QStringList Lobby::connectedGroups() const
{
    return groupList_;
}

QVariantMap Lobby::apps() const
{
    return QVariantMap(apps_);
}

QString Lobby::appUuid() const {
    return appUUID;
}

Q_INVOKABLE QVariant Lobby::appInfo(const QString &appUUID){
    return findAppByUUID(appUUID);
}

Q_INVOKABLE QStringList Lobby::appsInGroup(const QString &group) const {
    return groups_[group].toStringList();
}

void Lobby::connectApp(const QString &app)
{
    auto doc = QJsonDocument::fromJson(app.toUtf8());
    auto obj = doc.object();
    auto uuid = obj["UUID"].toString();

    if(tcpSocketMap_.count(uuid)<1)
    {
        auto ipList = obj["ipList"].toString().split(",");
        for(const auto& ip: ipList)
        {
            auto* socket = new QTcpSocket(this);
            socket->connectToHost(ip,obj["tcpPort"].toInt());
            if (socket->waitForConnected(1000))
            {
                connect(socket, SIGNAL(readyRead()), this,SLOT(readTCPDatagram()));
                tcpSocketMap_[uuid]=socket;
                socket->write(("setUUID="+appUUID).toStdString().data());
                socket->flush();
                socket->waitForBytesWritten(1000);
                emit connectedTo(uuid);
                return;
            }
        }
    }
}

void Lobby::sendMsg(const QString &msg, const QString &uuid)
{
    if(uuid.size()) //Send to a specific node
        writeTCPMsg(tcpSocketMap_[uuid],msg);
    else //Broadcast
    {
        auto sockets = tcpSocketMap_.values();
        for(auto* socket: sockets)
            writeTCPMsg(socket,msg);
    }
}

void Lobby::joinGroup(const QString &group)
{
    groupList_.append(group);
    auto glist = this->groups_[group].toStringList();
    if(!glist.contains(appUUID)){
        glist.append(appUUID);
        this->groups_[group]=glist;
        emit groupsChanged();
    }
    emit connectedGroupsChanged();
}

void Lobby::leaveGroup(const QString &group)
{
    groupList_.removeAll(group);
    //TODO: Disconnect from other that doesn't share a group anymore
    emit connectedGroupsChanged();
}

void Lobby::writeTCPMsg(QTcpSocket *socket, const QString &msg)
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

QString Lobby::findAppByUUID(QString uuid)
{
    auto keys = apps_.keys();
    for(auto& app: keys){
        if(app.contains(uuid)) return app;
    }
    return "";
}

void Lobby::broadcastDatagram()
{
    //Broadcast app details
    udpSocket_->writeDatagram(datagram_, QHostAddress::Broadcast, port_);

    //Broadcast joined groups
    if(groupList_.count()>0) {
        QJsonObject obj;
        obj["UUID"] = appUUID;
        obj["groups"] = groupList_.join(",");
        QJsonDocument doc(obj);
        udpSocket_->writeDatagram(doc.toJson(QJsonDocument::Compact), QHostAddress::Broadcast, port_);
    }
}

void Lobby::processDatagram()
{
    while (udpSocket_->hasPendingDatagrams())
    {
        QByteArray datagram;
        datagram.resize(udpSocket_->pendingDatagramSize());
        udpSocket_->readDatagram(datagram.data(), datagram.size());

        auto jsondoc = QJsonDocument::fromJson(datagram);
        if(!jsondoc["groups"].isUndefined())
        {
            auto uuid = jsondoc["UUID"].toString();
            if(uuid!=appUUID && tcpSocketMap_.count(uuid)<1){
                auto grps = jsondoc["groups"].toString().split(",");
                for(const auto& group: grps)
                {
                    auto glist = groups_[group].toStringList();
                    if(!glist.contains(uuid)){
                        glist.append(uuid);
                        groups_[group]=glist;
                        emit groupsChanged();
                    }
                    if(groupList_.contains(group)){
                        //Connect to the app that shares a group
                        connectApp(findAppByUUID(uuid));
                        emit connectedGroupsChanged();
                    }
                }
            }
            continue;
        }

        if(datagram==this->datagram_)
            continue;

        if(!apps_.count(datagram)){
            apps_[datagram]=QVariant(true);
            emit appsChanged();
        }

    }
}

void Lobby::newTCPConnection()
{
    auto *socket = tcpServer_->nextPendingConnection();
    tcpSocketUnnamedList_.append(socket);
    connect(socket, SIGNAL(readyRead()), this,SLOT(readTCPDatagram()));
}

void Lobby::readTCPDatagram()
{
    foreach (QTcpSocket *socket, tcpSocketMap_.values()) {
        QString msg = socket->readAll();
        processReceivedMessage(msg);
    }

    //TODO: If a socket gets too long in this list it should ask for its UUID or close the connection
    for(int i = tcpSocketUnnamedList_.size()-1;i>=0;i--) {
        QTcpSocket *socket=tcpSocketUnnamedList_[i];
        QString msg = socket->readAll();
        if(msg.startsWith("setUUID=")){
                tcpSocketMap_[msg.replace("setUUID=","")]=socket;
                tcpSocketUnnamedList_.removeAt(i);
                emit connectedTo(msg.replace("setUUID=",""));
        }
        else
            processReceivedMessage(msg);
    }
}

void Lobby::processReceivedMessage(QString &msg)
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
