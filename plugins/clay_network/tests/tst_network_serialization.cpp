// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include <QtTest/QtTest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariant>
#include <QVariantMap>
#include <QUuid>
#include "sender.h"
#include "handshake.h"
#include "statebatch.h"

/**
 * @brief Unit tests for ClayNetwork message serialization.
 *
 * Tests the QVariant <-> JSON conversion used for network messages.
 * These tests run without network dependencies and can be used in CI.
 */
class TestNetworkSerialization : public QObject
{
    Q_OBJECT

private slots:
    void testVariantMapToJson();
    void testJsonToVariantMap();
    void testStateMessageRoundTrip();
    void testChatMessageRoundTrip();
    void testNestedObjects();
    void testNumericTypes();
    void testStateSequenceNumber();
    void testStaleStateDetection();
    void testRelayPreservesStatePayload();
    void testStateCarriesSendTime();
    void testRosterSystemMessage();
    void testHostIgnoresClaimedSender();
    void testJoinerTakesRelayedSenderFromHost();
    void testMeshLinkIgnoresClaimedSender();
    void testSenderOutsideRosterIsDropped();
    void testHostAdmitsMatchingHello();
    void testHostRefusesOtherWireVersion();
    void testHostRefusesWrongPassword();
    void testHostRefusesOtherApp();
    void testHostRefusesJoinerWithoutHandshake();
    void testJoinerTakesWelcomeOverItsLink();
    void testJoinerReadsRefusal();
    void testJoinerRefusesHostWithoutHandshake();
    void testKeyedBatchesStayWithinADatagram();
    void testRelayedKeyedBatchStaysWithinADatagram();
    void testOversizedKeyedEntryGoesAlone();
    void testKeyedQueueKeepsNewestPerKey();
    void testKeyedStateIsStaleOnlyBehindItsOwnKey();
    void testKeyedStatsPerSenderAndKey();
};

namespace sb = clay::network::statebatch;

void TestNetworkSerialization::testVariantMapToJson()
{
    // Simulate what broadcast() does
    QVariantMap data;
    data["x"] = 0.5;
    data["y"] = 0.75;

    QJsonObject msg;
    msg["t"] = "s";
    msg["d"] = QJsonObject::fromVariantMap(data);

    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    QVERIFY(json.contains("\"t\":\"s\""));
    QVERIFY(json.contains("\"d\":{"));
    QVERIFY(json.contains("\"x\":0.5"));
    QVERIFY(json.contains("\"y\":0.75"));
}

void TestNetworkSerialization::testJsonToVariantMap()
{
    // Simulate what handleDataChannelMessage() does
    QString json = R"({"t":"s","d":{"x":0.5,"y":0.75}})";

    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    QVERIFY(doc.isObject());

    QJsonObject obj = doc.object();
    QString type = obj["t"].toString();
    QCOMPARE(type, "s");

    QJsonObject dataObj = obj["d"].toObject();
    QVERIFY(!dataObj.isEmpty());
    QCOMPARE(dataObj.keys().size(), 2);

    QVariantMap data = dataObj.toVariantMap();
    QVERIFY(!data.isEmpty());
    QCOMPARE(data["x"].toDouble(), 0.5);
    QCOMPARE(data["y"].toDouble(), 0.75);
}

void TestNetworkSerialization::testStateMessageRoundTrip()
{
    // Full round-trip: QVariantMap -> JSON -> QVariantMap
    QVariantMap original;
    original["x"] = 0.123;
    original["y"] = 0.456;

    // Encode (what sender does)
    QJsonObject msg;
    msg["t"] = "s";
    msg["d"] = QJsonObject::fromVariantMap(original);
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    // Decode (what receiver does)
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    QJsonObject parsed = doc.object();
    QVariantMap decoded = parsed["d"].toObject().toVariantMap();

    // Verify
    QCOMPARE(decoded["x"].toDouble(), original["x"].toDouble());
    QCOMPARE(decoded["y"].toDouble(), original["y"].toDouble());
}

