// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayscenehost.h"

#include <QEventLoop>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QQuickWindow>
#include <QTimer>

namespace ClayScene {

Host::~Host() = default;

QQuickWindow* Host::window() const
{
    auto* root = rootObject();
    return root ? root->window() : nullptr;
}

QQmlEngine* Host::engine() const
{
    auto* root = rootObject();
    return root ? qmlEngine(root) : nullptr;
}

QImage Host::grabImage(int timeoutMs, QString* error) const
{
    auto* root = rootObject();
    if (!root) {
        if (error) *error = QStringLiteral("No sandbox root item available");
        return {};
    }

    auto grabResult = root->grabToImage();
    if (!grabResult) {
        if (error) *error = QStringLiteral("grabToImage failed");
        return {};
    }

    QImage image;
    QEventLoop loop;
    QObject::connect(grabResult.data(), &QQuickItemGrabResult::ready,
                     &loop, [&]() {
        image = grabResult->image();
        loop.quit();
    });
    QTimer::singleShot(timeoutMs, &loop, &QEventLoop::quit);
    loop.exec();

    if (image.isNull() && error)
        *error = QStringLiteral("grab timed out after %1 ms").arg(timeoutMs);
    return image;
}

void Host::advance()
{
    // A hosted, visible scene renders itself; there is nothing to drive.
}

} // namespace ClayScene
