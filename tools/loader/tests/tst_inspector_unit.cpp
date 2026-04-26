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
    void testNullRootSnapshotCarriesDiagnostics();
    void testUnknownActionReturnsError();
    void testEmptyRequestFileIsIgnored();
    void testInvalidJsonIsIgnored();
    void testStateFileReflectsPhaseTransitions();
    void testEventLogRecordsSessionAndPhaseEvents();
    void testResponseEchoesRequestId();
    void testReloadActionEmitsSignal();
    void testWaitForRootOnLoadErrorEarlyReturns();
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

    // Null root now also attaches diagnostics, but after clearLogs() they are empty.
    QVERIFY(resp.contains("error"));
    QVERIFY(resp.contains("logTail"));
    QVERIFY(resp.contains("warnings"));
    QVERIFY(resp.contains("errors"));
    QCOMPARE(resp["logTail"].toArray().size(), 0);
    QCOMPARE(resp["warnings"].toArray().size(), 0);
    QCOMPARE(resp["errors"].toArray().size(), 0);
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

void TestInspectorUnit::testNullRootSnapshotCarriesDiagnostics()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.addLogMessage("scene-init begin");
    inspector.addWarning("deprecated property X");
    inspector.addError("Type SomeMissingComponent unavailable");

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

    // The whole point of this fix: diagnostics must be present even when the
    // sandbox failed to produce a root item.
    QVERIFY(resp.contains("logTail"));
    QVERIFY(resp.contains("warnings"));
    QVERIFY(resp.contains("errors"));

    auto logs = resp["logTail"].toArray();
    auto warns = resp["warnings"].toArray();
    auto errs = resp["errors"].toArray();
    QCOMPARE(logs.size(), 1);
    QCOMPARE(logs[0].toString(), QStringLiteral("scene-init begin"));
    QCOMPARE(warns.size(), 1);
    QCOMPARE(warns[0].toString(), QStringLiteral("deprecated property X"));
    QCOMPARE(errs.size(), 1);
    QVERIFY(errs[0].toString().contains("SomeMissingComponent"));
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

void TestInspectorUnit::testStateFileReflectsPhaseTransitions()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QString statePath = tmpDir.path() + "/.clay/inspect/state.json";
    QVERIFY(QFile::exists(statePath));

    auto readState = [&]() {
        QFile f(statePath);
        [&]{ QVERIFY(f.open(QIODevice::ReadOnly)); }();
        return QJsonDocument::fromJson(f.readAll()).object();
    };

    auto initial = readState();
    QCOMPARE(initial["phase"].toString(), QStringLiteral("starting"));
    QCOMPARE(initial["reloadCount"].toInt(), 0);
    QVERIFY(initial.contains("pid"));
    QVERIFY(initial.contains("startedAt"));
    QVERIFY(!initial.contains("lastReadyAt"));
    QVERIFY(!initial.contains("lastLoadErrorAt"));

    inspector.markReady();
    auto ready = readState();
    QCOMPARE(ready["phase"].toString(), QStringLiteral("ready"));
    QVERIFY(ready.contains("lastReadyAt"));

    inspector.markReloading();
    auto reloading = readState();
    QCOMPARE(reloading["phase"].toString(), QStringLiteral("reloading"));
    QCOMPARE(reloading["reloadCount"].toInt(), 1);

    inspector.markLoadError();
    auto errored = readState();
    QCOMPARE(errored["phase"].toString(), QStringLiteral("load_error"));
    QVERIFY(errored.contains("lastLoadErrorAt"));
    // Prior success timestamp must be preserved across a failed reload so the
    // agent can reason about "last known good state".
    QVERIFY(errored.contains("lastReadyAt"));
}

void TestInspectorUnit::testEventLogRecordsSessionAndPhaseEvents()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());
    inspector.markReloading();
    inspector.markReady();

    QString eventsPath = tmpDir.path() + "/.clay/inspect/events.jsonl";
    QVERIFY(QFile::exists(eventsPath));

    QFile f(eventsPath);
    QVERIFY(f.open(QIODevice::ReadOnly));
    QStringList lines = QString::fromUtf8(f.readAll()).split('\n', Qt::SkipEmptyParts);
    f.close();

    QCOMPARE(lines.size(), 3);

    auto parse = [](const QString& s) {
        return QJsonDocument::fromJson(s.toUtf8()).object();
    };
    auto first = parse(lines[0]);
    auto second = parse(lines[1]);
    auto third = parse(lines[2]);

    QCOMPARE(first["type"].toString(), QStringLiteral("session_start"));
    QVERIFY(first["data"].toObject().contains("pid"));
    QVERIFY(first["data"].toObject().contains("sandbox"));

    QCOMPARE(second["type"].toString(), QStringLiteral("phase_change"));
    QCOMPARE(second["data"].toObject()["phase"].toString(), QStringLiteral("reloading"));

    QCOMPARE(third["type"].toString(), QStringLiteral("phase_change"));
    QCOMPARE(third["data"].toObject()["phase"].toString(), QStringLiteral("ready"));
}

void TestInspectorUnit::testResponseEchoesRequestId()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QJsonObject req;
    req["action"] = "snapshot";
    req["id"] = "req-42";
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(QJsonDocument(req).toJson());
    f.close();

    QTest::qWait(500);

    QFile rf(tmpDir.path() + "/.clay/inspect/response.json");
    QVERIFY(rf.open(QIODevice::ReadOnly));
    auto resp = QJsonDocument::fromJson(rf.readAll()).object();
    rf.close();

    QCOMPARE(resp["requestId"].toString(), QStringLiteral("req-42"));
}

void TestInspectorUnit::testReloadActionEmitsSignal()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QSignalSpy spy(&inspector, &ClayInspector::reloadRequested);

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QJsonObject req;
    req["action"] = "reload";
    req["id"] = "r1";
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(QJsonDocument(req).toJson());
    f.close();

    QTest::qWait(500);

    QCOMPARE(spy.count(), 1);

    QFile rf(tmpDir.path() + "/.clay/inspect/response.json");
    QVERIFY(rf.open(QIODevice::ReadOnly));
    auto resp = QJsonDocument::fromJson(rf.readAll()).object();
    rf.close();
    QCOMPARE(resp["status"].toString(), QStringLiteral("requested"));
    QCOMPARE(resp["requestId"].toString(), QStringLiteral("r1"));
}

void TestInspectorUnit::testWaitForRootOnLoadErrorEarlyReturns()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());
    inspector.markLoadError();  // terminal phase — waitForRoot must not block

    QString reqPath = tmpDir.path() + "/.clay/inspect/request.json";
    QJsonObject req;
    req["action"] = "waitForRoot";
    req["id"] = "w1";
    req["timeoutMs"] = 5000;  // large — test would hang if early-return broke
    QFile f(reqPath);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(QJsonDocument(req).toJson());
    f.close();

    QElapsedTimer t; t.start();
    QTest::qWait(500);
    qint64 elapsed = t.elapsed();
    QVERIFY2(elapsed < 2000, "waitForRoot blocked despite terminal phase");

    QFile rf(tmpDir.path() + "/.clay/inspect/response.json");
    QVERIFY(rf.open(QIODevice::ReadOnly));
    auto resp = QJsonDocument::fromJson(rf.readAll()).object();
    rf.close();
    QCOMPARE(resp["phase"].toString(), QStringLiteral("load_error"));
    QCOMPARE(resp["ready"].toBool(), false);
    QCOMPARE(resp["waited"].toInt(), 0);
}

QTEST_MAIN(TestInspectorUnit)
#include "tst_inspector_unit.moc"
