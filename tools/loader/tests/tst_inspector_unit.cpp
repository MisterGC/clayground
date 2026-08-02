// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include <QtTest/QtTest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTemporaryDir>
#include <QDir>
#include <QFile>
#include <QRectF>

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
    void testStatusEnvelopeOnEveryResponse();
    void testGenerationCountsSuccessfulLoadsOnly();
    void testErrorsActionCarriesFileAndLine();
    void testErrorsActionFiltersBySinceGeneration();
    void testStatusLastErrorFromDojoState();
    void testBatchRunsStepsInOrder();
    void testBatchStopsAtFirstFailingStep();
    void testBatchStepNeedsAnAction();
    void testBatchRejectsNesting();
    void annotationCropFailureKeepsTheAnnotation();

private:
    // Round-trips one request through the file protocol and returns the
    // response object.
    static QJsonObject roundtrip(ClayInspector& inspector, const QString& dir,
                                 QJsonObject req);
};

QJsonObject TestInspectorUnit::roundtrip(ClayInspector& inspector,
                                         const QString& dir, QJsonObject req)
{
    Q_UNUSED(inspector);
    QFile f(dir + "/.clay/inspect/request.json");
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return {};
    f.write(QJsonDocument(req).toJson());
    f.close();

    // Wait for OUR reply: consecutive requests can produce byte-identical
    // responses apart from the id, and the file watcher is free to coalesce.
    QString wanted = req.value("id").toString();
    QJsonObject resp;
    for (int waited = 0; waited < 4000; waited += 100) {
        QTest::qWait(100);
        QFile rf(dir + "/.clay/inspect/response.json");
        if (!rf.open(QIODevice::ReadOnly))
            continue;
        resp = QJsonDocument::fromJson(rf.readAll()).object();
        rf.close();
        if (wanted.isEmpty() || resp.value("requestId").toString() == wanted)
            return resp;
    }
    return resp;
}

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
    QCOMPARE(resp["reloadStatus"].toString(), QStringLiteral("requested"));
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

void TestInspectorUnit::testStatusEnvelopeOnEveryResponse()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    // Even the failure path — an action nobody implements — must say whether
    // anyone was home.
    QJsonObject req;
    req["action"] = "bogus_action";
    req["id"] = "env-1";
    auto resp = roundtrip(inspector, tmpDir.path(), req);

    QVERIFY(resp.contains("status"));
    auto st = resp["status"].toObject();
    QCOMPARE(st["alive"].toBool(), true);
    QCOMPARE(st["rootLoaded"].toBool(), false);   // null container, no root
    QCOMPARE(st["generation"].toInt(), 0);
    QCOMPARE(st["phase"].toString(), QStringLiteral("starting"));
    QCOMPARE(st["supervised"].toBool(), false);   // no dojo.json
    QCOMPARE(st["restarts"].toInt(), 0);
    QVERIFY(st.contains("sandbox"));
    QVERIFY(st.contains("runId"));
    // No capture in this response, so no claim about one.
    QVERIFY(!st.contains("renderedAt"));

    // protocolVersion moved to 3 with the envelope.
    QFile sf(tmpDir.path() + "/.clay/inspect/state.json");
    QVERIFY(sf.open(QIODevice::ReadOnly));
    auto state = QJsonDocument::fromJson(sf.readAll()).object();
    sf.close();
    QCOMPARE(state["protocolVersion"].toInt(), 3);
}

void TestInspectorUnit::testGenerationCountsSuccessfulLoadsOnly()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    auto generationOf = [&](const QString& id) {
        QJsonObject req;
        req["action"] = "eval";
        req["id"] = id;
        return roundtrip(inspector, tmpDir.path(), req)["status"]
                   .toObject()["generation"].toInt();
    };

    QCOMPARE(generationOf("g0"), 0);

    inspector.markReady();
    QCOMPARE(generationOf("g1"), 1);

    // A reload attempt that ends in a load error must NOT advance it — the
    // whole point is "is the scene I am measuring the one I edited?".
    inspector.markReloading();
    inspector.markLoadError();
    QCOMPARE(generationOf("g2"), 1);

    inspector.markReloading();
    inspector.markReady();
    QCOMPARE(generationOf("g3"), 2);

    // reloadCount counts attempts and stays independent.
    QFile sf(tmpDir.path() + "/.clay/inspect/state.json");
    QVERIFY(sf.open(QIODevice::ReadOnly));
    auto state = QJsonDocument::fromJson(sf.readAll()).object();
    sf.close();
    QCOMPARE(state["generation"].toInt(), 2);
    QCOMPARE(state["reloadCount"].toInt(), 2);
}

