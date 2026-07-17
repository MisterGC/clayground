// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include <QtTest/QtTest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariant>
#include <QVariantMap>

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
    void testRosterSystemMessage();
};

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

QTEST_MAIN(TestNetworkSerialization)
#include "tst_network_serialization.moc"
