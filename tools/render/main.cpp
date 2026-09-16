// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// clayrender - one sandbox, one picture, no session (issue #164).

#include "renderhost.h"

#include <clayanchor.h>
#include <clayinspect.h>
#include <clayscenecapture.h>
#include <clayscenequery.h>
#include <claysettle.h>
#include <claystorage.h>

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <QCommandLineParser>
#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QFile>
#include <QMutex>
#include <QMutexLocker>
#include <QQuickItem>
#include <QTemporaryDir>
#include <QTextStream>

#include <memory>

namespace {

// Exit codes, so a script can tell the outcomes apart.
constexpr int EXIT_LOAD_FAILED = 1;        // nothing rendered
constexpr int EXIT_QML_ERRORS = 2;         // rendered, but the scene complained
constexpr int EXIT_STATE_NOT_REACHED = 3;  // --wait-for never came true

QtMessageHandler g_defaultHandler = nullptr;

// Qt runs the message handler on whichever thread happened to log, so it has to
// be reentrant. It is not just a theoretical requirement here: Qt Multimedia's
// ffmpeg plugin logs from a pooled worker thread while the main thread is still
// building the scene, and two threads growing the same QStringList corrupt the
// heap. That was issue #179 - the same command died as SIGSEGV, SIGABRT or
// SIGBUS depending on which thread lost the race, sometimes only at exit.
//
// The list and its mutex are leaked on purpose. Those worker threads can still
// be logging while static destructors run, so a list destroyed at exit is just
// the same race with a later deadline.
QMutex& problemsMutex()
{
    static QMutex* mutex = new QMutex;
    return *mutex;
}

QStringList& qmlProblems()
{
    static QStringList* problems = new QStringList;
    return *problems;
}

// A runtime ReferenceError does not stop a component from instantiating, so a
// sandbox can render a plausible-looking picture of a broken scene. Collect
// those and let them decide the exit code - reporting success for a scene that
// threw is exactly the failure this epic exists to remove.
void messageHandler(QtMsgType type, const QMessageLogContext& ctx,
                    const QString& msg)
{
    if (type == QtWarningMsg || type == QtCriticalMsg || type == QtFatalMsg) {
        QMutexLocker locker(&problemsMutex());
        qmlProblems() << msg;
    }
    // Deliberately outside the lock: the default handler writes to stderr and
    // may log again, and holding the lock across it would be a deadlock.
    if (g_defaultHandler)
        g_defaultHandler(type, ctx, msg);
}

int qmlProblemCount()
{
    QMutexLocker locker(&problemsMutex());
    return qmlProblems().size();
}

int fail(const QString& message)
{
    QTextStream(stderr) << "clayrender: " << message << "\n";
    return EXIT_LOAD_FAILED;
}

QSize parseSize(const QString& text, bool* ok)
{
    const auto parts = text.split('x', Qt::SkipEmptyParts);
    if (parts.size() != 2) { *ok = false; return {}; }
    bool okW = false, okH = false;
    QSize size(parts[0].toInt(&okW), parts[1].toInt(&okH));
    *ok = okW && okH && size.width() > 0 && size.height() > 0;
    return size;
}

QRect parseCrop(const QString& text, bool* ok)
{
    const auto parts = text.split(',', Qt::SkipEmptyParts);
    if (parts.size() != 4) { *ok = false; return {}; }
    bool allOk = true;
    int v[4];
    for (int i = 0; i < 4; ++i) {
        bool p = false;
        v[i] = parts[i].trimmed().toInt(&p);
        allOk = allOk && p;
    }
    *ok = allOk;
    return QRect(v[0], v[1], v[2], v[3]);
}

// One way of getting the scene into the state worth photographing.
struct Step
{
    enum Kind { Assign, Eval, Script };
    Kind kind;
    QString value;
};

// QCommandLineParser hands back all values of one option together, which
// loses the order BETWEEN options - and "--set paused=true --eval step()"
// does something different from the other way round. So the order comes
// from argv, and the parser is left to do the validating.
QList<Step> collectSteps(const QStringList& args)
{
    QList<Step> steps;
    for (int i = 1; i < args.size(); ++i) {
        const QString arg = args[i];
        auto take = [&](const char* name, Step::Kind kind) {
            const QString flag = QLatin1String("--") + QLatin1String(name);
            if (arg == flag) {
                if (i + 1 < args.size())
                    steps.append({kind, args[++i]});
                return true;
            }
            if (arg.startsWith(flag + QLatin1Char('='))) {
                steps.append({kind, arg.mid(flag.size() + 1)});
                return true;
            }
            return false;
        };
        if (take("set", Step::Assign)) continue;
        if (take("eval", Step::Eval)) continue;
        take("script", Step::Script);
    }
    return steps;
}

// What the scene did over time, as the loader's trace.jsonl says it: a meta
// line, then one JSON object per sample. The one difference is the clock -
// the loader samples on a timer, this samples once per rendered frame, so a
// sample here is always a frame that was actually drawn.
//
// Written a line at a time and flushed, never buffered until the end: a
// --wait-for that times out exits 3 without an image, and the trace of how
// the state was NOT reached is the evidence the caller came for.
class FrameTrace
{
public:
    // 'path' is a file, or "-" for stdout. Fails only when the file cannot be
    // opened, which is a usage error to report before anything renders.
    bool open(const QString& path, const QStringList& expressions,
              QString* error)
    {
        m_expressions = expressions;
        if (path == QLatin1String("-")) {
            m_stdout = true;
            return true;
        }
        m_file.setFileName(path);
        if (!m_file.open(QIODevice::WriteOnly | QIODevice::Truncate
                         | QIODevice::Text)) {
            if (error) *error = QStringLiteral("cannot write --trace-out %1")
                                .arg(path);
            return false;
        }
        return true;
    }