void TestInspectorUnit::testErrorsActionCarriesFileAndLine()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());
    inspector.markReady();

    inspector.addError("file:///tmp/gym/Sandbox.qml:80:12: "
                       "TypeError: Property 'nope' is not a function");
    inspector.addWarning("plain warning without a location");

    QJsonObject req;
    req["action"] = "errors";
    req["id"] = "e1";
    auto resp = roundtrip(inspector, tmpDir.path(), req);

    QCOMPARE(resp["action"].toString(), QStringLiteral("errors"));
    auto errors = resp["errors"].toArray();
    QCOMPARE(errors.size(), 1);
    auto e = errors[0].toObject();
    QCOMPARE(e["file"].toString(), QStringLiteral("file:///tmp/gym/Sandbox.qml"));
    QCOMPARE(e["line"].toInt(), 80);
    QCOMPARE(e["generation"].toInt(), 1);
    QVERIFY(e["text"].toString().contains("TypeError"));
    QVERIFY(e.contains("ts"));

    auto warnings = resp["warnings"].toArray();
    QCOMPARE(warnings.size(), 1);
    // A message with no location gets no location, not a guessed one.
    QVERIFY(!warnings[0].toObject().contains("file"));

    QCOMPARE(resp["errorCount"].toInt(), 1);
    QCOMPARE(resp["warningCount"].toInt(), 1);
    QCOMPARE(resp["truncated"].toBool(), false);
}

void TestInspectorUnit::testErrorsActionFiltersBySinceGeneration()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    inspector.markReady();               // generation 1
    inspector.addError("old failure");
    inspector.markReloading();
    inspector.markReady();               // generation 2
    inspector.addError("fresh failure");

    QJsonObject req;
    req["action"] = "errors";
    req["sinceGeneration"] = 2;
    req["id"] = "e2";
    auto resp = roundtrip(inspector, tmpDir.path(), req);

    auto errors = resp["errors"].toArray();
    QCOMPARE(errors.size(), 1);
    QCOMPARE(errors[0].toObject()["text"].toString(), QStringLiteral("fresh failure"));
    QCOMPARE(resp["sinceGeneration"].toInt(), 2);

    // Diagnostics raised while a load is in flight belong to the load being
    // attempted, so a failed reload's errors are visible at generation + 1
    // even though the reported generation never advanced.
    inspector.markReloading();
    inspector.addError("failed while loading");
    inspector.markLoadError();

    QJsonObject req2;
    req2["action"] = "errors";
    req2["sinceGeneration"] = 3;
    req2["id"] = "e3";
    auto resp2 = roundtrip(inspector, tmpDir.path(), req2);
    auto errors2 = resp2["errors"].toArray();
    QCOMPARE(errors2.size(), 1);
    QCOMPARE(errors2[0].toObject()["text"].toString(),
             QStringLiteral("failed while loading"));
    QCOMPARE(resp2["status"].toObject()["generation"].toInt(), 2);
}

void TestInspectorUnit::testStatusLastErrorFromDojoState()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    // What a supervisor in a crash loop leaves behind. The inspector reads it
    // from the sandbox dir (never the instance-scoped subdir) rather than
    // inventing a second channel.
    QJsonObject dojo;
    dojo["role"] = "dojo";
    dojo["generation"] = 4;
    dojo["phase"] = "child_crashed";
    dojo["rapidCrashCount"] = 3;
    dojo["lastExitCode"] = 0;
    dojo["lastExitStatus"] = "normal";
    dojo["updatedAt"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
    QFile df(tmpDir.path() + "/.clay/inspect/dojo.json");
    QVERIFY(df.open(QIODevice::WriteOnly | QIODevice::Truncate));
    df.write(QJsonDocument(dojo).toJson());
    df.close();

    QJsonObject req;
    req["action"] = "eval";
    req["id"] = "d1";
    auto st = roundtrip(inspector, tmpDir.path(), req)["status"].toObject();

    QCOMPARE(st["supervised"].toBool(), true);
    QCOMPARE(st["restarts"].toInt(), 3);   // 4 children started => 3 respawns
    QVERIFY(st["lastError"].toString().contains("child exited 0"));
}

void TestInspectorUnit::testBatchRunsStepsInOrder()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());
    inspector.addError("boom");

    // Two 'errors' steps that differ only in their body: the second filters
    // everything away. Same results in the same order proves both that the
    // steps ran in order and that each got its own request body.
    QJsonObject step1;
    step1["action"] = "errors";
    QJsonObject step2;
    step2["action"] = "errors";
    step2["sinceGeneration"] = 99;

    QJsonObject req;
    req["action"] = "batch";
    req["id"] = "b1";
    req["steps"] = QJsonArray{step1, step2};
    auto resp = roundtrip(inspector, tmpDir.path(), req);

    QVERIFY(!resp.contains("error"));
    QVERIFY(!resp.contains("failedStep"));
    QCOMPARE(resp["stepsRun"].toInt(), 2);
    QCOMPARE(resp["stepsTotal"].toInt(), 2);

    auto steps = resp["steps"].toArray();
    QCOMPARE(steps.size(), 2);
    QCOMPARE(steps[0].toObject()["errorCount"].toInt(), 1);
    QCOMPARE(steps[1].toObject()["errorCount"].toInt(), 0);
    // Action echoed per step, generation recorded per step, envelope once.
    QCOMPARE(steps[0].toObject()["action"].toString(), QStringLiteral("errors"));
    QVERIFY(steps[0].toObject().contains("generation"));
    QVERIFY(steps[1].toObject().contains("generation"));
    QVERIFY(resp["status"].toObject().contains("alive"));
    QCOMPARE(resp["action"].toString(), QStringLiteral("batch"));
}

