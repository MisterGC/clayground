// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <algorithm>
#include <utility>
#include <QByteArray>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QList>
#include <QPair>
#include <QString>
#include <QVariantMap>

// Keyed state (#302), shared by the native and the WASM backend.
//
// broadcastState(data) carries one sequence number per sender, so a node
// that sends one update per object would see a late update for A dropped
// behind B's. A keyed state is sequenced per sender AND key instead: only a
// newer update for the same key makes one stale. The keyed states a node
// sends between two flushes go out as batches, each one datagram:
//
//   {"t":"b","q":<seq>,"ts":<session ms>,"e":[{"k":<key>,"d":{...}}, ...]}
//
// "ts" is the session time (#304) the batch was sent at, in whole ms. An
// entry of a replicated object (#306) names it with "o" instead of "k":
// {"o":<object id>,"d":{...}} - a receiver takes it only from the object's
// owner (replica.h), and keys and object ids never meet.
//
// Every entry of a batch takes the batch's q; a key is in a batch at most
// once (a later update for it in the same frame replaces the earlier), and
// q grows from batch to batch, so per key it grows too. The host relays a
// batch as it is, with "from" added.
namespace clay::network::statebatch {

// A batch stays at about this many bytes - one datagram that fits a
// typical path MTU without IP fragmentation
constexpr int kDatagramBytes = 1200;
// Room left for the "from" the host's relay adds, so a relayed batch stays
// within kDatagramBytes too
constexpr int kRelayHeadroom = 64;
// The widest "q" and "ts" a batch header can have, for its size estimate
constexpr int kHeaderBytes = int(sizeof("{\"t\":\"b\",\"q\":4294967295,\"ts\":9999999999999,\"e\":[]}")) - 1;

using Entry = QPair<QString, QVariantMap>;

// The keyed entries, then the object entries (#306), packed into batches
// of at most `budget` bytes, in order. A single entry too large for a batch
// of its own still goes, alone. Each batch takes the next ++seq; when
// objectSeqs is given, it gets the seq each object entry went out with.
inline QList<QByteArray> pack(const QList<Entry> &entries, const QList<Entry> &objects,
                              quint32 &seq, double sentAtMs,
                              int budget = kDatagramBytes - kRelayHeadroom,
                              QList<quint32> *objectSeqs = nullptr)
{
    QList<QByteArray> batches;
    QList<QByteArray> body;
    int size = kHeaderBytes;
    auto close = [&]() {
        if (body.isEmpty())
            return;
        QByteArray out = "{\"t\":\"b\",\"q\":" + QByteArray::number(++seq)
                         + ",\"ts\":" + QByteArray::number(sentAtMs, 'f', 0)
                         + ",\"e\":[" + body.join(',') + "]}";
        batches.append(out);
        body.clear();
        size = kHeaderBytes;
    };
    auto add = [&](const Entry &e, const char *field) {
        QJsonObject o;
        o[QLatin1String(field)] = e.first;
        o["d"] = QJsonObject::fromVariantMap(e.second);
        const QByteArray json = QJsonDocument(o).toJson(QJsonDocument::Compact);
        if (!body.isEmpty() && size + 1 + json.size() > budget)
            close();
        size += json.size() + (body.isEmpty() ? 0 : 1);
        body.append(json);
    };
    for (const auto &e : entries)
        add(e, "k");
    for (const auto &e : objects) {
        add(e, "o");
        if (objectSeqs)
            objectSeqs->append(seq + 1);  // the batch it is in closes with ++seq
    }
    close();
    return batches;
}

inline QList<QByteArray> pack(const QList<Entry> &entries, quint32 &seq, double sentAtMs,
                              int budget = kDatagramBytes - kRelayHeadroom)
{
    return pack(entries, {}, seq, sentAtMs, budget);
}

// Keyed states queued in a frame: one entry per key, the newest data, in
// the order the keys were first queued
class Queue
{
public:
    void put(const QString &key, const QVariantMap &data)
    {
        auto it = index_.constFind(key);
        if (it != index_.constEnd()) {
            entries_[*it].second = data;
            return;
        }
        index_.insert(key, entries_.size());
        entries_.append({key, data});
    }
    bool isEmpty() const { return entries_.isEmpty(); }
    QList<Entry> take()
    {
        index_.clear();
        return std::exchange(entries_, {});
    }
    void clear() { entries_.clear(); index_.clear(); }

private:
    QList<Entry> entries_;
    QHash<QString, int> index_;
};

// What a receiver knows of the keyed states of every sender, by ORIGIN node
// id: per key the newest accepted seq, when it came, how many were taken
// and how many dropped as stale
class Tracker
{
public:
    struct Key {
        quint32 seq = 0;
        qint64 lastMs = 0;
        qint64 recv = 0;
        qint64 dropped = 0;
    };
    struct Sender {
        QHash<QString, Key> keys;
        qint64 batches = 0;
        qint64 maxBatchBytes = 0;
    };

