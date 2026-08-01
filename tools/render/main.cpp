// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// clayrender - one sandbox, one picture, no session (issue #164).

#include "renderhost.h"

#include <clayinspect.h>
#include <clayscenecapture.h>
#include <claysettle.h>

#include <QJsonDocument>
#include <QJsonObject>

#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QFile>
#include <QQuickItem>
#include <QTextStream>

namespace {

// Exit codes, so a script can tell the three outcomes apart.
constexpr int EXIT_LOAD_FAILED = 1;   // nothing rendered
constexpr int EXIT_QML_ERRORS = 2;    // rendered, but the scene complained

QStringList g_qmlProblems;
QtMessageHandler g_defaultHandler = nullptr;

// A runtime ReferenceError does not stop a component from instantiating, so a
// sandbox can render a plausible-looking picture of a broken scene. Collect
// those and let them decide the exit code - reporting success for a scene that
// threw is exactly the failure this epic exists to remove.
void messageHandler(QtMsgType type, const QMessageLogContext& ctx,
                    const QString& msg)
{
    if (type == QtWarningMsg || type == QtCriticalMsg || type == QtFatalMsg)
        g_qmlProblems << msg;
    if (g_defaultHandler)
        g_defaultHandler(type, ctx, msg);
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
        "bare ssh connection (View3D content comes out blank there).");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument("sandbox", "Sandbox.qml to render.");

    QCommandLineOption outOpt({"o", "out"}, "Write the PNG here.", "file", "shot.png");
    QCommandLineOption sizeOpt("size", "Viewport size, e.g. 1600x1000.", "WxH", "1280x800");
    QCommandLineOption setOpt("set",
        "Assign a property after load, before capture: --set 'root.showLabels=false'. "
        "Evaluated in the root's own context, so ids and dotted paths work. Repeatable.",
        "path=value");
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
    QCommandLineOption cropOpt("crop", "Crop before scaling: x,y,w,h.", "rect");
    QCommandLineOption scaleOpt("scale", "Scale the capture, e.g. 0.5.", "factor");
    QCommandLineOption widthOpt("width", "Scale the capture to this width.", "px");

    parser.addOptions({outOpt, sizeOpt, setOpt, framesOpt, settleOpt,
                       settleMsOpt, dumpOpt, projectOpt, pickOpt, cropOpt,
                       scaleOpt, widthOpt});
    parser.process(app);

    const auto positional = parser.positionalArguments();
    if (positional.size() != 1) {
        parser.showHelp(1);
        return 1;
    }

    bool ok = false;
    const QSize size = parseSize(parser.value(sizeOpt), &ok);
    if (!ok)
        return fail(QString("cannot parse --size '%1'").arg(parser.value(sizeOpt)));

    RenderHost host;
    if (!host.load(positional.first(), size)) {
        for (const auto& e : host.errors())
            QTextStream(stderr) << "clayrender: " << e << "\n";
        return 1;
    }

    for (const auto& assignment : parser.values(setOpt)) {
        QString error;
        if (!host.applyAssignment(assignment, &error))
            return fail(error);
    }

    const int frames = parser.value(framesOpt).toInt();
    host.renderFrames(qMax(1, frames));

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

    ClayScene::CaptureRequest capReq;
    if (parser.isSet(cropOpt)) {
        capReq.crop = parseCrop(parser.value(cropOpt), &ok);
        if (!ok)
            return fail(QString("cannot parse --crop '%1'").arg(parser.value(cropOpt)));
    }
    if (parser.isSet(scaleOpt))
        capReq.scale = parser.value(scaleOpt).toDouble();
    if (parser.isSet(widthOpt))
        capReq.targetWidth = parser.value(widthOpt).toInt();

    auto capture = ClayScene::capture(host, capReq);
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
    if (!g_qmlProblems.isEmpty()) {
        QTextStream(stderr) << "clayrender: " << g_qmlProblems.size()
                            << " QML warning(s)/error(s) during render\n";
        return EXIT_QML_ERRORS;
    }
    return 0;
}
