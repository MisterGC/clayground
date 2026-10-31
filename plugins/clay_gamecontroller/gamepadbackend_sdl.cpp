// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "gamepadbackend_sdl.h"

#include <QDebug>
#include <QSet>

#include <SDL3/SDL.h>

#include <algorithm>
#include <cmath>

// gamepadButtonNames() and gamepadAxisNames() are in SDL's enum order, so an
// SDL button or axis is the index of its name.
static_assert(SDL_GAMEPAD_BUTTON_COUNT == 26, "gamepadButtonNames() follows SDL_GamepadButton");
static_assert(SDL_GAMEPAD_AXIS_COUNT == 6, "gamepadAxisNames() follows SDL_GamepadAxis");

namespace {

bool isTrigger(int axis)
{
    return axis == SDL_GAMEPAD_AXIS_LEFT_TRIGGER || axis == SDL_GAMEPAD_AXIS_RIGHT_TRIGGER;
}

double axisValue(int axis, Sint16 raw)
{
    // SDL_JOYSTICK_AXIS_MIN is -32768, one step further than the maximum
    const double v = raw / double(SDL_JOYSTICK_AXIS_MAX);
    return isTrigger(axis) ? std::clamp(v, 0.0, 1.0) : std::clamp(v, -1.0, 1.0);
}

QString labelName(SDL_GamepadButtonLabel label)
{
    switch (label) {
    case SDL_GAMEPAD_BUTTON_LABEL_A: return QStringLiteral("A");
    case SDL_GAMEPAD_BUTTON_LABEL_B: return QStringLiteral("B");
    case SDL_GAMEPAD_BUTTON_LABEL_X: return QStringLiteral("X");
    case SDL_GAMEPAD_BUTTON_LABEL_Y: return QStringLiteral("Y");
    case SDL_GAMEPAD_BUTTON_LABEL_CROSS: return QStringLiteral("Cross");
    case SDL_GAMEPAD_BUTTON_LABEL_CIRCLE: return QStringLiteral("Circle");
    case SDL_GAMEPAD_BUTTON_LABEL_SQUARE: return QStringLiteral("Square");
    case SDL_GAMEPAD_BUTTON_LABEL_TRIANGLE: return QStringLiteral("Triangle");
    default: return {};
    }
}

} // namespace

SdlGamepadBackend::SdlGamepadBackend(QObject *parent)
    : GamepadBackend(parent)
{
    // SDL would install SIGINT/SIGTERM handlers that turn Ctrl+C into an
    // SDL_EVENT_QUIT nobody reads - the app could no longer be interrupted.
    SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
    // SDL never has a window here, so whether the app is in front is Qt's
    // business; the game decides what to do with input while in the back.
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");

    valid_ = SDL_Init(SDL_INIT_GAMEPAD);
    if (!valid_) {
        qWarning() << "GameController: SDL could not start reading gamepads:"
                   << SDL_GetError();
        return;
    }
    // State is read by poll(); queued events would only pile up unread
    SDL_SetJoystickEventsEnabled(false);
    SDL_SetGamepadEventsEnabled(false);
}

SdlGamepadBackend::~SdlGamepadBackend()
{
    if (!valid_) return;
    for (auto it = pads_.begin(); it != pads_.end(); ++it)
        SDL_CloseGamepad(it->gamepad);
    pads_.clear();
    for (auto it = virtual_.begin(); it != virtual_.end(); ++it) {
        SDL_CloseJoystick(it.value());
        SDL_DetachVirtualJoystick(SDL_JoystickID(it.key()));
    }
    virtual_.clear();
    SDL_Quit();
}

void SdlGamepadBackend::poll()
{
    if (!valid_) return;

    // Detects pads plugged in or out and reads the state of the open ones
    SDL_UpdateGamepads();

    int count = 0;
    SDL_JoystickID *ids = SDL_GetGamepads(&count);
    QSet<int> present;
    for (int i = 0; i < count; ++i)
        present.insert(int(ids[i]));
    SDL_free(ids);

    const QList<int> known = pads_.keys();
    for (int id : known)
        if (!present.contains(id)) close(id);
    for (int id : std::as_const(present))
        if (!pads_.contains(id)) open(id);

    const QStringList &buttonNames = gamepadButtonNames();
    const QStringList &axisNames = gamepadAxisNames();
    for (auto it = pads_.begin(); it != pads_.end(); ++it) {
        Pad &pad = it.value();
        int slot = 0;
        for (int b : std::as_const(pad.buttons)) {
            const double v = SDL_GetGamepadButton(pad.gamepad, SDL_GamepadButton(b)) ? 1 : 0;
            if (v != pad.values[slot]) {
                pad.values[slot] = v;
                emit inputChanged(it.key(), buttonNames[b], v);
            }
            ++slot;
        }
        for (int a : std::as_const(pad.axes)) {
            const double v = axisValue(a, SDL_GetGamepadAxis(pad.gamepad, SDL_GamepadAxis(a)));
            if (v != pad.values[slot]) {
                pad.values[slot] = v;
                emit inputChanged(it.key(), axisNames[a], v);
            }
            ++slot;
        }
    }
}

