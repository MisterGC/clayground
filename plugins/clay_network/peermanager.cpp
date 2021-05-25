/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Copyright (C) 2018 Intel Corporation.
** Contact: https://www.qt.io/licensing/
** Copyright (C) 2021 serein.pfeiffer@gmail.com
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of The Qt Company Ltd nor the names of its
**     contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
**
****************************************************************************/

#include <QtNetwork>
#include <QUuid>

#include "claynetworknode.h"
#include "connection.h"
#include "peermanager.h"

static const qint32 BroadcastInterval = 2000;
static const unsigned broadcastPort = 45000;

PeerManager::PeerManager(ClayNetworkNode *client)
    : QObject(client)
{
    this->client = client;

    userid = QUuid::createUuid().toString();

    updateAddresses();
    serverPort = 0;

    broadcastSocket.bind(QHostAddress::Any, broadcastPort, QUdpSocket::ShareAddress
                         | QUdpSocket::ReuseAddressHint);
    connect(&broadcastSocket, &QUdpSocket::readyRead,
            this, &PeerManager::readBroadcastDatagram);

    broadcastTimer.setInterval(BroadcastInterval);
    connect(&broadcastTimer, &QTimer::timeout,
            this, &PeerManager::sendBroadcastDatagram);
}

void PeerManager::setServerPort(int port)
{
    serverPort = port;
}

QString PeerManager::userId() const
{
    return userid;
}

void PeerManager::startBroadcasting()
{
    broadcastTimer.start();
}

bool PeerManager::isLocalHostAddress(const QHostAddress &address) const
{
    for (const QHostAddress &localAddress : ipAddresses) {
        if (address.isEqual(localAddress))
            return true;
    }
    return false;
}

void PeerManager::sendBroadcastDatagram()
{
    QByteArray datagram;
    {
        QCborStreamWriter writer(&datagram);
        writer.startArray(2);
        writer.append(userid);
        writer.append(serverPort);
        writer.endArray();
    }

    bool validBroadcastAddresses = true;
    for (const QHostAddress &address : qAsConst(broadcastAddresses)) {
        if (broadcastSocket.writeDatagram(datagram, address,
                                          broadcastPort) == -1)
            validBroadcastAddresses = false;
    }

    if (!validBroadcastAddresses)
        updateAddresses();
}

void PeerManager::readBroadcastDatagram()
{
    while (broadcastSocket.hasPendingDatagrams()) {
        QHostAddress senderIp;
        quint16 senderPort;
        QByteArray datagram;
        datagram.resize(broadcastSocket.pendingDatagramSize());
        if (broadcastSocket.readDatagram(datagram.data(), datagram.size(),
                                         &senderIp, &senderPort) == -1)
            continue;

        int senderServerPort;
        {
            // decode the datagram
            QCborStreamReader reader(datagram);
            if (reader.lastError() != QCborError::NoError || !reader.isArray())
                continue;
            if (!reader.isLengthKnown() || reader.length() != 2)
                continue;

            reader.enterContainer();
            if (reader.lastError() != QCborError::NoError || !reader.isString())
                continue;
            while (reader.readString().status == QCborStreamReader::Ok) {
                // we don't actually need the username right now
            }

            if (reader.lastError() != QCborError::NoError || !reader.isUnsignedInteger())
                continue;
            senderServerPort = reader.toInteger();
        }

        if (isLocalHostAddress(senderIp) && senderServerPort == serverPort)
            continue;

        if (!client->hasConnection(senderIp)) {
            qDebug() << "A NEW CONNECTION PEER " << senderIp << ": " << senderServerPort;
            Connection *connection = new Connection(this);
            connection->setGreetingMessage(userid);
            emit newConnection(connection);
            connection->connectToHost(senderIp, senderServerPort);
            qDebug() << "A NEW CONNECTION PEER END " << senderIp << ": " << senderServerPort;
        }
    }
}

void PeerManager::updateAddresses()
{
    broadcastAddresses.clear();
    ipAddresses.clear();
    using Qni = QNetworkInterface;
    const auto interfaces = Qni::allInterfaces();
    for (const auto &interface : interfaces) {
        if (!(interface.type() == Qni::Ethernet || interface.type() == Qni::Wifi) ||
              interface.flags() & QNetworkInterface::IsLoopBack ||
              !(interface.flags() & QNetworkInterface::IsRunning)) continue;
        qDebug() << "INTERFACE type " <<  interface.type() << " flags " << interface.flags();
        const auto entries = interface.addressEntries();
        for (const auto &entry : entries) {
            auto broadcastAddress = entry.broadcast();
            if (broadcastAddress != QHostAddress::Null && entry.ip() != QHostAddress::LocalHost) {
                broadcastAddresses << broadcastAddress;
                ipAddresses << entry.ip();
            }
        }
    }
}
