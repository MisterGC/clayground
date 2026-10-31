// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef GAMEPADBACKEND_BROWSER_H
#define GAMEPADBACKEND_BROWSER_H

#include "gamepadbackend.h"

#include <QHash>
#include <QList>
#include <QVector>

// One slot of navigator.getGamepads() as poll() reads it
struct BrowserPadState
{
    // False for an empty slot: a pad that went keeps its index free
    bool present = false;
    QString id;
    QString mapping;
    QVector<double> axes;
    // A button's analog value in [0, 1] and whether the browser calls it pressed
    QVector<double> buttonValues;
    QVector<bool> buttonPressed;
};

// Reads pads through the browser's Gamepad API: each poll() samples
// navigator.getGamepads() and reports what changed. A pad the browser maps
// to its standard gamepad ("mapping" is "standard") is read by the standard
// gamepad's button and axis indices; any other is read by them as well, and
// its type says "unmapped". The browser shows a pad to the page only after
// it was pressed with the page in front - until then there is none.
//
// Firefox is not read yet: it reports buttons pressed and a stick moved on an
// untouched pad (a Switch Pro Controller on macOS, Firefox 158), so a pad
// there is listed with type "unsupported" and no inputs, and drives nothing
// until #474 lifts that.
class BrowserGamepadBackend : public GamepadBackend
{
    Q_OBJECT

public:
    explicit BrowserGamepadBackend(QObject *parent = nullptr);

    QString name() const override { return QStringLiteral("browser"); }
    void poll() override;

    // Virtual pads take slots after the browser's, with the standard mapping
    int attachVirtual(const QString &name) override;
    bool detachVirtual(int deviceId) override;
    bool setVirtualInput(int deviceId, const QString &input, double value) override;

    // The name a person knows the pad by: Chrome appends
    // "(STANDARD GAMEPAD Vendor: 054c Product: 09cc)" to it, Firefox puts
    // "054c-09cc-" in front
    static QString padName(const QString &id);

protected:
    // The browser's slots, in order; empty where there is no Gamepad API.
    // poll() reports how they differ from the last ones.
    virtual QList<BrowserPadState> sample();

    // navigator.userAgent, read once, on the first poll()
    virtual QString userAgent() const;

private:
    struct Pad {
        int deviceId = -1;
        QString id;
        QStringList inputs;     // the names it reports, buttons then axes
        QVector<double> values; // last reported, in the order of inputs
    };

    void open(int slot, const BrowserPadState &state, int deviceId);
    void close(int slot);
    void read(Pad &pad, const BrowserPadState &state);

    // By slot: the browser's from 0, a virtual pad's at kVirtualSlot + deviceId
    QHash<int, Pad> pads_;
    QHash<int, BrowserPadState> virtual_; // by deviceId
    int nextDeviceId_ = 1;
    bool checkedBrowser_ = false;
    bool unsupported_ = false; // Firefox, see above
};

#endif // GAMEPADBACKEND_BROWSER_H
