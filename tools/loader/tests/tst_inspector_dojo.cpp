// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Integration test: exercises the ClayInspector file-based protocol
// by launching clayliveloader with a test sandbox and communicating
// via .clay/inspect/request.json ↔ response.json

#include <QtTest/QtTest>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QFileInfo>

class TestInspectorDojo : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();

    void testSnapshotRootProperties();
    void testSnapshotFlagInfo();
    void testSnapshotLogTail();
    void testSnapshotEval();
    void testEvalAction();
    void testTreeAction();
    void testTreeDepthLimit();
    void testSnapshotScreenshot();

private:
    bool writeRequest(const QJsonObject& request);
    QJsonObject waitForResponse(int timeoutMs = 5000);

    QProcess* m_loader = nullptr;
    QString m_sandboxDir;
    QString m_inspectDir;
    QString m_loaderBin;
    QString m_lastResponseTs;
};

void TestInspectorDojo::initTestCase()
{
    // Locate the test sandbox relative to the test executable
    // The sandbox QML is deployed next to the test binary
    QString testDir = QCoreApplication::applicationDirPath();
    m_sandboxDir = testDir + "/test_sandbox";
    QDir().mkpath(m_sandboxDir);

    // Copy TestSandbox.qml to the sandbox directory
    QString srcQml = QString(SRCDIR) + "/TestSandbox.qml";
    QString dstQml = m_sandboxDir + "/Sandbox.qml";
    if (QFile::exists(dstQml))
        QFile::remove(dstQml);
    QVERIFY2(QFile::copy(srcQml, dstQml),
             qPrintable("Failed to copy " + srcQml + " to " + dstQml));

    m_inspectDir = m_sandboxDir + "/.clay/inspect";

    // Locate clayliveloader binary
    m_loaderBin = QString(LOADER_BIN);
    QVERIFY2(QFile::exists(m_loaderBin),
             qPrintable("clayliveloader not found at: " + m_loaderBin));

    // Start clayliveloader offscreen
    m_loader = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("QT_QPA_PLATFORM", "offscreen");
    m_loader->setProcessEnvironment(env);
    m_loader->setProcessChannelMode(QProcess::ForwardedChannels);
    m_loader->start(m_loaderBin, {"--sbx", dstQml});
    QVERIFY2(m_loader->waitForStarted(5000),
             "clayliveloader failed to start");

    // Wait for the inspector to create the request.json watch file
    QString reqPath = m_inspectDir + "/request.json";
    bool ready = false;
    for (int i = 0; i < 50; ++i) {
        if (QFile::exists(reqPath)) {
            ready = true;
            break;
        }
        QTest::qWait(200);
    }
    QVERIFY2(ready, "Inspector did not create request.json within 10 seconds");

    // Give the QML scene a moment to fully load
    QTest::qWait(500);
}

void TestInspectorDojo::cleanupTestCase()
{
    if (m_loader) {
        m_loader->terminate();
        if (!m_loader->waitForFinished(3000))
            m_loader->kill();
        delete m_loader;
        m_loader = nullptr;
    }
}