void TestNetworkSerialization::testChatMessageRoundTrip()
{
    // Test with string data (chat messages)
    QVariantMap original;
    original["type"] = "chat";
    original["text"] = "Hello, World!";

    // Encode
    QJsonObject msg;
    msg["t"] = "m";
    msg["d"] = QJsonObject::fromVariantMap(original);
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    // Decode
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    QJsonObject parsed = doc.object();
    QCOMPARE(parsed["t"].toString(), "m");

    QVariantMap decoded = parsed["d"].toObject().toVariantMap();

    // Verify
    QCOMPARE(decoded["type"].toString(), "chat");
    QCOMPARE(decoded["text"].toString(), "Hello, World!");
}

void TestNetworkSerialization::testNestedObjects()
{
    // Test nested data structures
    QVariantMap position;
    position["x"] = 100;
    position["y"] = 200;

    QVariantMap original;
    original["name"] = "player1";
    original["position"] = position;

    // Encode
    QJsonObject msg;
    msg["t"] = "m";
    msg["d"] = QJsonObject::fromVariantMap(original);
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    // Decode
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    QVariantMap decoded = doc.object()["d"].toObject().toVariantMap();

    QCOMPARE(decoded["name"].toString(), "player1");
    QVariantMap decodedPos = decoded["position"].toMap();
    QCOMPARE(decodedPos["x"].toInt(), 100);
    QCOMPARE(decodedPos["y"].toInt(), 200);
}

void TestNetworkSerialization::testNumericTypes()
{
    // Test various numeric types
    QVariantMap original;
    original["intVal"] = 42;
    original["doubleVal"] = 3.14159;
    original["boolVal"] = true;

    // Encode
    QJsonObject msg;
    msg["t"] = "s";
    msg["d"] = QJsonObject::fromVariantMap(original);
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    // Decode
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    QVariantMap decoded = doc.object()["d"].toObject().toVariantMap();

    QCOMPARE(decoded["intVal"].toInt(), 42);
    QCOMPARE(decoded["doubleVal"].toDouble(), 3.14159);
    QCOMPARE(decoded["boolVal"].toBool(), true);
}

void TestNetworkSerialization::testStateSequenceNumber()
{
    // State updates carry a per-sender sequence number "q" (uint32 range)
    QJsonObject msg;
    msg["t"] = "s";
    msg["q"] = static_cast<qint64>(4294967295u);
    msg["d"] = QJsonObject::fromVariantMap({{"x", 1.5}});
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    QJsonObject parsed = QJsonDocument::fromJson(json.toUtf8()).object();
    QVERIFY(parsed.contains("q"));
    QCOMPARE(static_cast<quint32>(parsed["q"].toDouble()), 4294967295u);
}

void TestNetworkSerialization::testStaleStateDetection()
{
    // Receiver logic: anything at or behind the newest accepted seq is stale
    auto isStale = [](quint32 incoming, quint32 newest) {
        return incoming <= newest;
    };
    QVERIFY(isStale(5, 5));
    QVERIFY(isStale(4, 5));
    QVERIFY(!isStale(6, 5));
}

void TestNetworkSerialization::testRelayPreservesStatePayload()
{
    // Host relay adds "from" but must leave seq and payload untouched
    QJsonObject msg;
    msg["t"] = "s";
    msg["q"] = 42;
    msg["d"] = QJsonObject::fromVariantMap({{"x", 7.25}, {"a", -90}});

    QJsonObject relayed = msg;
    relayed["from"] = "node123";
    QString json = QString::fromUtf8(QJsonDocument(relayed).toJson(QJsonDocument::Compact));

    QJsonObject parsed = QJsonDocument::fromJson(json.toUtf8()).object();
    QCOMPARE(parsed["from"].toString(), "node123");
    QCOMPARE(parsed["q"].toInt(), 42);
    QCOMPARE(parsed["t"].toString(), "s");
    QCOMPARE(parsed["d"].toObject()["x"].toDouble(), 7.25);
    QCOMPARE(parsed["d"].toObject()["a"].toInt(), -90);
}

