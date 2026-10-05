// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QString>
#include <QStringList>

namespace clay::network {

// The node a received message is attributed to, or an empty string when the
// message must be dropped. Shared by the native and the WASM backend.
//
// linkPeer is the node at the other end of the connection the message came
// over - the transport vouches for it. claimedFrom is the "from" field the
// message itself carries, which any peer can write. Only the host relays for
// others, so a "from" counts only when a joiner receives it over its link to
// the host; on every other link (the host's own, a Mesh link) it is ignored
// and the message belongs to linkPeer. Whoever it lands on must be in the
// receiver's roster, or a relay could make up a node nobody joined (#298).
inline QString attributeSender(const QString &linkPeer, const QString &claimedFrom,
                               bool isHost, const QString &hostId,
                               const QStringList &roster)
{
    QString sender = linkPeer;
    if (!isHost && !hostId.isEmpty() && linkPeer == hostId && !claimedFrom.isEmpty())
        sender = claimedFrom;
    return roster.contains(sender) ? sender : QString();
}

} // namespace clay::network
