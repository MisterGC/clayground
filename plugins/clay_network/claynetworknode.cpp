#include <QtNetwork>

#include "claynetworknode.h"
#include "connection.h"
#include "peermanager.h"

ClayNetworkNode::ClayNetworkNode()
{
    peerManager = new PeerManager(this);
    peerManager->setServerPort(server.serverPort());

    connect(peerManager, &PeerManager::newConnection,
            this, &ClayNetworkNode::newConnection);
    connect(&server, &Server::newConnection,
            this, &ClayNetworkNode::newConnection);
}

void ClayNetworkNode::sendDirectMessage(const QString& userId, const QString &message)
{
    if (message.isEmpty()) return;
    // Support self talk
    if (userId == this->userId()) {
        newMessage(userId, message);
        return;
    }

    for (auto *c : qAsConst(peers)) {
        if (c->name() == userId) c->sendMessage(message);
    }
}

void ClayNetworkNode::broadcastMessage(const QString &message)
{
    if (message.isEmpty()) return;
    for (auto *c : qAsConst(peers)) c->sendMessage(message);
}

QString ClayNetworkNode::userId() const
{
    return peerManager->userId();
}

bool ClayNetworkNode::hasConnection(const QHostAddress &senderIp, int senderPort) const
{
    if (senderPort == -1) return peers.contains(senderIp);
    if (!peers.contains(senderIp)) return false;

    const auto conns = peers.values(senderIp);
    for (const auto *c : conns) {
        if (c->peerPort() == senderPort) return true;
    }
    return false;
}

void ClayNetworkNode::setAppData(const QString& appData)
{
    if (appData_ != appData){
        appData_ = appData;
        for (auto *c : qAsConst(peers)) c->sendAppDataUpdate(appData);
    }
}

QString ClayNetworkNode::appData() const
{
   return appData_;
}

void ClayNetworkNode::newConnection(Connection *conn)
{
    conn->setGreetingMessage(peerManager->userId());
    connect(conn, &Connection::errorOccurred, this, &ClayNetworkNode::connectionError);
    connect(conn, &Connection::disconnected, this, &ClayNetworkNode::disconnected);
    connect(conn, &Connection::readyForUse, this, &ClayNetworkNode::readyForUse);
}

void ClayNetworkNode::readyForUse()
{
    auto *conn = qobject_cast<Connection *>(sender());
    if (!conn || hasConnection(conn->peerAddress(), conn->peerPort()))
        return;

    connect(conn,  &Connection::newMessage, this, &ClayNetworkNode::newMessage);
    connect(conn,  &Connection::appDataUpdate, this, &ClayNetworkNode::appDataUpdate);
    peers.insert(conn->peerAddress(), conn);

    auto userId = conn->name();
    if (!userId.isEmpty())
        emit newParticipant(userId);
}

void ClayNetworkNode::disconnected()
{
    if (auto* conn = qobject_cast<Connection *>(sender()))
        removeConnection(conn);
}

void ClayNetworkNode::connectionError(QAbstractSocket::SocketError /* socketError */)
{
    if (auto *conn = qobject_cast<Connection *>(sender()))
        removeConnection(conn);
}

void ClayNetworkNode::removeConnection(Connection *connection)
{
    if (peers.contains(connection->peerAddress())) {
        peers.remove(connection->peerAddress());
        auto userId = connection->name();
        if (!userId.isEmpty())
            emit participantLeft(userId);
    }
    connection->deleteLater();
}

void ClayNetworkNode::classBegin()
{
}

void ClayNetworkNode::componentComplete()
{
    peerManager->startBroadcasting();
}