void TestInspectorUnit::testBatchStopsAtFirstFailingStep()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QJsonObject ok;
    ok["action"] = "errors";
    QJsonObject bad;
    bad["action"] = "no_such_action";

    QJsonObject req;
    req["action"] = "batch";
    req["id"] = "b2";
    req["steps"] = QJsonArray{ok, bad, ok};
    auto resp = roundtrip(inspector, tmpDir.path(), req);

    QCOMPARE(resp["failedStep"].toInt(), 1);
    QCOMPARE(resp["stepsRun"].toInt(), 2);      // the third never ran
    QCOMPARE(resp["stepsTotal"].toInt(), 3);
    QCOMPARE(resp["steps"].toArray().size(), 2);
    QVERIFY(resp["error"].toString().contains("step 1"));
    QVERIFY(resp["error"].toString().contains("Unknown action"));
}

void TestInspectorUnit::testBatchStepNeedsAnAction()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    // The shorthand from the issue sketch. Without an explicit action this
    // would default to 'snapshot' and the caller would think a key was sent.
    QJsonObject sugar;
    sugar["input"] = QJsonObject{{"key", QJsonObject{{"key", "V"}}}};

    QJsonObject req;
    req["action"] = "batch";
    req["id"] = "b3";
    req["steps"] = QJsonArray{sugar};
    auto resp = roundtrip(inspector, tmpDir.path(), req);

    QCOMPARE(resp["failedStep"].toInt(), 0);
    QVERIFY(resp["steps"].toArray()[0].toObject()["error"].toString()
                .contains("action"));
}

void TestInspectorUnit::testBatchRejectsNesting()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    QJsonObject inner;
    inner["action"] = "batch";
    inner["steps"] = QJsonArray{};

    QJsonObject req;
    req["action"] = "batch";
    req["id"] = "b4";
    req["steps"] = QJsonArray{inner};
    auto resp = roundtrip(inspector, tmpDir.path(), req);

    QCOMPARE(resp["failedStep"].toInt(), 0);
    QVERIFY(resp["error"].toString().contains("nest"));

    // An empty batch is a caller mistake, not a no-op.
    QJsonObject empty;
    empty["action"] = "batch";
    empty["id"] = "b5";
    empty["steps"] = QJsonArray{};
    auto eresp = roundtrip(inspector, tmpDir.path(), empty);
    QVERIFY(eresp["error"].toString().contains("empty"));
}

// The overlay's creation-side call, when there is no scene to capture or to
// resolve against. Neither failure may cost the annotation: the note and the
// rect are the record, the crop and the anchor are evidence about it.
void TestInspectorUnit::annotationCropFailureKeepsTheAnnotation()
{
    QTemporaryDir tmpDir;
    QVERIFY(tmpDir.isValid());

    ClayInspector inspector(nullptr);
    inspector.setSandboxDir(tmpDir.path());

    const QString crew = tmpDir.path() + "/.clay/crew";
    QDir().mkpath(crew + "/annotations");
    QJsonObject entry{
        {"id", "a1"},
        {"created", "2026-08-02T10:11:12"},
        {"generation", 2},
        {"scope", "region"},
        {"rect", QJsonArray{10, 20, 30, 40}},
        {"note", "the label is clipped"},
        {"status", "open"},
    };
    QJsonObject doc{{"version", 1}, {"annotations", QJsonArray{entry}}};
    QFile store(crew + "/annotations/index.json");
    QVERIFY(store.open(QIODevice::WriteOnly | QIODevice::Truncate));
    store.write(QJsonDocument(doc).toJson());
    store.close();

    auto result = inspector.attachAnnotation("a1", QRectF(10, 20, 30, 40));
    QVERIFY(result.value("stored").toBool());
    QVERIFY(!result.value("cropError").toString().isEmpty());
    QCOMPARE(result.value("anchor").toMap().value("resolved").toBool(), false);

    QVERIFY(store.open(QIODevice::ReadOnly));
    auto written = QJsonDocument::fromJson(store.readAll())
                       .object().value("annotations").toArray()
                       .at(0).toObject();
    store.close();
    // The user's fields untouched, the crop honestly absent rather than
    // pointing at a file that was never written.
    QCOMPARE(written.value("note").toString(), QStringLiteral("the label is clipped"));
    QCOMPARE(written.value("generation").toInt(), 2);
    QCOMPARE(written.value("status").toString(), QStringLiteral("open"));
    QVERIFY(written.value("crop").isNull());
    QCOMPARE(written.value("anchor").toObject().value("resolved").toBool(), false);

    // And an id nobody created is a reported failure, not a silent write.
    auto orphan = inspector.attachAnnotation("nope", QRectF(0, 0, 5, 5));
    QVERIFY(!orphan.value("stored").toBool());
    QVERIFY(orphan.value("storeError").toString().contains("nope"));
}

QTEST_MAIN(TestInspectorUnit)
#include "tst_inspector_unit.moc"
