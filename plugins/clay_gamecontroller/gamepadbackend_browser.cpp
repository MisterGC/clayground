// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "gamepadbackend_browser.h"

#include <QRegularExpression>

#include <algorithm>

#ifdef Q_OS_WASM
#include <emscripten/html5.h>
#include <emscripten/val.h>
#endif

namespace {

// Virtual pads sit past any slot a browser hands out (Chrome has four)
constexpr int kVirtualSlot = 1 << 16;

// The standard gamepad of the Gamepad API: button i is the name at i, the
// triggers are buttons 6 and 7 with an analog value and read as axes
// (https://w3c.github.io/gamepad/#remapping)
const QStringList &standardButtons()
{
    static const QStringList names{
        "south", "east", "west", "north", "leftShoulder", "rightShoulder",
        "leftTrigger", "rightTrigger", "back", "start", "leftStick", "rightStick",
        "dpadUp", "dpadDown", "dpadLeft", "dpadRight", "guide"};
    return names;
}

const QStringList &standardAxes()
{
    static const QStringList names{"leftX", "leftY", "rightX", "rightY"};
    return names;
}

constexpr int kLeftTrigger = 6;
constexpr int kRightTrigger = 7;

bool isTriggerButton(int b) { return b == kLeftTrigger || b == kRightTrigger; }

} // namespace

BrowserGamepadBackend::BrowserGamepadBackend(QObject *parent)
    : GamepadBackend(parent)
{
}

QString BrowserGamepadBackend::padName(const QString &id)
{
    // emscripten hands the id over in 64 bytes, so Chrome's suffix often
    // arrives cut off before its closing parenthesis
    static const QRegularExpression chrome(
        QStringLiteral("\\s*\\([^()]*(?:STANDARD GAMEPAD|Vendor:)[^()]*\\)?\\s*$"));
    static const QRegularExpression firefox(
        QStringLiteral("^[0-9a-fA-F]{1,4}-[0-9a-fA-F]{1,4}-"));
    QString name = id;
    name.remove(chrome);
    name.remove(firefox);
    name = name.trimmed();
    return name.isEmpty() ? QStringLiteral("Gamepad") : name;
}

QList<BrowserPadState> BrowserGamepadBackend::sample()
{
    QList<BrowserPadState> pads;
#ifdef Q_OS_WASM
    // Fails where the page has no Gamepad API or a permissions policy
    // denies it; the browser then has no pads for us
    if (emscripten_sample_gamepad_data() != EMSCRIPTEN_RESULT_SUCCESS) return pads;
    const int count = emscripten_get_num_gamepads();
    for (int i = 0; i < count; ++i) {
        BrowserPadState s;
        EmscriptenGamepadEvent e;
        if (emscripten_get_gamepad_status(i, &e) == EMSCRIPTEN_RESULT_SUCCESS && e.connected) {
            s.present = true;
            s.id = QString::fromUtf8(e.id);
            s.mapping = QString::fromUtf8(e.mapping);
            const int numAxes = std::min(e.numAxes, 64);
            const int numButtons = std::min(e.numButtons, 64);
            for (int a = 0; a < numAxes; ++a) s.axes.append(e.axis[a]);
            for (int b = 0; b < numButtons; ++b) {
                s.buttonValues.append(e.analogButton[b]);
                s.buttonPressed.append(e.digitalButton[b]);
            }
        }
        pads.append(s);
    }
#endif
    return pads;
}

QString BrowserGamepadBackend::userAgent() const
{
#ifdef Q_OS_WASM
    const emscripten::val ua = emscripten::val::global("navigator")["userAgent"];
    if (ua.isString()) return QString::fromStdString(ua.as<std::string>());
#endif
    return {};
}

void BrowserGamepadBackend::poll()
{
    if (!checkedBrowser_) {
        checkedBrowser_ = true;
        unsupported_ = userAgent().contains(QStringLiteral("Firefox/"));
    }
    const QList<BrowserPadState> browser = sample();

    // A slot that emptied, or holds another pad now, lets go of its pad
    const QList<int> known = pads_.keys();
    for (int slot : known) {
        if (slot >= kVirtualSlot) {
            if (!virtual_.contains(pads_[slot].deviceId)) close(slot);
            continue;
        }
        if (slot >= browser.size() || !browser[slot].present
            || browser[slot].id != pads_[slot].id)
            close(slot);
    }

    for (int slot = 0; slot < browser.size(); ++slot) {
        if (!browser[slot].present) continue;
        if (!pads_.contains(slot)) open(slot, browser[slot], nextDeviceId_++);
        read(pads_[slot], browser[slot]);
    }
    for (auto it = virtual_.cbegin(); it != virtual_.cend(); ++it) {
        const int slot = kVirtualSlot + it.key();
        if (!pads_.contains(slot)) open(slot, it.value(), it.key());
        read(pads_[slot], it.value());
    }
}

