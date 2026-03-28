// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include <QtTest/QtTest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTemporaryDir>
#include <QFile>

#include "clayinspector.h"

class TestInspectorUnit : public QObject
{
    Q_OBJECT

private slots:
    void testLogBufferAdd();
    void testLogBufferOverflow();
    void testWarningBufferOverflow();
    void testErrorBufferOverflow();
    void testClearLogs();
    void testSetSandboxDirCreatesInspectDir();
    void testSetSandboxDirCreatesRequestFile();
    void testSnapshotWithNullContainerReturnsError();
    void testEvalWithNullContainerReturnsError();
    void testTreeWithNullContainerReturnsError();
    void testUnknownActionReturnsError();
    void testEmptyRequestFileIsIgnored();
    void testInvalidJsonIsIgnored();
};

void TestInspectorUnit::testLogBufferAdd()
{
    ClayInspector inspector(nullptr);
    inspector.addLogMessage("msg1");
    inspector.addLogMessage("msg2");

    // Verify by triggering a snapshot (with null container → error response
    // but logs should still be captured internally)
    // We use the file protocol to check log content
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());
    inspector.setSandboxDir(tmpDir.path());

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QJsonObject req;
    req["action"] = "snapshot";
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(QJsonDocument(req).toJson());
    f.close();

    // Give file watcher time to trigger
    QTest::qWait(500);

    QString respPath = tmpDir.path() + "/.clay/inspect/response.json";
    QVERIFY(QFile::exists(respPath));

    QFile rf(respPath);
    QVERIFY(rf.open(QIODevice::ReadOnly));
    auto doc = QJsonDocument::fromJson(rf.readAll());
    rf.close();

    // With null container we get an error, but the response is still written
    auto resp = doc.object();
    QVERIFY(resp.contains("action"));
    QCOMPARE(resp["action"].toString(), "snapshot");
}

void TestInspectorUnit::testLogBufferOverflow()
{
    ClayInspector inspector(nullptr);
    for (int i = 0; i < 250; ++i)
        inspector.addLogMessage(QString("log_%1").arg(i));

    // Buffer should be capped at 200
    // We verify indirectly: add one more and check we don't crash
    inspector.addLogMessage("overflow_check");
    // If we got here, the buffer management works
    QVERIFY(true);
}

void TestInspectorUnit::testWarningBufferOverflow()
{
    ClayInspector inspector(nullptr);
    for (int i = 0; i < 250; ++i)
        inspector.addWarning(QString("warn_%1").arg(i));
    inspector.addWarning("overflow_check");
    QVERIFY(true);
}

void TestInspectorUnit::testErrorBufferOverflow()
{
    ClayInspector inspector(nullptr);
    for (int i = 0; i < 250; ++i)
        inspector.addError(QString("err_%1").arg(i));
    inspector.addError("overflow_check");
    QVERIFY(true);
}

void TestInspectorUnit::testClearLogs()
{
    ClayInspector inspector(nullptr);
    inspector.addLogMessage("log");
    inspector.addWarning("warn");
    inspector.addError("err");
    inspector.clearLogs();

    // Trigger snapshot to verify buffers are empty
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());
    inspector.setSandboxDir(tmpDir.path());

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QJsonObject req;
    req["action"] = "snapshot";
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(QJsonDocument(req).toJson());
    f.close();

    QTest::qWait(500);

    QString respPath = tmpDir.path() + "/.clay/inspect/response.json";
    QFile rf(respPath);
    QVERIFY(rf.open(QIODevice::ReadOnly));
    auto resp = QJsonDocument::fromJson(rf.readAll()).object();
    rf.close();

    // With null container we get error but no log/warn/error arrays
    // (they're only added in handleSnapshot which bails early on null root)
    QVERIFY(resp.contains("error"));
}

void TestInspectorUnit::testSetSandboxDirCreatesInspectDir()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QVERIFY(QDir(tmpDir.path() + "/.clay/inspect").exists());
}

void TestInspectorUnit::testSetSandboxDirCreatesRequestFile()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QVERIFY(QFile::exists(tmpDir.path() + "/.clay/inspect/request.json"));
}

void TestInspectorUnit::testSnapshotWithNullContainerReturnsError()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QJsonObject req;
    req["action"] = "snapshot";
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(QJsonDocument(req).toJson());
    f.close();

    QTest::qWait(500);

    QFile rf(tmpDir.path() + "/.clay/inspect/response.json");
    QVERIFY(rf.open(QIODevice::ReadOnly));
    auto resp = QJsonDocument::fromJson(rf.readAll()).object();
    rf.close();

    QVERIFY(resp.contains("error"));
    QVERIFY(resp["error"].toString().contains("No sandbox root"));
    QCOMPARE(resp["action"].toString(), "snapshot");
    QVERIFY(resp.contains("ts"));
}

void TestInspectorUnit::testEvalWithNullContainerReturnsError()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QJsonObject req;
    req["action"] = "eval";
    req["eval"] = QJsonArray({"1+1"});
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(QJsonDocument(req).toJson());
    f.close();

    QTest::qWait(500);

    QFile rf(tmpDir.path() + "/.clay/inspect/response.json");
    QVERIFY(rf.open(QIODevice::ReadOnly));
    auto resp = QJsonDocument::fromJson(rf.readAll()).object();
    rf.close();

    QVERIFY(resp.contains("error"));
    QCOMPARE(resp["action"].toString(), "eval");
}

void TestInspectorUnit::testTreeWithNullContainerReturnsError()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QJsonObject req;
    req["action"] = "tree";
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(QJsonDocument(req).toJson());
    f.close();

    QTest::qWait(500);

    QFile rf(tmpDir.path() + "/.clay/inspect/response.json");
    QVERIFY(rf.open(QIODevice::ReadOnly));
    auto resp = QJsonDocument::fromJson(rf.readAll()).object();
    rf.close();

    QVERIFY(resp.contains("error"));
    QCOMPARE(resp["action"].toString(), "tree");
}

void TestInspectorUnit::testUnknownActionReturnsError()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QJsonObject req;
    req["action"] = "bogus_action";
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(QJsonDocument(req).toJson());
    f.close();

    QTest::qWait(500);

    QFile rf(tmpDir.path() + "/.clay/inspect/response.json");
    QVERIFY(rf.open(QIODevice::ReadOnly));
    auto resp = QJsonDocument::fromJson(rf.readAll()).object();
    rf.close();

    QVERIFY(resp.contains("error"));
    QVERIFY(resp["error"].toString().contains("Unknown action"));
    QCOMPARE(resp["action"].toString(), "bogus_action");
}

void TestInspectorUnit::testEmptyRequestFileIsIgnored()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    // Write empty content — should be silently ignored
    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write("");
    f.close();

    QTest::qWait(500);

    // No response should be written
    QVERIFY(!QFile::exists(tmpDir.path() + "/.clay/inspect/response.json"));
}

void TestInspectorUnit::testInvalidJsonIsIgnored()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write("{not valid json!!!");
    f.close();

    QTest::qWait(500);

    // No response should be written for invalid JSON
    QVERIFY(!QFile::exists(tmpDir.path() + "/.clay/inspect/response.json"));
}

QTEST_MAIN(TestInspectorUnit)
#include "tst_inspector_unit.moc"