void TestNetworkSerialization::testStateCarriesSendTime()
{
    // State updates carry the sender's clock in "ts" (ms since epoch, a
    // double on the wire) and a relay must pass it through untouched (#290)
    QJsonObject msg;
    msg["t"] = "s";
    msg["q"] = 7;
    msg["ts"] = static_cast<double>(1789000000123LL);
    msg["d"] = QJsonObject::fromVariantMap({{"x", 1.0}});

    QJsonObject relayed = msg;
    relayed["from"] = "origin";
    QString json = QString::fromUtf8(QJsonDocument(relayed).toJson(QJsonDocument::Compact));

    QJsonObject parsed = QJsonDocument::fromJson(json.toUtf8()).object();
    QVERIFY(parsed.contains("ts"));
    QCOMPARE(static_cast<qint64>(parsed["ts"].toDouble()), 1789000000123LL);

    // A sender without "ts" (older build) maps to -1 on the receiver
    QJsonObject legacy;
    legacy["t"] = "s";
    legacy["q"] = 8;
    legacy["d"] = QJsonObject();
    double sentAt = legacy.contains("ts") ? legacy["ts"].toDouble() : -1.0;
    QCOMPARE(sentAt, -1.0);
}

void TestNetworkSerialization::testRosterSystemMessage()
{
    // Star topology roster: {"t":"y","sys":"roster","nodes":[...]}
    QJsonObject msg;
    msg["t"] = "y";
    msg["sys"] = "roster";
    msg["nodes"] = QJsonArray{"nodeA", "nodeB"};
    QString json = QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact));

    QJsonObject parsed = QJsonDocument::fromJson(json.toUtf8()).object();
    QCOMPARE(parsed["t"].toString(), "y");
    QCOMPARE(parsed["sys"].toString(), "roster");
    QJsonArray nodes = parsed["nodes"].toArray();
    QCOMPARE(nodes.size(), 2);
    QCOMPARE(nodes[0].toString(), "nodeA");
    QCOMPARE(nodes[1].toString(), "nodeB");

    // Incremental variants
    QJsonObject joined;
    joined["t"] = "y";
    joined["sys"] = "node_joined";
    joined["nodeId"] = "nodeC";
    QJsonObject reparsed = QJsonDocument::fromJson(
        QJsonDocument(joined).toJson(QJsonDocument::Compact)).object();
    QCOMPARE(reparsed["sys"].toString(), "node_joined");
    QCOMPARE(reparsed["nodeId"].toString(), "nodeC");
}

// Sender attribution (#298): the link vouches for the sender, the "from"
// field only counts when a joiner receives it from the host.
using clay::network::attributeSender;

void TestNetworkSerialization::testHostIgnoresClaimedSender()
{
    const QStringList roster{"nodeB", "nodeC"};
    // nodeC speaks as nodeB to the host: the host knows the link is nodeC's
    QCOMPARE(attributeSender("nodeC", "nodeB", true, "HOST", roster), QString("nodeC"));
    QCOMPARE(attributeSender("nodeC", "", true, "HOST", roster), QString("nodeC"));
}

void TestNetworkSerialization::testJoinerTakesRelayedSenderFromHost()
{
    const QStringList roster{"HOST", "nodeC"};
    QCOMPARE(attributeSender("HOST", "nodeC", false, "HOST", roster), QString("nodeC"));
    // No "from": the host's own message
    QCOMPARE(attributeSender("HOST", "", false, "HOST", roster), QString("HOST"));
    // Before the host is known, nothing can relay
    QCOMPARE(attributeSender("HOST", "nodeC", false, "", roster), QString("HOST"));
}

void TestNetworkSerialization::testMeshLinkIgnoresClaimedSender()
{
    // WASM Mesh: nodeC has its own link to this joiner and claims to be nodeB
    const QStringList roster{"ABC123", "nodeB", "nodeC"};
    QCOMPARE(attributeSender("nodeC", "nodeB", false, "ABC123", roster), QString("nodeC"));
    QCOMPARE(attributeSender("nodeC", "ABC123", false, "ABC123", roster), QString("nodeC"));
}

