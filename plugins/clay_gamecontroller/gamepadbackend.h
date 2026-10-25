// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef GAMEPADBACKEND_H
#define GAMEPADBACKEND_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

// What a backend knows about one physical pad. Buttons and axes are named in
// one vocabulary for every backend (gamepadButtonNames(), gamepadAxisNames()),
// so the QML source maps them once: SDL, the browser's Gamepad API and Qt's
// Universal Input all describe the same standard pad.
struct GamepadInfo
{
    // Unique while the pad is connected; a pad plugged in again gets a new one
    int deviceId = -1;
    QString name;
    // "xbox360", "ps5", "steamdeck", ... or "standard" when the backend cannot tell
    QString type;
    // The inputs this pad has, a subset of the names below
    QStringList buttons;
    QStringList axes;
    // What the face buttons are labelled on this pad, e.g. {south: "Cross"}
    QVariantMap labels;
};

// Every button name a backend may report: positional, after where a button
// sits on the pad, not what it is labelled.
inline const QStringList &gamepadButtonNames()
{
    static const QStringList names{
        "south", "east", "west", "north",
        "back", "guide", "start", "leftStick", "rightStick",
        "leftShoulder", "rightShoulder",
        "dpadUp", "dpadDown", "dpadLeft", "dpadRight",
        "misc1", "rightPaddle1", "leftPaddle1", "rightPaddle2", "leftPaddle2",
        "touchpad", "misc2", "misc3", "misc4", "misc5", "misc6"};
    return names;
}

// Every axis name: sticks in [-1, 1] with y down, as pads report them,
// triggers in [0, 1]
inline const QStringList &gamepadAxisNames()
{
    static const QStringList names{
        "leftX", "leftY", "rightX", "rightY", "leftTrigger", "rightTrigger"};
    return names;
}

// One way of reading physical pads: SDL3 on desktop, the browser's Gamepad
// API on WASM. The hub owns exactly one and calls poll() from its timer; a
// backend fed by events of its own may do nothing there. It reports through
// the signals, always on the hub's thread.
class GamepadBackend : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    // "sdl", "browser", ...
    virtual QString name() const = 0;
    virtual void poll() = 0;

    // A pad that exists only in software, for tests: attachVirtual() returns
    // its deviceId, -1 where the backend has no such pads. It shows up like
    // a plugged-in one on the next poll().
    virtual int attachVirtual(const QString &name) { Q_UNUSED(name); return -1; }
    virtual bool detachVirtual(int deviceId) { Q_UNUSED(deviceId); return false; }
    virtual bool setVirtualInput(int deviceId, const QString &input, double value)
    {
        Q_UNUSED(deviceId); Q_UNUSED(input); Q_UNUSED(value);
        return false;
    }

signals:
    void padAdded(const GamepadInfo &info);
    void padRemoved(int deviceId);
    // A button reads 0 or 1
    void inputChanged(int deviceId, const QString &input, double value);
};

#endif // GAMEPADBACKEND_H
