// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "gamepadhub.h"

#include <QCoreApplication>

#ifdef CLAY_GAMEPAD_SDL
#include "gamepadbackend_sdl.h"
#endif
#ifdef Q_OS_WASM
#include "gamepadbackend_browser.h"
#endif

namespace {

// 125 Hz: a press waits at most 8 ms for the next read, half a frame at 60 fps
constexpr int kPollIntervalMs = 8;

GamepadHub *theHub = nullptr;

} // namespace

ClayGamepad::ClayGamepad(const GamepadInfo &info, QObject *parent)
    : QObject(parent), info_(info)
{
    for (const QString &b : info.buttons) values_.insert(b, false);
    for (const QString &a : info.axes) values_.insert(a, 0.0);
}

QVariant ClayGamepad::value(const QString &input) const
{
    if (values_.contains(input)) return values_.value(input);
    return gamepadButtonNames().contains(input) ? QVariant(false) : QVariant(0.0);
}

void ClayGamepad::setValue(const QString &input, double value)
{
    const QVariant v = info_.buttons.contains(input) ? QVariant(value > .5) : QVariant(value);
    if (values_.value(input) == v) return;
    values_.insert(input, v);
    emit valuesChanged();
}

GamepadHub *GamepadHub::instance()
{
    if (!theHub) {
        theHub = new GamepadHub;
        // Before the application goes, so the backend lets go of its devices
        // while Qt still runs
        qAddPostRoutine([] { delete theHub; theHub = nullptr; });
    }
    return theHub;
}

GamepadHub *GamepadHub::create(QQmlEngine *, QJSEngine *)
{
    GamepadHub *hub = instance();
    // Shared by every engine, owned by none
    QJSEngine::setObjectOwnership(hub, QJSEngine::CppOwnership);
    return hub;
}

GamepadHub::GamepadHub(QObject *parent)
    : QObject(parent)
{
#ifdef CLAY_GAMEPAD_SDL
    auto *sdl = new SdlGamepadBackend(this);
    if (sdl->isValid()) backend_ = sdl;
    else delete sdl;
#endif
#ifdef Q_OS_WASM
    backend_ = new BrowserGamepadBackend(this);
#endif
    if (!backend_) return;

    connect(backend_, &GamepadBackend::padAdded, this, &GamepadHub::onPadAdded);
    connect(backend_, &GamepadBackend::padRemoved, this, &GamepadHub::onPadRemoved);
    connect(backend_, &GamepadBackend::inputChanged, this, &GamepadHub::onInputChanged);
    connect(&timer_, &QTimer::timeout, this, &GamepadHub::poll);
    timer_.setTimerType(Qt::PreciseTimer);
    timer_.start(kPollIntervalMs);
    // Pads connected before the start count from the first frame on
    poll();
}

QString GamepadHub::backend() const
{
    return backend_ ? backend_->name() : QStringLiteral("none");
}

QList<QObject *> GamepadHub::gamepads() const
{
    QList<QObject *> list;
    list.reserve(pads_.size());
    for (ClayGamepad *p : pads_) list.append(p);
    return list;
}

QObject *GamepadHub::gamepad(int deviceId) const
{
    for (ClayGamepad *p : pads_)
        if (p->deviceId() == deviceId) return p;
    return nullptr;
}

int GamepadHub::attachVirtualGamepad(const QString &name)
{
    if (!backend_) return -1;
    const int id = backend_->attachVirtual(name);
    poll();
    return id;
}

bool GamepadHub::setVirtualGamepadInput(int deviceId, const QString &input, double value)
{
    if (!backend_ || !backend_->setVirtualInput(deviceId, input, value)) return false;
    poll();
    return true;
}

bool GamepadHub::detachVirtualGamepad(int deviceId)
{
    if (!backend_ || !backend_->detachVirtual(deviceId)) return false;
    poll();
    return true;
}

void GamepadHub::poll()
{
    if (backend_) backend_->poll();
}

void GamepadHub::onPadAdded(const GamepadInfo &info)
{
    pads_.append(new ClayGamepad(info, this));
    emit gamepadsChanged();
}

void GamepadHub::onPadRemoved(int deviceId)
{
    for (int i = 0; i < pads_.size(); ++i) {
        if (pads_[i]->deviceId() != deviceId) continue;
        ClayGamepad *pad = pads_.takeAt(i);
        emit gamepadsChanged();
        emit gamepadRemoved(deviceId);
        // QML may still hold it in a binding being torn down
        pad->deleteLater();
        return;
    }
}

void GamepadHub::onInputChanged(int deviceId, const QString &input, double value)
{
    if (auto *pad = qobject_cast<ClayGamepad *>(gamepad(deviceId)))
        pad->setValue(input, value);
}