void BrowserGamepadBackend::open(int slot, const BrowserPadState &state, int deviceId)
{
    GamepadInfo info;
    info.deviceId = deviceId;
    info.name = padName(state.id);
    // The browser says nothing about make or labels. A pad it does not map
    // is read as if it were mapped; its buttons may then carry other names.
    info.type = state.mapping == QStringLiteral("standard") ?
        QStringLiteral("standard") : QStringLiteral("unmapped");

    if (unsupported_) {
        // Listed, so the game can say why it does not move: no inputs at all
        info.type = QStringLiteral("unsupported");
        Pad pad;
        pad.deviceId = deviceId;
        pad.id = state.id;
        pads_.insert(slot, pad);
        emit padAdded(info);
        return;
    }

    // Every input the pad has, in the order of the common vocabulary
    const int numButtons = int(state.buttonValues.size());
    const int numAxes = int(state.axes.size());
    for (const QString &b : gamepadButtonNames()) {
        const int i = standardButtons().indexOf(b);
        if (i >= 0 && i < numButtons) info.buttons.append(b);
    }
    for (const QString &a : gamepadAxisNames()) {
        const int stick = standardAxes().indexOf(a);
        const int trigger = standardButtons().indexOf(a);
        if ((stick >= 0 && stick < numAxes) || (trigger >= 0 && trigger < numButtons))
            info.axes.append(a);
    }

    Pad pad;
    pad.deviceId = deviceId;
    pad.id = state.id;
    pad.inputs = info.buttons + info.axes;
    // Everything starts neutral, as the hub assumes; read() reports the rest
    pad.values.fill(0, pad.inputs.size());
    pads_.insert(slot, pad);
    emit padAdded(info);
}

void BrowserGamepadBackend::close(int slot)
{
    emit padRemoved(pads_.take(slot).deviceId);
}

void BrowserGamepadBackend::read(Pad &pad, const BrowserPadState &state)
{
    for (int i = 0; i < pad.inputs.size(); ++i) {
        const QString &input = pad.inputs[i];
        double v = 0;
        const int b = standardButtons().indexOf(input);
        if (isTriggerButton(b)) {
            // A trigger without travel reads 1 while pressed
            v = std::clamp(state.buttonValues.value(b), 0.0, 1.0);
            if (v == 0 && state.buttonPressed.value(b)) v = 1;
        } else if (b >= 0) {
            v = state.buttonPressed.value(b) ? 1 : 0;
        } else {
            v = std::clamp(state.axes.value(standardAxes().indexOf(input)), -1.0, 1.0);
        }
        if (v == pad.values[i]) continue;
        pad.values[i] = v;
        emit inputChanged(pad.deviceId, input, v);
    }
}

int BrowserGamepadBackend::attachVirtual(const QString &name)
{
    BrowserPadState s;
    s.present = true;
    s.id = name;
    s.mapping = QStringLiteral("standard");
    s.axes.fill(0, standardAxes().size());
    s.buttonValues.fill(0, standardButtons().size());
    s.buttonPressed.fill(false, standardButtons().size());
    const int id = nextDeviceId_++;
    virtual_.insert(id, s);
    return id;
}

bool BrowserGamepadBackend::detachVirtual(int deviceId)
{
    return virtual_.remove(deviceId) > 0;
}

bool BrowserGamepadBackend::setVirtualInput(int deviceId, const QString &input, double value)
{
    auto it = virtual_.find(deviceId);
    if (it == virtual_.end()) return false;
    const int b = standardButtons().indexOf(input);
    if (b >= 0) {
        const double v = isTriggerButton(b) ? std::clamp(value, 0.0, 1.0) : (value > .5 ? 1 : 0);
        it->buttonValues[b] = v;
        it->buttonPressed[b] = v > 0;
        return true;
    }
    const int a = standardAxes().indexOf(input);
    if (a < 0) return false;
    it->axes[a] = std::clamp(value, -1.0, 1.0);
    return true;
}
