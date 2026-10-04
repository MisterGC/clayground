// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <functional>
#include <utility>
#include <QHash>
#include <QJsonObject>
#include <QJsonValue>
#include <QList>
#include <QString>
#include <QVariant>
#include <QVariantMap>
#include "statebatch.h"

// Replicated objects (#306), shared by the native and the WASM backend.
//
// Every node keeps the same table of objects: per object its id, type,
// spawn properties, owner, what happens to it when its owner leaves, and
// its last state. The table is changed by operations, reliable messages:
//
//   {"t":"o","op":"spawn","id":..,"type":..,"owner":..,"props":{..},
//    "leave":"despawn"|"host"[,"st":{..},"sq":<seq>,"sa":<sent at>]}
//   {"t":"o","op":"despawn","id":..}
//   {"t":"o","op":"owner","id":..,"owner":..}
//   {"t":"o","op":"state","id":..,"q":<seq>,"ts":<sent at>,"d":{..}[,"by":..]}
//   {"t":"o","op":"session","p":{name: value, ..}}
//
// The host orders them: a joiner sends its operation to the host, the host
// checks it, applies it and sends it on to every node - as its own, so a
// joiner takes an operation only from the host and only over its link to
// the host (the review of #354: whatever the owner check trusts came over a
// link that passed the handshake). A joiner applies its own spawn at once,
// so the owner can send state in the same frame; a spawn the host drops
// comes back to it as a despawn.
//
// Ids are made here and never reused: "<spawner node id>:<n>". A state that
// arrives after its object's despawn finds no object and is dropped before
// the sequence check, so it cannot undo the despawn nor make a sequence
// entry again - the despawn freed that entry (the review of #355).
//
// An object's state goes with the owner's keyed states, as {"o":id,...}
// entries (statebatch.h), sequenced per owner and object. A resting
// object's last state comes once more as a "state" operation, reliably,
// with a newer seq than any lossy update before it.
//
// A node that joins late gets one spawn operation per live object, with its
// owner, policy and last state, and then the session properties, right
// after its welcome; every operation after that arrives after them.
namespace clay::network::replica {

// What happens to an object whose owner leaves
enum class OwnerLeft { Despawn, Host };

inline OwnerLeft ownerLeftFrom(const QString &name)
{
    return name == QLatin1String("host") ? OwnerLeft::Host : OwnerLeft::Despawn;
}

inline QString ownerLeftName(OwnerLeft policy)
{
    return policy == OwnerLeft::Host ? QStringLiteral("host") : QStringLiteral("despawn");
}

struct Object {
    QString id;
    QString type;
    QString owner;
    QVariantMap props;
    OwnerLeft onOwnerLeft = OwnerLeft::Despawn;
    // The newest state of the object, its seq and the session time it was
    // sent at; what a late joiner starts from
    bool hasState = false;
    QVariantMap state;
    quint32 stateSeq = 0;
    double stateAt = -1;

    QVariantMap toMap() const
    {
        QVariantMap m;
        m["id"] = id;
        m["type"] = type;
        m["owner"] = owner;
        m["props"] = props;
        m["onOwnerLeft"] = ownerLeftName(onOwnerLeft);
        if (hasState)
            m["state"] = state;
        return m;
    }
};

// What the table does to the world around it. The backend fills it in;
// a missing function does nothing.
struct Io {
    // Reliable, to one node
    std::function<void(const QString &nodeId, const QJsonObject &op)> sendTo;
    // Reliable, to every node but except
    std::function<void(const QJsonObject &op, const QString &except)> broadcast;
    // True for a node in the roster
    std::function<bool(const QString &nodeId)> isNode;
    std::function<void(const QString &detail)> diag;
    std::function<void(const Object &object)> spawned;
    std::function<void(const Object &object)> despawned;
    std::function<void(const QString &id, const QString &owner)> ownerChanged;
    std::function<void(const QString &id, const QVariantMap &data, double sentAt)> state;
    std::function<void(const QString &name, const QVariant &value)> sessionProperty;
};

inline QJsonObject spawnOp(const Object &o, bool withState)
{
    QJsonObject op;
    op["t"] = "o";
    op["op"] = "spawn";
    op["id"] = o.id;
    op["type"] = o.type;
    op["owner"] = o.owner;
    op["props"] = QJsonObject::fromVariantMap(o.props);
    op["leave"] = ownerLeftName(o.onOwnerLeft);
    if (withState && o.hasState) {
        op["st"] = QJsonObject::fromVariantMap(o.state);
        op["sq"] = qint64(o.stateSeq);
        op["sa"] = o.stateAt;
    }
    return op;
}

inline QJsonObject despawnOp(const QString &id)
{
    QJsonObject op;
    op["t"] = "o";
    op["op"] = "despawn";
    op["id"] = id;
    return op;
}

inline QJsonObject ownerOp(const QString &id, const QString &owner)
{
    QJsonObject op;
    op["t"] = "o";
    op["op"] = "owner";
    op["id"] = id;
    op["owner"] = owner;
    return op;
}

inline QJsonObject stateOp(const QString &id, const QVariantMap &data, quint32 seq,
                           double sentAt, const QString &by = QString())
{
    QJsonObject op;
    op["t"] = "o";
    op["op"] = "state";
    op["id"] = id;
    op["q"] = qint64(seq);
    op["ts"] = sentAt;
    op["d"] = QJsonObject::fromVariantMap(data);
    if (!by.isEmpty())
        op["by"] = by;
    return op;
}

inline QJsonObject sessionOp(const QVariantMap &properties)
{
    QJsonObject op;
    op["t"] = "o";
    op["op"] = "session";
    op["p"] = QJsonObject::fromVariantMap(properties);
    return op;
}

class Table
{
public:
    explicit Table(Io io = {}) : io_(std::move(io)) {}