bool TestInspectorDojo::writeRequest(const QJsonObject& request)
{
    QString reqPath = m_inspectDir + "/request.json";
    QFile f(reqPath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    f.write(QJsonDocument(request).toJson());
    f.close();
    return true;
}

QJsonObject TestInspectorDojo::waitForResponse(int timeoutMs)
{
    // Wait for a response with a newer timestamp than the last one we read.
    // This avoids reading stale responses from previous requests.
    QString respPath = m_inspectDir + "/response.json";
    QElapsedTimer timer;
    timer.start();

    while (timer.elapsed() < timeoutMs) {
        if (QFile::exists(respPath)) {
            QFile f(respPath);
            if (f.open(QIODevice::ReadOnly)) {
                auto data = f.readAll();
                f.close();
                if (!data.trimmed().isEmpty()) {
                    auto doc = QJsonDocument::fromJson(data);
                    if (doc.isObject()) {
                        auto obj = doc.object();
                        QString ts = obj["ts"].toString();
                        if (ts != m_lastResponseTs) {
                            m_lastResponseTs = ts;
                            return obj;
                        }
                    }
                }
            }
        }
        QTest::qWait(100);
    }
    return {};
}

// --- Test cases ---

void TestInspectorDojo::testSnapshotRootProperties()
{
    QJsonObject req;
    req["action"] = "snapshot";
    QVERIFY(writeRequest(req));

    auto resp = waitForResponse();
    QVERIFY2(!resp.isEmpty(), "No response received for snapshot");
    QCOMPARE(resp["action"].toString(), "snapshot");
    QVERIFY(resp.contains("ts"));
    QVERIFY(!resp.contains("error"));

    // Verify auto-captured root properties from TestSandbox.qml
    QVERIFY(resp.contains("rootProperties"));
    auto props = resp["rootProperties"].toObject();
    QCOMPARE(props["score"].toInt(), 42);
    QCOMPARE(props["currentLevel"].toString(), "dungeon_3");
    QCOMPARE(props["combatActive"].toBool(), true);
    QVERIFY(qAbs(props["difficulty"].toDouble() - 0.7) < 0.01);

    // Private property should NOT be captured
    QVERIFY(!props.contains("_internalCounter"));
}

void TestInspectorDojo::testSnapshotFlagInfo()
{
    QJsonObject req;
    req["action"] = "snapshot";
    QVERIFY(writeRequest(req));

    auto resp = waitForResponse();
    QVERIFY2(!resp.isEmpty(), "No response received");

    // flagInfo() is defined in TestSandbox.qml
    QVERIFY2(resp.contains("flagInfo"), "flagInfo missing from snapshot");
    auto fi = resp["flagInfo"].toObject();
    QCOMPARE(fi["playerX"].toDouble(), 50.0);
    QCOMPARE(fi["playerY"].toDouble(), 100.0);
    QCOMPARE(fi["enemyCount"].toInt(), 3);
    QCOMPARE(fi["seed"].toInt(), 12345);
}

void TestInspectorDojo::testSnapshotLogTail()
{
    QJsonObject req;
    req["action"] = "snapshot";
    QVERIFY(writeRequest(req));

    auto resp = waitForResponse();
    QVERIFY(!resp.isEmpty());

    // logTail, warnings, errors should be present as arrays
    QVERIFY(resp.contains("logTail"));
    QVERIFY(resp["logTail"].isArray());
    QVERIFY(resp.contains("warnings"));
    QVERIFY(resp["warnings"].isArray());
    QVERIFY(resp.contains("errors"));
    QVERIFY(resp["errors"].isArray());
}

void TestInspectorDojo::testSnapshotEval()
{
    QJsonObject req;
    req["action"] = "snapshot";
    req["eval"] = QJsonArray({"score", "currentLevel", "score * 2"});
    QVERIFY(writeRequest(req));

    auto resp = waitForResponse();
    QVERIFY2(!resp.isEmpty(), "No response received");
    QVERIFY(resp.contains("eval"));

    auto eval = resp["eval"].toObject();
    QCOMPARE(eval["score"].toInt(), 42);
    QCOMPARE(eval["currentLevel"].toString(), "dungeon_3");
    QCOMPARE(eval["score * 2"].toInt(), 84);
}

void TestInspectorDojo::testEvalAction()
{
    QJsonObject req;
    req["action"] = "eval";
    req["eval"] = QJsonArray({"1 + 1", "combatActive", "Math.max(3, 7)"});
    QVERIFY(writeRequest(req));

    auto resp = waitForResponse();
    QVERIFY2(!resp.isEmpty(), "No response received for eval action");
    QCOMPARE(resp["action"].toString(), "eval");
    QVERIFY(!resp.contains("error"));

    auto eval = resp["eval"].toObject();
    QCOMPARE(eval["1 + 1"].toInt(), 2);
    QCOMPARE(eval["combatActive"].toBool(), true);
    QCOMPARE(eval["Math.max(3, 7)"].toInt(), 7);
}

void TestInspectorDojo::testTreeAction()
{
    QJsonObject req;
    req["action"] = "tree";
    QVERIFY(writeRequest(req));

    auto resp = waitForResponse();
    QVERIFY2(!resp.isEmpty(), "No response received for tree action");
    QCOMPARE(resp["action"].toString(), "tree");
    QVERIFY(!resp.contains("error"));

    QVERIFY(resp.contains("tree"));
    auto tree = resp["tree"].toObject();

    // Root is a Rectangle in QML, but file-based components get
    // auto-generated type names like "Sandbox_QMLTYPE_0"
    QVERIFY(!tree["type"].toString().isEmpty());
    // The loader may resize the root to fit its container,
    // so just verify dimensions are positive
    QVERIFY(tree["width"].toDouble() > 0);
    QVERIFY(tree["height"].toDouble() > 0);
    QVERIFY(tree["visible"].toBool());

    // Should have children (player, repeater items, text)
    QVERIFY(tree.contains("children"));
    auto children = tree["children"].toArray();
    QVERIFY(children.size() >= 2); // At least player + hud

    // Find the player item by objectName
    bool foundPlayer = false;
    for (const auto& child : children) {
        auto obj = child.toObject();
        if (obj["objectName"].toString() == "player") {
            foundPlayer = true;
            QCOMPARE(obj["x"].toDouble(), 50.0);
            QCOMPARE(obj["y"].toDouble(), 100.0);
            QCOMPARE(obj["width"].toDouble(), 16.0);
            QCOMPARE(obj["height"].toDouble(), 16.0);
            break;
        }
    }
    QVERIFY2(foundPlayer, "Player item not found in tree");
}

void TestInspectorDojo::testTreeDepthLimit()
{
    QJsonObject req;
    req["action"] = "tree";
    req["maxDepth"] = 0;
    QVERIFY(writeRequest(req));

    auto resp = waitForResponse();
    QVERIFY(!resp.isEmpty());

    auto tree = resp["tree"].toObject();
    // At depth 0, children should not be expanded
    QVERIFY(!tree.contains("children"));
    QVERIFY(tree.contains("childCount"));
    QVERIFY(tree["childCount"].toInt() > 0);
}

void TestInspectorDojo::testSnapshotScreenshot()
{
    QJsonObject req;
    req["action"] = "snapshot";
    req["screenshot"] = true;
    QVERIFY(writeRequest(req));

    auto resp = waitForResponse(8000); // Screenshots can take longer
    QVERIFY2(!resp.isEmpty(), "No response received for screenshot request");

    // In offscreen mode, grabToImage may or may not produce a file
    // depending on the Qt platform plugin capabilities.
    // We verify the protocol handles it gracefully either way.
    if (resp.contains("screenshot")) {
        QString screenshotPath = resp["screenshot"].toString();
        QVERIFY2(QFile::exists(screenshotPath),
                 qPrintable("Screenshot file missing: " + screenshotPath));
        QFileInfo fi(screenshotPath);
        QVERIFY(fi.size() > 0);
    }

    // Even if screenshot didn't work, the rest of the snapshot should be valid
    QVERIFY(resp.contains("rootProperties"));
    QVERIFY(resp.contains("logTail"));
}

QTEST_MAIN(TestInspectorDojo)
#include "tst_inspector_dojo.moc"