    // A batch of `bytes` from sender arrived
    void batch(const QString &sender, qint64 bytes)
    {
        Sender &s = senders_[sender];
        s.batches++;
        s.maxBatchBytes = std::max(s.maxBatchBytes, bytes);
    }

    // True when the entry for key is newer than any accepted before
    bool accept(const QString &sender, const QString &key, quint32 seq, qint64 nowMs)
    {
        Sender &s = senders_[sender];
        auto it = s.keys.find(key);
        if (it != s.keys.end() && seq <= it->seq) {
            it->dropped++;
            return false;
        }
        Key &k = s.keys[key];
        k.seq = seq;
        k.lastMs = nowMs;
        k.recv++;
        return true;
    }

    // ms since the newest accepted state of sender's key, -1 if none
    int ageMs(const QString &sender, const QString &key, qint64 nowMs) const
    {
        auto s = senders_.constFind(sender);
        if (s == senders_.constEnd())
            return -1;
        auto k = s->keys.constFind(key);
        return k == s->keys.constEnd() ? -1 : int(nowMs - k->lastMs);
    }

    bool contains(const QString &sender) const { return senders_.contains(sender); }
    void forget(const QString &sender) { senders_.remove(sender); }
    // Drops one key of sender - a despawned object's (#306), so a session
    // that spawns and despawns all the time does not grow the table
    void forgetKey(const QString &sender, const QString &key)
    {
        auto s = senders_.find(sender);
        if (s != senders_.end())
            s->keys.remove(key);
    }
    // The newest accepted seq of sender's key, 0 if none
    quint32 seq(const QString &sender, const QString &key) const
    {
        auto s = senders_.constFind(sender);
        if (s == senders_.constEnd())
            return 0;
        auto k = s->keys.constFind(key);
        return k == s->keys.constEnd() ? 0 : k->seq;
    }
    // Every sender's keys, counted together
    int keyCount() const
    {
        int n = 0;
        for (const auto &s : senders_)
            n += s.keys.size();
        return n;
    }
    void clear() { senders_.clear(); }

    // Adds sender's keyed figures to its syncStats entry: recv and dropped
    // grow by its keyed entries, and keys, batches, maxBatchBytes appear
    void addStats(const QString &sender, QVariantMap &stats, qint64 nowMs) const
    {
        auto s = senders_.constFind(sender);
        if (s == senders_.constEnd())
            return;
        QVariantMap keys;
        qint64 recv = 0, dropped = 0;
        for (auto k = s->keys.constBegin(); k != s->keys.constEnd(); ++k) {
            QVariantMap ks;
            ks["seq"] = k->seq;
            ks["recv"] = k->recv;
            ks["dropped"] = k->dropped;
            ks["ageMs"] = nowMs - k->lastMs;
            keys[k.key()] = ks;
            recv += k->recv;
            dropped += k->dropped;
        }
        stats["recv"] = stats.value("recv").toLongLong() + recv;
        stats["dropped"] = stats.value("dropped").toLongLong() + dropped;
        stats["keys"] = keys;
        stats["batches"] = s->batches;
        stats["maxBatchBytes"] = s->maxBatchBytes;
    }

private:
    QHash<QString, Sender> senders_;
};

} // namespace clay::network::statebatch
