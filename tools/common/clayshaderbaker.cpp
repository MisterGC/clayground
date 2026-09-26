// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayshaderbaker.h"

#include <QDirIterator>
#include <QFileInfo>
#include <QLibraryInfo>
#include <QProcess>

bool ClayShaderBaker::isShaderSource(const QString& path)
{
    return path.endsWith(".frag") || path.endsWith(".vert");
}

QString ClayShaderBaker::qsbTool()
{
    auto const env = qEnvironmentVariable("CLAY_QSB");
    if (!env.isEmpty()) return env;
#ifdef Q_OS_WIN
    auto const exe = QStringLiteral("qsb.exe");
#else
    auto const exe = QStringLiteral("qsb");
#endif
    // Qt ships qsb in bin/; some distributions move tools to libexec/.
    for (auto const loc: {QLibraryInfo::BinariesPath,
                          QLibraryInfo::LibraryExecutablesPath}) {
        auto const candidate = QLibraryInfo::path(loc) + "/" + exe;
        if (QFileInfo(candidate).isExecutable()) return candidate;
    }
    return {};
}

bool ClayShaderBaker::bake(const QString& source, QString* error)
{
    auto const tool = qsbTool();
    if (tool.isEmpty()) {
        if (error) *error = QStringLiteral(
            "cannot bake %1: no qsb found next to Qt (set CLAY_QSB)").arg(source);
        return false;
    }
    QProcess p;
    p.setProcessChannelMode(QProcess::MergedChannels);
    p.start(tool, {"--glsl", "100 es,120,150,300 es", "--hlsl", "50", "--msl", "12",
                   "-o", source + ".qsb", source});
    // A shader compiles in well under a second; the ceiling only guards
    // against a hung tool blocking the reload forever.
    if (!p.waitForFinished(20000)) {
        p.kill();
        if (error) *error = QStringLiteral("qsb timed out on %1").arg(source);
        return false;
    }
    if (p.exitStatus() != QProcess::NormalExit || p.exitCode() != 0) {
        if (error) *error = QStringLiteral("qsb failed on %1:\n%2")
                .arg(source, QString::fromLocal8Bit(p.readAll()).trimmed());
        return false;
    }
    return true;
}

ClayShaderBaker::Result ClayShaderBaker::bakeStale(const QString& dir)
{
    Result r;
    QDirIterator it(dir, {"*.frag", "*.vert"}, QDir::Files,
                    QDirIterator::Subdirectories);
    while (it.hasNext()) {
        auto const src = it.next();
        if (src.contains("/.clay/")) continue;
        QFileInfo const out(src + ".qsb");
        if (out.exists() && out.lastModified() >= QFileInfo(src).lastModified())
            continue;
        QString err;
        if (bake(src, &err)) ++r.baked;
        else r.errors << err;
    }
    return r;
}