    // One sample: every expression against the root, this frame. A throw is
    // recorded as {"error": ...} for that expression and nothing else - the
    // trace is an observer, and an observer that aborts the run would turn
    // "what happened" into "nothing happened".
    void sample(QQuickItem* root)
    {
        if (m_frames == 0) {
            m_clock.start();
            writeMeta();
        }
        QJsonObject values;
        for (const auto& expression : m_expressions) {
            QJsonValue value;
            QString error;
            if (ClayScene::evalValue(root, expression, &value, &error))
                values[expression] = value;
            else
                values[expression] = QJsonObject{{"error", error}};
        }
        QJsonObject line;
        line["frame"] = m_frames;
        line["t"] = static_cast<double>(m_clock.elapsed());
        line["values"] = values;
        writeLine(line);
        ++m_frames;
    }

    // Stops observing. The meta line is still written for a run that never
    // rendered a frame, so the file always says what was being watched.
    void close()
    {
        if (m_closed)
            return;
        m_closed = true;
        if (m_frames == 0)
            writeMeta();
        if (m_file.isOpen())
            m_file.close();
    }

    ~FrameTrace() { close(); }

    int frames() const { return m_frames; }

private:
    void writeMeta()
    {
        QJsonObject meta;
        meta["meta"] = "trace_start";
        // Wall clock of the first sample, so epochMs + t is an absolute time
        // the same way it is for the loader's trace.
        meta["epochMs"] = static_cast<double>(QDateTime::currentMSecsSinceEpoch());
        meta["sampling"] = "frame";
        meta["watch"] = QJsonArray::fromStringList(m_expressions);
        writeLine(meta);
    }

    void writeLine(const QJsonObject& object)
    {
        const QByteArray line =
            QJsonDocument(object).toJson(QJsonDocument::Compact) + "\n";
        if (m_stdout) {
            QTextStream out(stdout);
            out << QString::fromUtf8(line);
            out.flush();
        } else if (m_file.isOpen()) {
            m_file.write(line);
            m_file.flush();
        }
    }

    QStringList m_expressions;
    QFile m_file;
    bool m_stdout = false;
    bool m_closed = false;
    int m_frames = 0;
    QElapsedTimer m_clock;
};

} // namespace