void TestNetworkSerialization::testSenderOutsideRosterIsDropped()
{
    const QStringList roster{"HOST", "nodeB"};
    // A relayed "from" nobody joined as, or this node's own id
    QVERIFY(attributeSender("HOST", "ghost", false, "HOST", roster).isEmpty());
    QVERIFY(attributeSender("HOST", "self", false, "HOST", roster).isEmpty());
    // A link from a peer that is not (or no longer) in the roster
    QVERIFY(attributeSender("nodeX", "", true, "HOST", roster).isEmpty());
    QVERIFY(attributeSender("nodeX", "nodeB", false, "HOST", roster).isEmpty());
}

namespace hs = clay::network::handshake;

void TestNetworkSerialization::testHostAdmitsMatchingHello()
{
    const QJsonObject hello = hs::hello(hs::kWireVersion, "stone", "secret", "tok-1");
    QCOMPARE(hello["t"].toString(), QString("h"));
    QCOMPARE(hello["tok"].toString(), QString("tok-1"));
    QVERIFY(hs::judgeHello(hello, hs::kWireVersion, "stone", "secret").ok());
    // A host without a password takes any
    QVERIFY(hs::judgeHello(hello, hs::kWireVersion, "stone", "").ok());
    // The hello survives the trip as JSON text, the way it crosses the wire
    const QJsonObject wire = QJsonDocument::fromJson(
        QJsonDocument(hello).toJson(QJsonDocument::Compact)).object();
    QVERIFY(hs::judgeHello(wire, hs::kWireVersion, "stone", "secret").ok());
}

void TestNetworkSerialization::testHostRefusesOtherWireVersion()
{
    const auto v = hs::judgeHello(hs::hello(hs::kWireVersion + 1, "", "", "t"),
                                  hs::kWireVersion, "", "");
    QCOMPARE(v.reason, hs::incompatibleVersion());
    QVERIFY(v.message.startsWith("Incompatible version"));
    // The version is judged first: a wrong password from another build
    // still says why the builds cannot talk
    const auto first = hs::judgeHello(hs::hello(hs::kWireVersion + 1, "", "guess", "t"),
                                      hs::kWireVersion, "", "secret");
    QCOMPARE(first.reason, hs::incompatibleVersion());
}

void TestNetworkSerialization::testHostRefusesWrongPassword()
{
    for (const QString &guess : {QString(), QString("secre"), QString("secret!"),
                                 QString("Secret")}) {
        const auto v = hs::judgeHello(hs::hello(hs::kWireVersion, "", guess, "t"),
                                      hs::kWireVersion, "", "secret");
        QCOMPARE(v.reason, hs::wrongPassword());
        QCOMPARE(v.message, QString("Wrong password"));
        // The refusal does not repeat what was guessed or what is right
        const QJsonObject r = hs::refusal(v);
        QCOMPARE(r["t"].toString(), QString("R"));
        QCOMPARE(r["code"].toString(), hs::wrongPassword());
        QVERIFY(!QJsonDocument(r).toJson().contains("secret"));
    }
    QVERIFY(hs::samePassword("äöü", "äöü"));
    QVERIFY(!hs::samePassword("äöü", "aou"));
}

void TestNetworkSerialization::testHostRefusesOtherApp()
{
    const auto v = hs::judgeHello(hs::hello(hs::kWireVersion, "chiptrack", "", "t"),
                                  hs::kWireVersion, "stone", "");
    QCOMPARE(v.reason, hs::incompatibleApp());
}

void TestNetworkSerialization::testHostRefusesJoinerWithoutHandshake()
{
    // A build from before the handshake speaks first with a ping, a state
    // or a message - or says nothing, which the host's timeout turns into {}
    QJsonObject ping;
    ping["t"] = "p";
    QJsonObject msg;
    msg["t"] = "m";
    for (const QJsonObject &first : {ping, msg, QJsonObject()})
        QCOMPARE(hs::judgeHello(first, hs::kWireVersion, "", "").reason,
                 hs::incompatibleVersion());
}

