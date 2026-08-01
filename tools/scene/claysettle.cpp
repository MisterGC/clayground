// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claysettle.h"
#include "clayscenecapture.h"
#include "clayscenehost.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QImage>
#include <QTimer>

namespace ClayScene {

SettleResult settle(const Host& host, const SettleRequest& request)
{
    SettleResult result;

    QElapsedTimer clock;
    clock.start();

    QImage previous;
    int stable = 0;

    while (clock.elapsed() < request.timeoutMs) {
        // Let the scene advance: animations tick, physics steps, the render
        // thread produces a new frame.
        QEventLoop loop;
        QTimer::singleShot(request.intervalMs, &loop, &QEventLoop::quit);
        loop.exec();

        QString error;
        QImage current = host.grabImage(request.timeoutMs, &error);
        if (current.isNull()) {
            result.error = error.isEmpty()
                           ? QStringLiteral("settle: capture failed") : error;
            result.waitedMs = static_cast<int>(clock.elapsed());
            return result;
        }

        if (!previous.isNull()) {
            ++result.framesCompared;
            auto d = diffImages(previous, current, request.tolerance);
            if (!d.ok()) {
                // A size change means the window is still settling its layout;
                // treat it as motion rather than an error.
                stable = 0;
            } else {
                result.lastDelta = d.delta;
                stable = (d.changedPixels == 0) ? stable + 1 : 0;
            }

            if (stable >= request.stableFrames) {
                result.settled = true;
                result.waitedMs = static_cast<int>(clock.elapsed());
                return result;
            }
        }

        previous = current;
    }

    result.waitedMs = static_cast<int>(clock.elapsed());
    return result;
}

} // namespace ClayScene