    void setIo(Io io) { io_ = std::move(io); }

    // This node is in a network now: nodeId is its own id, hostId the host's
    void start(const QString &nodeId, const QString &hostId, bool isHost)
    {
        me_ = nodeId;
        host_ = hostId;
        isHost_ = isHost;
        counter_ = 0;
    }
    bool active() const { return !me_.isEmpty(); }

    // The network is gone: every object despawns here, last of all
    void reset()
    {
        const auto gone = std::exchange(objects_, {});
        session_.clear();
        tracker_.clear();
        me_.clear();
        host_.clear();
        isHost_ = false;
        for (const Object &o : gone)
            if (io_.despawned)
                io_.despawned(o);
    }

    // ---- This node's operations ----

    // A new object of type with props; owner empty means this node. Only
    // the host spawns for another node. The id, or empty when refused.
    QString spawn(const QString &type, const QVariantMap &props, const QString &owner,
                  OwnerLeft onOwnerLeft)
    {
        if (!active() || type.isEmpty())
            return {};
        const QString who = owner.isEmpty() ? me_ : owner;
        if (who != me_ && !(isHost_ && isNode(who))) {
            diag(QString("Spawn of a %1 for %2 refused: only the host spawns for another node")
                     .arg(type, who.left(8)));
            return {};
        }
        Object o;
        o.id = me_ + ':' + QString::number(++counter_);
        o.type = type;
        o.owner = who;
        o.props = props;
        o.onOwnerLeft = onOwnerLeft;
        objects_.insert(o.id, o);
        if (io_.spawned)
            io_.spawned(o);
        if (isHost_)
            broadcast(spawnOp(o, false));
        else if (io_.sendTo)
            io_.sendTo(host_, spawnOp(o, false));
        return o.id;
    }

    // The owner or the host despawns. On a joiner it takes effect when the
    // host sends it back.
    bool despawn(const QString &id)
    {
        auto it = objects_.constFind(id);
        if (!active() || it == objects_.constEnd())
            return false;
        if (isHost_) {
            remove(id);
            broadcast(despawnOp(id));
            return true;
        }
        if (it->owner != me_)
            return false;
        if (io_.sendTo)
            io_.sendTo(host_, despawnOp(id));
        return true;
    }

    // The owner or the host hands the object to owner. On a joiner it
    // takes effect when the host sends it back.
    bool setOwner(const QString &id, const QString &owner)
    {
        auto it = objects_.constFind(id);
        if (!active() || it == objects_.constEnd() || owner == it->owner)
            return false;
        if (owner != host_ && owner != me_ && !isNode(owner))
            return false;
        if (isHost_) {
            changeOwner(id, owner);
            broadcast(ownerOp(id, owner));
            return true;
        }
        if (it->owner != me_)
            return false;
        if (io_.sendTo)
            io_.sendTo(host_, ownerOp(id, owner));
        return true;
    }

    // Host only: a session property, for every node and every late joiner
    bool setSessionProperty(const QString &name, const QVariant &value)
    {
        if (!active() || !isHost_ || name.isEmpty())
            return false;
        // As JSON carries it, so the host holds what every joiner gets
        const QVariant sent = QJsonValue::fromVariant(value).toVariant();
        session_[name] = sent;
        if (io_.sessionProperty)
            io_.sessionProperty(name, sent);
        QVariantMap p;
        p[name] = sent;
        broadcast(sessionOp(p));
        return true;
    }