void TestNetworkSerialization::testJoinerTakesWelcomeOverItsLink()
{
    QVERIFY(hs::judgeReply(hs::welcome("HOST", hs::kWireVersion), "HOST",
                           hs::kWireVersion).ok());
    // A welcome naming somebody else than the host at the other end
    QCOMPARE(hs::judgeReply(hs::welcome("ABC123", hs::kWireVersion), "HOST",
                            hs::kWireVersion).reason, hs::handshakeFailed());
    QCOMPARE(hs::judgeReply(hs::welcome("HOST", hs::kWireVersion + 1), "HOST",
                            hs::kWireVersion).reason, hs::incompatibleVersion());
}

void TestNetworkSerialization::testJoinerReadsRefusal()
{
    const auto v = hs::judgeReply(hs::refusal({hs::wrongPassword(), "Wrong password"}),
                                  "HOST", hs::kWireVersion);
    QCOMPARE(v.reason, hs::wrongPassword());
    QCOMPARE(v.message, QString("Wrong password"));
    // The older rejection without a code, a full network
    QJsonObject full;
    full["t"] = "R";
    full["r"] = "Network full";
    const auto f = hs::judgeReply(full, "HOST", hs::kWireVersion);
    QCOMPARE(f.reason, hs::refused());
    QCOMPARE(f.message, QString("Network full"));
}

void TestNetworkSerialization::testJoinerRefusesHostWithoutHandshake()
{
    // A host from before the handshake greets with its roster
    QJsonObject roster;
    roster["t"] = "y";
    roster["sys"] = "roster";
    const auto v = hs::judgeReply(roster, "HOST", hs::kWireVersion);
    QCOMPARE(v.reason, hs::incompatibleVersion());
    QVERIFY(v.message.startsWith("Incompatible version"));
}

// 100 objects' positions, as one frame of a game would queue them
static QList<sb::Entry> hundredObjects()
{
    QList<sb::Entry> entries;
    for (int i = 0; i < 100; ++i) {
        QVariantMap d;
        d["x"] = 1234.5 + i;
        d["y"] = -87.25 - i;
        d["hp"] = i;
        entries.append({QString("enemy-%1").arg(i), d});
    }
    return entries;
}

void TestNetworkSerialization::testKeyedBatchesStayWithinADatagram()
{
    quint32 seq = 41;
    const auto batches = sb::pack(hundredObjects(), seq, 1.7e12);
    QVERIFY(batches.size() > 1);
    QCOMPARE(seq, quint32(41 + batches.size()));
    QStringList keys;
    quint32 q = 41;
    for (const QByteArray &b : batches) {
        QVERIFY2(b.size() <= sb::kDatagramBytes - sb::kRelayHeadroom,
                 qPrintable(QString::number(b.size())));
        const QJsonObject obj = QJsonDocument::fromJson(b).object();
        QCOMPARE(obj["t"].toString(), QString("b"));
        QCOMPARE(quint32(obj["q"].toDouble()), ++q);
        QCOMPARE(obj["ts"].toDouble(), 1.7e12);
        for (const auto &e : obj["e"].toArray())
            keys.append(e.toObject()["k"].toString());
    }
    // Every object once, in the order queued, and its data intact
    QCOMPARE(keys.size(), 100);
    QCOMPARE(keys.first(), QString("enemy-0"));
    QCOMPARE(keys.last(), QString("enemy-99"));
    const QJsonObject first = QJsonDocument::fromJson(batches.first()).object();
    const QVariantMap d = first["e"].toArray()[0].toObject()["d"].toObject().toVariantMap();
    QCOMPARE(d["x"].toDouble(), 1234.5);
    QCOMPARE(d["hp"].toInt(), 0);
    // Packed, not one datagram per object: 100 entries of ~45 bytes
    QVERIFY2(batches.size() <= 5, qPrintable(QString::number(batches.size())));
}

void TestNetworkSerialization::testRelayedKeyedBatchStaysWithinADatagram()
{
    quint32 seq = 0;
    for (const QByteArray &b : sb::pack(hundredObjects(), seq, 1.7e12)) {
        // What the host's relay sends on: the batch with a PeerJS-length id
        QJsonObject obj = QJsonDocument::fromJson(b).object();
        obj["from"] = QUuid::createUuid().toString(QUuid::WithoutBraces);
        const QByteArray relayed = QJsonDocument(obj).toJson(QJsonDocument::Compact);
        QVERIFY2(relayed.size() <= sb::kDatagramBytes,
                 qPrintable(QString::number(relayed.size())));
    }
}

