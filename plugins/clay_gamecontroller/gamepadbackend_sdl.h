// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef GAMEPADBACKEND_SDL_H
#define GAMEPADBACKEND_SDL_H

#include "gamepadbackend.h"

#include <QHash>
#include <QVector>

struct SDL_Gamepad;
struct SDL_Joystick;

// Reads pads through SDL3's gamepad subsystem and nothing else of SDL: no
// window, no video, no event queue. poll() updates SDL's device list and
// state and reports what changed. SDL brings its controller database (the
// mapping from a pad's raw buttons to the standard pad) and honours the
// environment Steam sets for its virtual pad.
class SdlGamepadBackend : public GamepadBackend
{
    Q_OBJECT

public:
    explicit SdlGamepadBackend(QObject *parent = nullptr);
    ~SdlGamepadBackend() override;

    // False when SDL could not start its gamepad subsystem; the backend
    // then reports no pads
    bool isValid() const { return valid_; }

    QString name() const override { return QStringLiteral("sdl"); }
    void poll() override;

    int attachVirtual(const QString &name) override;
    bool detachVirtual(int deviceId) override;
    bool setVirtualInput(int deviceId, const QString &input, double value) override;

private:
    struct Pad {
        SDL_Gamepad *gamepad = nullptr;
        QVector<int> buttons;   // SDL_GamepadButton values the pad has
        QVector<int> axes;      // SDL_GamepadAxis values the pad has
        QVector<double> values; // last reported, buttons then axes
    };

    void open(int deviceId);
    void close(int deviceId);

    bool valid_ = false;
    QHash<int, Pad> pads_;
    QHash<int, SDL_Joystick *> virtual_;
};

#endif // GAMEPADBACKEND_SDL_H