    // This node is about to send the state of id with seq: true when it
    // may - it owns the object - and then the state is its last
    bool sending(const QString &id, const QVariantMap &data, quint32 seq, double sentAt)
    {
        auto it = objects_.find(id);
        if (!active() || it == objects_.end() || it->owner != me_)
            return false;
        keep(*it, data, seq, sentAt);
        return true;
    }

    // ---- What arrives ----

    // An operation over the link to linkPeer
    void receiveOp(const QString &linkPeer, const QJsonObject &op)
    {
        if (!active())
            return;
        if (isHost_)
            hostReceives(linkPeer, op);
        else if (linkPeer == host_ && !op.contains("from"))
            joinerReceives(op);
        else
            diag(QString("Dropped an object operation over %1: only the host's count")
                     .arg(linkPeer.left(8)));
    }

    // A batch entry for object id from sender, over the link to linkPeer.
    // True when it is taken: the object lives, sender owns it, and it is
    // newer than every state taken before.
    bool receiveState(const QString &linkPeer, const QString &sender, const QString &id,
                      quint32 seq, const QVariantMap &data, double sentAt, qint64 nowMs)
    {
        if (!active() || sender == me_ || (!isHost_ && linkPeer != host_))
            return false;
        auto it = objects_.find(id);
        if (it == objects_.end() || it->owner != sender)
            return false;
        if (!tracker_.accept(sender, id, seq, nowMs))
            return false;
        keep(*it, data, seq, sentAt);
        if (io_.state)
            io_.state(id, data, sentAt);
        return true;
    }

    // Host: a joiner was admitted - it gets every live object and the
    // session properties
    void admitted(const QString &nodeId)
    {
        if (!active() || !isHost_ || !io_.sendTo)
            return;
        for (const Object &o : std::as_const(objects_))
            io_.sendTo(nodeId, spawnOp(o, true));
        if (!session_.isEmpty())
            io_.sendTo(nodeId, sessionOp(session_));
    }

    // A node left. Its sequence entries go; on the host each object it
    // owned despawns or passes to the host, as the object declared.
    void nodeLeft(const QString &nodeId)
    {
        tracker_.forget(nodeId);
        if (!active() || !isHost_)
            return;
        QStringList orphans;
        for (const Object &o : std::as_const(objects_))
            if (o.owner == nodeId)
                orphans.append(o.id);
        for (const QString &id : std::as_const(orphans)) {
            if (objects_[id].onOwnerLeft == OwnerLeft::Host) {
                changeOwner(id, me_);
                broadcast(ownerOp(id, me_));
            } else {
                remove(id);
                broadcast(despawnOp(id));
            }
        }
    }

    // ---- Reading ----

    const Object *find(const QString &id) const
    {
        auto it = objects_.constFind(id);
        return it == objects_.constEnd() ? nullptr : &*it;
    }
    QList<Object> objects() const { return objects_.values(); }
    int size() const { return int(objects_.size()); }
    QVariantMap sessionProperties() const { return session_; }
    // Sequence entries kept for object states, every sender's together
    int trackedKeys() const { return tracker_.keyCount(); }

private:
    void hostReceives(const QString &from, const QJsonObject &op)
    {
        if (!isNode(from))
            return;
        const QString kind = op["op"].toString();
        const QString id = op["id"].toString();
        auto it = objects_.constFind(id);
        if (kind == QLatin1String("spawn")) {
            const QString owner = op["owner"].toString();
            const QString type = op["type"].toString();
            if (it != objects_.constEnd())
                return;  // an id lives once; its spawner keeps it
            if (!id.startsWith(from + ':') || owner != from || type.isEmpty()) {
                diag(QString("Dropped a spawn from %1: %2 is not its own").arg(from.left(8), id));
                // Its spawner applied it at once; it must not linger there
                if (io_.sendTo)
                    io_.sendTo(from, despawnOp(id));
                return;
            }
            Object o;
            o.id = id;
            o.type = type;
            o.owner = owner;
            o.props = op["props"].toObject().toVariantMap();
            o.onOwnerLeft = ownerLeftFrom(op["leave"].toString());
            objects_.insert(id, o);
            if (io_.spawned)
                io_.spawned(o);
            broadcast(spawnOp(o, false), from);
            return;
        }
        if (it == objects_.constEnd()) {
            diag(QString("Dropped a %1 from %2 for %3, no such object")
                     .arg(kind, from.left(8), id));
            return;
        }
        if (it->owner != from) {
            diag(QString("Dropped a %1 from %2 for %3: it is %4's")
                     .arg(kind, from.left(8), id, it->owner.left(8)));
            return;
        }
        if (kind == QLatin1String("despawn")) {
            remove(id);
            broadcast(despawnOp(id));
        } else if (kind == QLatin1String("owner")) {
            const QString owner = op["owner"].toString();
            if (owner == from || (owner != me_ && !isNode(owner)))
                return;
            changeOwner(id, owner);
            broadcast(ownerOp(id, owner));
        } else if (kind == QLatin1String("state")) {
            const auto seq = quint32(op["q"].toDouble());
            const QVariantMap data = op["d"].toObject().toVariantMap();
            const double sentAt = op["ts"].toDouble(-1);
            if (!tracker_.accept(from, id, seq, 0))
                return;
            keep(objects_[id], data, seq, sentAt);
            if (io_.state)
                io_.state(id, data, sentAt);
            broadcast(stateOp(id, data, seq, sentAt, from), from);
        }
    }