void TestNetworkSerialization::testOversizedKeyedEntryGoesAlone()
{
    QVariantMap big;
    big["blob"] = QString(3000, 'x');
    QVariantMap small;
    small["x"] = 1;
    quint32 seq = 0;
    const auto batches = sb::pack({{"a", small}, {"big", big}, {"b", small}}, seq, 0);
    QCOMPARE(batches.size(), 3);
    QCOMPARE(QJsonDocument::fromJson(batches[1]).object()["e"].toArray().size(), 1);
    QVERIFY(batches[1].size() > sb::kDatagramBytes);
}

void TestNetworkSerialization::testKeyedQueueKeepsNewestPerKey()
{
    sb::Queue queue;
    QVERIFY(queue.isEmpty());
    queue.put("a", {{"x", 1}});
    queue.put("b", {{"x", 2}});
    queue.put("a", {{"x", 3}});
    const auto entries = queue.take();
    QCOMPARE(entries.size(), 2);
    QCOMPARE(entries[0].first, QString("a"));
    QCOMPARE(entries[0].second["x"].toInt(), 3);
    QCOMPARE(entries[1].first, QString("b"));
    QVERIFY(queue.isEmpty());
}

void TestNetworkSerialization::testKeyedStateIsStaleOnlyBehindItsOwnKey()
{
    // Two batches of one frame overtake each other on the unordered
    // channel: q=8 carries B, q=7 carries A and arrives last
    sb::Tracker in;
    QVERIFY(in.accept("node", "B", 8, 100));
    QVERIFY(in.accept("node", "A", 7, 101));
    // One sequence per sender would have dropped A here (7 <= 8)
    // An older update for B itself is stale, and so is a repeat
    QVERIFY(!in.accept("node", "B", 6, 102));
    QVERIFY(!in.accept("node", "B", 8, 103));
    QVERIFY(in.accept("node", "B", 9, 104));
    // Keys are per sender: another node's A is its own
    QVERIFY(in.accept("other", "A", 1, 105));
    QCOMPARE(in.ageMs("node", "A", 111), 10);
    QCOMPARE(in.ageMs("node", "C", 111), -1);
    QCOMPARE(in.ageMs("nobody", "A", 111), -1);
}

void TestNetworkSerialization::testKeyedStatsPerSenderAndKey()
{
    sb::Tracker in;
    in.batch("node", 900);
    in.accept("node", "A", 1, 100);
    in.accept("node", "B", 1, 100);
    in.batch("node", 1100);
    in.accept("node", "A", 2, 150);
    in.accept("node", "B", 1, 150);

    QVariantMap stats;
    stats["recv"] = 5;  // unkeyed states already counted
    stats["dropped"] = 1;
    in.addStats("node", stats, 200);
    QCOMPARE(stats["recv"].toLongLong(), 5 + 3);
    QCOMPARE(stats["dropped"].toLongLong(), 1 + 1);
    QCOMPARE(stats["batches"].toLongLong(), 2);
    QCOMPARE(stats["maxBatchBytes"].toLongLong(), 1100);
    const QVariantMap keys = stats["keys"].toMap();
    QCOMPARE(keys.size(), 2);
    QCOMPARE(keys["A"].toMap()["seq"].toUInt(), 2u);
    QCOMPARE(keys["A"].toMap()["ageMs"].toLongLong(), 50);
    QCOMPARE(keys["B"].toMap()["recv"].toLongLong(), 1);
    QCOMPARE(keys["B"].toMap()["dropped"].toLongLong(), 1);

    in.forget("node");
    QVERIFY(!in.contains("node"));
    QCOMPARE(in.ageMs("node", "A", 200), -1);
}

QTEST_MAIN(TestNetworkSerialization)
#include "tst_network_serialization.moc"
