// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "framestats.h"
#include "renderhost.h"

#include <QAnimationDriver>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QJsonValue>
#include <QList>
#include <QQuickItem>
#include <QTimer>

#include <algorithm>
#include <cmath>
#include <numeric>

#if defined(Q_OS_WIN)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#else
#include <ctime>
#endif


namespace {

// Advances animations once per frame slot, on the wall clock, the way a
// window's render loop does on the display's vsync. Qt's own driver runs on a
// timer of its own instead, so a slot saw zero, one or two animation ticks
// and the CPU time of the same lab moved by a fifth from run to run.
class SlotAnimationDriver : public QAnimationDriver
{
};

// CPU time of the whole process, in ms. The whole process and not the main
// thread: the graphics driver's threads do part of every frame's work.
double processCpuMs()
{
#if defined(Q_OS_WIN)
    FILETIME created, exited, kernel, user;
    if (!GetProcessTimes(GetCurrentProcess(), &created, &exited, &kernel, &user))
        return 0.0;
    auto ticks = [](const FILETIME& t) {
        return (static_cast<quint64>(t.dwHighDateTime) << 32) | t.dwLowDateTime;
    };
    return static_cast<double>(ticks(kernel) + ticks(user)) / 10000.0;
#else
    timespec ts{};
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts);
    return static_cast<double>(ts.tv_sec) * 1000.0
           + static_cast<double>(ts.tv_nsec) / 1.0e6;
#endif
}

// View3D is QQuick3DViewport in C++. Found by class name, so clayrender does
// not link Quick 3D for a sandbox that may not use it.
void collectViews3d(QQuickItem* item, QList<QQuickItem*>* views)
{
    if (!item)
        return;
    if (item->inherits("QQuick3DViewport"))
        views->append(item);
    for (auto* child : item->childItems())
        collectViews3d(child, views);
}

QObject* renderStatsOf(QQuickItem* view)
{
    return view->property("renderStats").value<QObject*>();
}

double rounded(double v)
{
    return std::round(v * 1000.0) / 1000.0;
}

QJsonValue summary(QList<double> values, bool withMean)
{
    if (values.isEmpty())
        return QJsonValue::Null;
    std::sort(values.begin(), values.end());
    const qsizetype n = values.size();
    const double median = n % 2 ? values[n / 2]
                                : (values[n / 2 - 1] + values[n / 2]) / 2.0;
    QJsonObject out;
    out["median"] = rounded(median);
    if (withMean)
        out["mean"] = rounded(std::accumulate(values.begin(), values.end(), 0.0)
                              / static_cast<double>(n));
    out["min"] = rounded(values.first());
    out["max"] = rounded(values.last());
    return out;
}

} // namespace

namespace FrameStats {

QJsonObject measure(RenderHost& host, int slotCount)
{
    QList<QQuickItem*> views;
    collectViews3d(host.rootObject(), &views);
    // Draw calls and vertices are only counted with extended data on.
    for (auto* view : views) {
        if (auto* stats = renderStatsOf(view))
            stats->setProperty("extendedDataCollectionEnabled", true);
    }

    // Whatever the setup left asking for a frame is drawn before the first
    // slot: it belongs to the state being measured, not to its cost.
    host.renderIfRequested();

    const double slotMs = 1000.0 / 60.0;
    const int framesBefore = host.renderedFrames();
    QList<double> cpuMs, renderMs, drawCalls, vertices;

    SlotAnimationDriver driver;
    driver.install();

    QElapsedTimer wall;
    wall.start();
    for (int i = 0; i < slotCount; ++i) {
        const double cpuBefore = processCpuMs();

        // Until the end of this slot the event loop runs on its own: events
        // and QTimers arrive at their real rate. A slot that overran leaves
        // the next one less time, as on a real display.
        const double remaining = (i + 1) * slotMs
                                 - static_cast<double>(wall.nsecsElapsed()) / 1.0e6;
        QEventLoop loop;
        QTimer::singleShot(std::max(0, static_cast<int>(std::lround(remaining))),
                           Qt::PreciseTimer, &loop, &QEventLoop::quit);
        loop.exec();

        // Animations, the sim clock's FrameAnimation and QML Timers next, as
        // on a display: they decide what this frame shows.
        driver.advance();

        QElapsedTimer drawing;
        drawing.start();
        if (host.renderIfRequested()) {
            renderMs.append(static_cast<double>(drawing.nsecsElapsed()) / 1.0e6);
            // Without a View3D there is nothing to count - null, not a zero
            // that reads as "draws nothing".
            if (!views.isEmpty()) {
                double calls = 0, verts = 0;
                for (auto* view : views) {
                    if (auto* stats = renderStatsOf(view)) {
                        calls += stats->property("drawCallCount").toDouble();
                        verts += stats->property("drawVertexCount").toDouble();
                    }
                }
                drawCalls.append(calls);
                vertices.append(verts);
            }
        }
        cpuMs.append(processCpuMs() - cpuBefore);
    }
    // Qt's own driver again, which takes over the animation time where this
    // one leaves it, so what runs after the measurement does not jump.
    driver.uninstall();

    QJsonObject out;
    out["frames"] = slotCount;
    out["rendered"] = host.renderedFrames() - framesBefore;
    out["seconds"] = rounded(static_cast<double>(wall.nsecsElapsed()) / 1.0e9);
    out["cpuMs"] = summary(cpuMs, true);
    out["renderMs"] = summary(renderMs, true);
    out["drawCalls"] = summary(drawCalls, false);
    out["vertices"] = summary(vertices, false);
    out["views3d"] = static_cast<int>(views.size());
    return out;
}

} // namespace FrameStats