    void joinerReceives(const QJsonObject &op)
    {
        const QString kind = op["op"].toString();
        const QString id = op["id"].toString();
        if (kind == QLatin1String("session")) {
            const QVariantMap p = op["p"].toObject().toVariantMap();
            for (auto it = p.constBegin(); it != p.constEnd(); ++it) {
                session_[it.key()] = it.value();
                if (io_.sessionProperty)
                    io_.sessionProperty(it.key(), it.value());
            }
            return;
        }
        auto it = objects_.find(id);
        if (kind == QLatin1String("spawn")) {
            if (it != objects_.end())
                return;  // this node's own, applied when it spawned it
            Object o;
            o.id = id;
            o.type = op["type"].toString();
            o.owner = op["owner"].toString();
            o.props = op["props"].toObject().toVariantMap();
            o.onOwnerLeft = ownerLeftFrom(op["leave"].toString());
            if (op.contains("st")) {
                // The newest state the host has; an older lossy one still
                // under way must not overwrite it
                o.hasState = true;
                o.state = op["st"].toObject().toVariantMap();
                o.stateSeq = quint32(op["sq"].toDouble());
                o.stateAt = op["sa"].toDouble(-1);
                // 0: the state came from an owner before this one
                if (o.owner != me_ && o.stateSeq > 0)
                    tracker_.accept(o.owner, id, o.stateSeq, 0);
            }
            objects_.insert(id, o);
            if (io_.spawned)
                io_.spawned(o);
            return;
        }
        if (it == objects_.end())
            return;
        if (kind == QLatin1String("despawn")) {
            remove(id);
        } else if (kind == QLatin1String("owner")) {
            changeOwner(id, op["owner"].toString());
        } else if (kind == QLatin1String("state")) {
            if (op["by"].toString() != it->owner)
                return;
            const auto seq = quint32(op["q"].toDouble());
            if (!tracker_.accept(it->owner, id, seq, 0))
                return;
            const QVariantMap data = op["d"].toObject().toVariantMap();
            const double sentAt = op["ts"].toDouble(-1);
            keep(*it, data, seq, sentAt);
            if (io_.state)
                io_.state(id, data, sentAt);
        }
    }

    void keep(Object &o, const QVariantMap &data, quint32 seq, double sentAt)
    {
        o.hasState = true;
        o.state = data;
        o.stateSeq = seq;
        o.stateAt = sentAt;
    }

    void remove(const QString &id)
    {
        const Object o = objects_.take(id);
        tracker_.forgetKey(o.owner, id);
        if (io_.despawned)
            io_.despawned(o);
    }

    void changeOwner(const QString &id, const QString &owner)
    {
        Object &o = objects_[id];
        // The new owner counts on its own sequence: the last state stays,
        // its seq does not - a late joiner would take it as the new
        // owner's and drop its states until they pass the old owner's
        tracker_.forgetKey(o.owner, id);
        o.stateSeq = 0;
        o.owner = owner;
        if (io_.ownerChanged)
            io_.ownerChanged(id, owner);
    }

    void broadcast(const QJsonObject &op, const QString &except = QString())
    {
        if (io_.broadcast)
            io_.broadcast(op, except);
    }
    bool isNode(const QString &nodeId) const { return io_.isNode && io_.isNode(nodeId); }
    void diag(const QString &detail) const
    {
        if (io_.diag)
            io_.diag(detail);
    }

    Io io_;
    QString me_;
    QString host_;
    bool isHost_ = false;
    quint64 counter_ = 0;
    QHash<QString, Object> objects_;
    QVariantMap session_;
    // Per owner and object: the newest accepted seq
    statebatch::Tracker tracker_;
};

} // namespace clay::network::replica