int main(int argc, char* argv[])
{
    qputenv("QML_DISABLE_DISK_CACHE", "1");

    g_defaultHandler = qInstallMessageHandler(messageHandler);

    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName("clayrender");
    QCoreApplication::setApplicationVersion(CLAY_RENDER_VERSION);

    QCommandLineParser parser;
    parser.setApplicationDescription(
        "Render one Clayground sandbox to a PNG and exit.\n"
        "\n"
        "Stateless by design: no dojo, no session, no protocol - so several\n"
        "variants can be rendered in parallel and a stale or dead instance\n"
        "cannot be mistaken for a fresh one.\n"
        "\n"
        "Rendering goes through the real GPU into a window that is never\n"
        "shown, so it does not steal focus - but it does need a graphics\n"
        "session. It will NOT work under QT_QPA_PLATFORM=offscreen or over a\n"
        "bare ssh connection (View3D content comes out blank there).\n"
        "\n"
        "Renders do not touch your settings: everything the sandbox persists\n"
        "(LabPrefs' theme, language and UI scale) goes to a throwaway store\n"
        "that is deleted on exit, so a render always starts from the defaults\n"
        "and cannot leave the next dojo session dark at 160%. See --prefs.");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument("sandbox",
        "Sandbox.qml to render (or --sbx, as the dojo spells it).");

    QCommandLineOption sbxOpt("sbx",
        "The sandbox to render - the same thing as the positional argument, "
        "spelled the way claydojo spells it, so one script can drive both. "
        "Giving both is an error.", "file");
    QCommandLineOption prefsOpt("prefs",
        QStringLiteral(
            "Where the sandbox may persist things: 'isolated' (default) uses "
            "a throwaway store deleted on exit, 'user' uses your real one "
            "(the store the dojo reads, so a theme or scale flipped here "
            "stays flipped), or a directory to keep one across a render "
            "series without touching yours. Carried to the engine as $%1, "
            "which any other headless host can set the same way.")
            .arg(QLatin1String(ClayScene::StorageDirEnvVar)),
        "isolated|user|dir", "isolated");
    QCommandLineOption outOpt({"o", "out"}, "Write the PNG here.", "file", "shot.png");
    QCommandLineOption sizeOpt("size", "Viewport size, e.g. 1600x1000.", "WxH", "1280x800");
    QCommandLineOption setOpt("set",
        "Assign a property after load, before capture: --set 'showLabels=false'. "
        "Evaluated in the root's own context, so ids and dotted paths work. "
        "Assignment only - use --eval to call something. Repeatable.",
        "path=value");
    QCommandLineOption evalOpt("eval",
        "Run statements in the root's context for their side effect: "
        "--eval 'applyScenario(\"parallel\")'. Repeatable, and --set/--eval/"
        "--script run in the order given on the command line.", "js");
    QCommandLineOption scriptOpt("script",
        "Run a JS file in the root's context - the same thing as --eval for "
        "setups too long for one line.", "file");
    QCommandLineOption resultOpt("result",
        "Write what each --eval/--script evaluated to: a JSON array in "
        "command-line order, one {\"source\", \"value\"} per fragment, to "
        "this file or to stdout for '-'. A fragment that is an expression "
        "answers with its value ('clock.time' -> 0); anything JSON cannot "
        "carry answers with its String(). Values are captured where the "
        "fragment runs, which is BEFORE --wait-for and the capture. Without "
        "the flag nothing is captured.", "file|-");
    QCommandLineOption pausedOpt("paused",
        "Start with Clayground.paused set, before the sandbox root exists, so "
        "no frame ticker ever runs and the first --eval sees clock.time === 0. "
        "This is what a stepped, reproducible run wants: advance the clock "
        "yourself (Lab.runFlow(), clock._advance(1/60)) instead of racing a "
        "wall clock.");
    QCommandLineOption waitForOpt("wait-for",
        "Hold the capture until this expression is truthy: --wait-for "
        "'spawned.length === 12'. Exits 3 if it never is, rather than "
        "photographing a state that was never reached.", "js");
    QCommandLineOption waitMsOpt("wait-timeout",
        "Upper bound for --wait-for in ms.", "ms", "3000");
    QCommandLineOption traceOpt("trace",
        "Evaluate this expression in the root's context once per rendered "
        "frame - from the first --set/--eval/--script through --frames, "
        "--wait-for and --settle, up to the capture - and write the samples "
        "to --trace-out. The one way to observe motion without a session: "
        "--trace 'view3d.mapFrom3DScene(prof.headAnchor).x'. Objects come "
        "back as JSON, an expression that throws yields {\"error\": ...} "
        "for that frame and never aborts the run. Repeatable.\n"
        "Example - a character's screen position through a flight:\n"
        "  clayrender labs/kits/professor/Sandbox.qml --out x.png "
        "--eval 'prof.appear()' --eval 'prof.travelTo(Qt.vector3d(6,0,4))' "
        "--trace 'view3d.mapFrom3DScene(prof.headAnchor).x' "
        "--trace 'prof.travelling' --trace-out flight.jsonl "
        "--wait-for '!prof.travelling' --wait-timeout 8000", "js");
    QCommandLineOption traceOutOpt("trace-out",
        "Where --trace samples go: JSONL in the shape of the loader's "
        "trace.jsonl - a {\"meta\":\"trace_start\",...} line, then one "
        "{\"frame\",\"t\",\"values\"} object per rendered frame, 't' in ms "
        "since the first sample and 'values' keyed by expression. Streamed "
        "as it goes, so a --wait-for that exits 3 still leaves the trace of "
        "how the state was not reached. Required with --trace.", "file|-");
    QCommandLineOption framesOpt("frames",
        "Render this many frames before capturing.", "n", "2");
    QCommandLineOption settleOpt("settle",
        "Capture once the picture stops changing (or the timeout expires).");
    QCommandLineOption settleMsOpt("settle-timeout",
        "Upper bound for --settle in ms.", "ms", "3000");
    QCommandLineOption dumpOpt("dump",
        "Ask the renderer what it actually got and write it as JSON: "
        "--dump lines=out.json (any type with a clayInspect() hook works, "
        "e.g. --dump LineBatch3D=lines.json). Numeric questions belong here, "
        "not in a screenshot.", "type=file");
    QCommandLineOption projectOpt("project",
        "Where a world point lands on screen: --project x,y,z", "x,y,z");
    QCommandLineOption pickOpt("pick",
        "What is under this pixel, with the colour rendered there: --pick x,y",
        "x,y");
    QCommandLineOption anchorOpt("anchor",
        "What a viewport rectangle is about: --anchor x,y,w,h. Reports the "
        "item or 3D node under its centre with name, type, source file and "
        "world position - or an explicitly unresolved anchor when nothing "
        "meaningful is there.", "x,y,w,h");
    QCommandLineOption cropOpt("crop",
        "Crop before scaling: either x,y,w,h in viewport pixels or the "
        "objectName of the item to cut out - --crop legendPanel. A name that "
        "matches nothing is an error, never the whole frame: a figure showing "
        "the wrong corner is worse than one that failed to render.",
        "rect|name");
    QCommandLineOption cropPadOpt("crop-pad",
        "Grow the crop by this many pixels on every side, clipped to the "
        "viewport. A tight cut around a panel reads as cramped.", "px");
    QCommandLineOption scaleOpt("scale", "Scale the capture, e.g. 0.5.", "factor");
    QCommandLineOption widthOpt("width", "Scale the capture to this width.", "px");

    parser.addOptions({sbxOpt, prefsOpt, outOpt, sizeOpt, setOpt, evalOpt,
                       scriptOpt, resultOpt, pausedOpt, waitForOpt, waitMsOpt,
                       traceOpt, traceOutOpt, framesOpt, settleOpt,
                       settleMsOpt, dumpOpt, projectOpt, pickOpt, anchorOpt,
                       cropOpt, cropPadOpt, scaleOpt, widthOpt});
    parser.process(app);

    const auto positional = parser.positionalArguments();
    // Two ways to name the sandbox, one sandbox. Silently preferring one of
    // them would render something other than what the command says.
    if (parser.isSet(sbxOpt) && !positional.isEmpty())
        return fail(QString("sandbox given twice: '%1' and --sbx '%2' - use one")
                    .arg(positional.first(), parser.value(sbxOpt)));
    if (positional.size() > 1)
        return fail(QString("one sandbox at a time, got %1").arg(positional.size()));
    const QString sandbox = parser.isSet(sbxOpt) ? parser.value(sbxOpt)
                                                 : positional.value(0);
    if (sandbox.isEmpty()) {
        parser.showHelp(1);
        return 1;
    }

    // Prefs before the engine exists: RenderHost reads the environment when it
    // sets the engine's offline storage path, and a store is chosen once.
    QTemporaryDir isolatedPrefs(QDir::tempPath() + "/clayrender-prefs-XXXXXX");
    const QString prefs = parser.value(prefsOpt);
    if (prefs == QLatin1String("user")) {
        // Whatever the caller's environment says - including their own
        // CLAY_STORAGE_DIR, which is the point of the variable.
    } else if (prefs == QLatin1String("isolated")) {
        if (!isolatedPrefs.isValid())
            return fail(QString("cannot create a throwaway prefs store: %1")
                        .arg(isolatedPrefs.errorString()));
        qputenv(ClayScene::StorageDirEnvVar, isolatedPrefs.path().toUtf8());
    } else {
        QDir dir(prefs);
        if (!dir.exists() && !dir.mkpath("."))
            return fail(QString("cannot create the prefs store %1").arg(prefs));
        qputenv(ClayScene::StorageDirEnvVar, dir.absolutePath().toUtf8());
    }

    bool ok = false;
    const QSize size = parseSize(parser.value(sizeOpt), &ok);
    if (!ok)
        return fail(QString("cannot parse --size '%1'").arg(parser.value(sizeOpt)));

    // Both halves or neither: a trace with nowhere to go would be silently
    // dropped, and a destination with nothing to watch is a typo.
    const QStringList traced = parser.values(traceOpt);
    if (!traced.isEmpty() && !parser.isSet(traceOutOpt))
        return fail("--trace without --trace-out: say where the samples go "
                    "(a file, or - for stdout)");
    if (traced.isEmpty() && parser.isSet(traceOutOpt))
        return fail("--trace-out without --trace: nothing to write");

    RenderHost host;
    host.setPausedOnLoad(parser.isSet(pausedOpt));
    if (!host.load(sandbox, size)) {
        for (const auto& e : host.errors())
            QTextStream(stderr) << "clayrender: " << e << "\n";
        return 1;
    }

    // One entry per --eval/--script, in the order they ran. Filled only when
    // --result asked for it: capturing a value needs a different wrapping, and
    // a run without the flag must behave exactly as it always did.
    const bool wantResults = parser.isSet(resultOpt);
    QJsonArray results;

    // Armed before the first step, so every frame from here to the capture
    // is a sample - but not the frames load() drew, which show a scene nobody
    // has asked anything of yet. Declared after host, so it is destroyed
    // (and flushed) first on every return path, including the exit-3 one.
    FrameTrace trace;
    if (!traced.isEmpty()) {
        QString error;
        if (!trace.open(parser.value(traceOutOpt), traced, &error))
            return fail(error);
        host.setFrameRendered([&]() { trace.sample(host.rootObject()); });
    }

    for (const auto& step : collectSteps(app.arguments())) {
        QString error;
        QJsonValue value;
        switch (step.kind) {
        case Step::Assign:
            if (!host.applyAssignment(step.value, &error))
                return fail(error);
            break;
        case Step::Eval:
            if (!host.evalScript(step.value, &error,
                                 wantResults ? &value : nullptr))
                return fail(QString("--eval '%1': %2").arg(step.value, error));
            if (wantResults)
                results.append(QJsonObject{{"source", step.value},
                                           {"value", value}});
            break;
        case Step::Script: {
            QFile file(step.value);
            if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
                return fail(QString("cannot read --script %1").arg(step.value));
            const QString source = QString::fromUtf8(file.readAll());
            if (!host.evalScript(source, &error,
                                 wantResults ? &value : nullptr))
                return fail(QString("--script %1: %2").arg(step.value, error));
            if (wantResults)
                // The path, not the file's contents: that is what the command
                // line said, and a setup script is not a one-liner to read
                // back in a report.
                results.append(QJsonObject{{"source", step.value},
                                           {"value", value}});
            break;
        }
        }
    }

    // Written here rather than at the end, because this is where the values
    // were taken: a --wait-for that never comes true exits 3, and the numbers
    // the run already produced are still worth having.
    if (wantResults) {
        const QString path = parser.value(resultOpt);
        const QByteArray json =
            QJsonDocument(results).toJson(QJsonDocument::Indented);
        if (path == QLatin1String("-")) {
            QTextStream(stdout) << QString::fromUtf8(json);
        } else {
            QFile file(path);
            if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
                return fail(QString("cannot write --result %1").arg(path));
            file.write(json);
        }
    }

    const int frames = parser.value(framesOpt).toInt();
    host.renderFrames(qMax(1, frames));

    if (parser.isSet(waitForOpt)) {
        ClayScene::WaitRequest req;
        req.expression = parser.value(waitForOpt);
        req.timeoutMs = parser.value(waitMsOpt).toInt();
        auto waited = ClayScene::waitFor(host, req);
        if (!waited.error.isEmpty())
            return fail(QString("--wait-for '%1': %2")
                        .arg(req.expression, waited.error));
        if (!waited.satisfied) {
            // No image: a picture of a state that was never reached is the
            // kind of evidence that costs an hour to disbelieve.
            QTextStream(stderr)
                << "clayrender: --wait-for '" << req.expression
                << "' still false after " << waited.waitedMs << " ms\n";
            return EXIT_STATE_NOT_REACHED;
        }
    }

    if (parser.isSet(settleOpt)) {
        ClayScene::SettleRequest req;
        req.timeoutMs = parser.value(settleMsOpt).toInt();
        auto settled = ClayScene::settle(host, req);
        if (!settled.error.isEmpty())
            return fail(settled.error);
        if (!settled.settled) {
            // Not an error: some scenes never stop moving. Say so, capture
            // anyway, and let the caller decide what that means.
            QTextStream(stderr)
                << "clayrender: still moving after " << settled.waitedMs
                << " ms (" << settled.lastDelta * 100.0
                << "% of pixels changing) - captured anyway\n";
        }
    }

    // Scene queries before the capture, so a dump describes the same frame the
    // picture shows.
    for (const auto& dump : parser.values(dumpOpt)) {
        const int eq = dump.indexOf('=');
        if (eq <= 0)
            return fail(QString("cannot parse --dump '%1' (want type=file)").arg(dump));
        QString type = dump.left(eq);
        const QString path = dump.mid(eq + 1);

        ClayScene::InspectSelector selector;
        // "lines" is the documented shorthand; everything else is a type name.
        selector.type = (type.compare("lines", Qt::CaseInsensitive) == 0)
                        ? QStringLiteral("LineBatch3D") : type;
        auto found = ClayScene::inspect(host.rootObject(), selector);

        QFile file(path);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
            return fail(QString("cannot write %1").arg(path));
        file.write(QJsonDocument(found).toJson(QJsonDocument::Indented));
        QTextStream(stdout) << path << " (" << found.size() << " "
                            << selector.type << ")\n";
    }

    if (parser.isSet(projectOpt)) {
        const auto parts = parser.value(projectOpt).split(',');
        if (parts.size() != 3)
            return fail("--project wants x,y,z");
        auto projected = ClayScene::project(host.rootObject(),
                                            parts[0].toDouble(),
                                            parts[1].toDouble(),
                                            parts[2].toDouble());
        QTextStream(stdout)
            << QString::fromUtf8(QJsonDocument(projected).toJson(QJsonDocument::Compact))
            << "\n";
    }

    if (parser.isSet(anchorOpt)) {
        const auto parts = parser.value(anchorOpt).split(',');
        if (parts.size() != 4)
            return fail("--anchor wants x,y,w,h");
        auto anchor = ClayScene::resolveAnchor(
            host.rootObject(),
            QRectF(parts[0].toDouble(), parts[1].toDouble(),
                   parts[2].toDouble(), parts[3].toDouble()));
        // The round trip, as a check you can read: a resolved anchor that
        // projects back somewhere else is a bad anchor, and this is the only
        // place it is visible without a session.
        if (anchor.value("resolved").toBool(false))
            anchor["now"] = ClayScene::reproject(host.rootObject(), anchor);
        QTextStream(stdout)
            << QString::fromUtf8(QJsonDocument(anchor).toJson(QJsonDocument::Compact))
            << "\n";
    }

    ClayScene::CaptureRequest capReq;
    if (parser.isSet(cropOpt)) {
        // Four numbers is a rectangle; anything else is the name of the thing
        // the caller actually means. No prefix to remember, and no ambiguity
        // in practice - an objectName is an identifier, so it has no commas.
        const QString spec = parser.value(cropOpt);
        capReq.crop = parseCrop(spec, &ok);
        if (!ok) {
            QString why;
            capReq.crop = ClayScene::itemRect(host.rootObject(), spec, &why);
            if (capReq.crop.isNull())
                return fail(QString("--crop '%1': %2 (give x,y,w,h or an "
                                    "objectName)").arg(spec, why));
        }
    }
    if (parser.isSet(cropPadOpt)) {
        if (capReq.crop.isNull())
            return fail("--crop-pad without --crop has nothing to grow");
        const int pad = parser.value(cropPadOpt).toInt(&ok);
        if (!ok || pad < 0)
            return fail(QString("--crop-pad wants a pixel count, got '%1'")
                            .arg(parser.value(cropPadOpt)));
        // The capture clips to the viewport, so padding off the edge is safe
        // and simply gives back a smaller margin on that side.
        capReq.crop = capReq.crop.adjusted(-pad, -pad, pad, pad);
    }
    if (parser.isSet(scaleOpt))
        capReq.scale = parser.value(scaleOpt).toDouble();
    if (parser.isSet(widthOpt))
        capReq.targetWidth = parser.value(widthOpt).toInt();

    auto capture = ClayScene::capture(host, capReq);
    // The capture's frame is the last sample: it is the frame the picture
    // shows. Whatever renders after this (--pick grabs the full frame again)
    // is not part of the run being observed.
    host.setFrameRendered({});
    trace.close();
    if (!capture.ok())
        return fail(capture.error);

    if (parser.isSet(pickOpt)) {
        const auto parts = parser.value(pickOpt).split(',');
        if (parts.size() != 2)
            return fail("--pick wants x,y");
        // The uncropped frame is the one whose pixel coordinates the caller
        // means.
        auto full = ClayScene::capture(host);
        auto picked = ClayScene::pick(host.rootObject(),
                                      parts[0].toDouble(), parts[1].toDouble(),
                                      QString(), &full.image);
        QTextStream(stdout)
            << QString::fromUtf8(QJsonDocument(picked).toJson(QJsonDocument::Compact))
            << "\n";
    }

    QString saveError;
    const QString outPath = parser.value(outOpt);
    if (!ClayScene::saveImage(capture.image, outPath, &saveError))
        return fail(saveError);

    QTextStream(stdout) << outPath << " ("
                        << capture.image.width() << "x"
                        << capture.image.height() << ")\n";

    // The picture exists either way - but a scene that threw is not a scene
    // you should trust, so say so and exit non-zero.
    const int problems = qmlProblemCount();
    if (problems > 0) {
        QTextStream(stderr) << "clayrender: " << problems
                            << " QML warning(s)/error(s) during render\n";
        return EXIT_QML_ERRORS;
    }
    return 0;
}
