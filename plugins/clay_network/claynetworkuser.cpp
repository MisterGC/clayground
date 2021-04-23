#include <QtNetwork>

#include "claynetworkuser.h"
#include "connection.h"
#include "peermanager.h"

ClayNetworkUser::ClayNetworkUser()
{
    peerManager = new PeerManager(this);
    peerManager->setServerPort(server.serverPort());
    peerManager->startBroadcasting();

    connect(peerManager, &PeerManager::newConnection,
            this, &ClayNetworkUser::newConnection);
    connect(&server, &Server::newConnection,
            this, &ClayNetworkUser::newConnection);
}

void ClayNetworkUser::sendDirectMessage(const QString& userId, const QString &message)
{
    if (message.isEmpty()) return;
    for (auto *c : qAsConst(peers)) {
        if (c->name() == userId) c->sendMessage(message);
    }
}

void ClayNetworkUser::broadcastMessage(const QString &message)
{
    if (message.isEmpty()) return;
    for (auto *c : qAsConst(peers)) c->sendMessage(message);
}

QString ClayNetworkUser::userId() const
{
    return server.serverAddress().toString() + ":" + QString::number(server.serverPort());
}

bool ClayNetworkUser::hasConnection(const QHostAddress &senderIp, int senderPort) const
{
    if (senderPort == -1) return peers.contains(senderIp);
    if (!peers.contains(senderIp)) return false;

    const auto conns = peers.values(senderIp);
    for (const auto *c : conns) {
        if (c->peerPort() == senderPort) return true;
    }
    return false;
}

void ClayNetworkUser::newConnection(Connection *conn)
{
    conn->setGreetingMessage(peerManager->userName());
    connect(conn, &Connection::errorOccurred, this, &ClayNetworkUser::connectionError);
    connect(conn, &Connection::disconnected, this, &ClayNetworkUser::disconnected);
    connect(conn, &Connection::readyForUse, this, &ClayNetworkUser::readyForUse);
}

void ClayNetworkUser::readyForUse()
{
    auto *conn = qobject_cast<Connection *>(sender());
    if (!conn || hasConnection(conn->peerAddress(), conn->peerPort()))
        return;

    connect(conn,  &Connection::newMessage, this, &ClayNetworkUser::newMessage);
    peers.insert(conn->peerAddress(), conn);

    auto userId = conn->name();
    if (!userId.isEmpty())
        emit newParticipant(userId);
}

void ClayNetworkUser::disconnected()
{
    if (auto* conn = qobject_cast<Connection *>(sender()))
        removeConnection(conn);
}

void ClayNetworkUser::connectionError(QAbstractSocket::SocketError /* socketError */)
{
    if (auto *conn = qobject_cast<Connection *>(sender()))
        removeConnection(conn);
}

void ClayNetworkUser::removeConnection(Connection *connection)
{
    if (peers.contains(connection->peerAddress())) {
        peers.remove(connection->peerAddress());
        auto nick = connection->name();
        if (!nick.isEmpty())
            emit participantLeft(nick);
    }
    connection->deleteLater();
}