void SdlGamepadBackend::open(int deviceId)
{
    SDL_Gamepad *gamepad = SDL_OpenGamepad(SDL_JoystickID(deviceId));
    if (!gamepad) {
        qWarning() << "GameController: cannot open gamepad" << deviceId << SDL_GetError();
        return;
    }

    GamepadInfo info;
    info.deviceId = deviceId;
    const char *name = SDL_GetGamepadName(gamepad);
    info.name = name ? QString::fromUtf8(name) : QStringLiteral("Gamepad");
    const char *type = SDL_GetGamepadStringForType(SDL_GetGamepadType(gamepad));
    info.type = type ? QString::fromUtf8(type) : QStringLiteral("standard");

    Pad pad;
    pad.gamepad = gamepad;
    for (int b = 0; b < SDL_GAMEPAD_BUTTON_COUNT; ++b) {
        if (!SDL_GamepadHasButton(gamepad, SDL_GamepadButton(b))) continue;
        pad.buttons.append(b);
        info.buttons.append(gamepadButtonNames()[b]);
        if (b <= SDL_GAMEPAD_BUTTON_NORTH) {
            const QString label = labelName(SDL_GetGamepadButtonLabel(gamepad, SDL_GamepadButton(b)));
            if (!label.isEmpty()) info.labels.insert(gamepadButtonNames()[b], label);
        }
    }
    for (int a = 0; a < SDL_GAMEPAD_AXIS_COUNT; ++a) {
        if (!SDL_GamepadHasAxis(gamepad, SDL_GamepadAxis(a))) continue;
        pad.axes.append(a);
        info.axes.append(gamepadAxisNames()[a]);
    }
    // Everything starts neutral, as the hub assumes; poll() reports the rest
    pad.values.fill(0, pad.buttons.size() + pad.axes.size());
    pads_.insert(deviceId, pad);
    emit padAdded(info);
}

void SdlGamepadBackend::close(int deviceId)
{
    SDL_CloseGamepad(pads_.take(deviceId).gamepad);
    emit padRemoved(deviceId);
}

int SdlGamepadBackend::attachVirtual(const QString &name)
{
    if (!valid_) return -1;
    const QByteArray utf8 = name.toUtf8();
    SDL_VirtualJoystickDesc desc;
    SDL_INIT_INTERFACE(&desc);
    // A gamepad with every standard button and axis: SDL maps button i to
    // SDL_GamepadButton i and axis i to SDL_GamepadAxis i
    desc.type = SDL_JOYSTICK_TYPE_GAMEPAD;
    desc.nbuttons = SDL_GAMEPAD_BUTTON_COUNT;
    desc.naxes = SDL_GAMEPAD_AXIS_COUNT;
    desc.button_mask = (Uint32(1) << SDL_GAMEPAD_BUTTON_COUNT) - 1;
    desc.axis_mask = (Uint32(1) << SDL_GAMEPAD_AXIS_COUNT) - 1;
    desc.name = utf8.constData();
    // SDL names a pad after the mapping of its model; pads of one model share
    // it, so each virtual pad is a model of its own and keeps its name.
    // Without a vendor the model is the first bytes of the name, which
    // "Pad 1" and "Pad 2" share.
    static Uint16 nextProduct = 1;
    desc.vendor_id = 0xc1a7;
    desc.product_id = nextProduct++;
    const SDL_JoystickID id = SDL_AttachVirtualJoystick(&desc);
    if (!id) {
        qWarning() << "GameController: cannot attach a virtual gamepad:" << SDL_GetError();
        return -1;
    }
    virtual_.insert(int(id), SDL_OpenJoystick(id));
    return int(id);
}

bool SdlGamepadBackend::detachVirtual(int deviceId)
{
    if (!virtual_.contains(deviceId)) return false;
    SDL_CloseJoystick(virtual_.take(deviceId));
    return SDL_DetachVirtualJoystick(SDL_JoystickID(deviceId));
}

bool SdlGamepadBackend::setVirtualInput(int deviceId, const QString &input, double value)
{
    SDL_Joystick *joystick = virtual_.value(deviceId, nullptr);
    if (!joystick) return false;
    const int button = gamepadButtonNames().indexOf(input);
    if (button >= 0)
        return SDL_SetJoystickVirtualButton(joystick, button, value > .5);
    const int axis = gamepadAxisNames().indexOf(input);
    if (axis < 0) return false;
    // A virtual trigger spans the whole joystick range, rest at the minimum
    const double raw = isTrigger(axis) ?
        SDL_JOYSTICK_AXIS_MIN + std::clamp(value, 0.0, 1.0) * 65535.0 :
        std::clamp(value, -1.0, 1.0) * SDL_JOYSTICK_AXIS_MAX;
    return SDL_SetJoystickVirtualAxis(joystick, axis, Sint16(std::lround(raw)));
}
