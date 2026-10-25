// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef GAMEPADHUB_H
#define GAMEPADHUB_H

#include "gamepadbackend.h"

#include <QList>
#include <QObject>
#include <QQmlEngine>
#include <QTimer>

// One connected physical pad as QML sees it: what it is, which buttons and
// axes it has and their live values. Reached through GameController.gamepads
// and GameController.gamepad; never created in QML.
class ClayGamepad : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int deviceId READ deviceId CONSTANT)
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString type READ type CONSTANT)
    Q_PROPERTY(QStringList buttons READ buttons CONSTANT)
    Q_PROPERTY(QStringList axes READ axes CONSTANT)
    Q_PROPERTY(QVariantMap labels READ labels CONSTANT)
    Q_PROPERTY(QVariantMap values READ values NOTIFY valuesChanged)

public:
    ClayGamepad(const GamepadInfo &info, QObject *parent);

    int deviceId() const { return info_.deviceId; }
    QString name() const { return info_.name; }
    QString type() const { return info_.type; }
    QStringList buttons() const { return info_.buttons; }
    QStringList axes() const { return info_.axes; }
    QVariantMap labels() const { return info_.labels; }
    QVariantMap values() const { return values_; }

    // The value of a button (bool) or an axis (number); a name the pad lacks
    // reads neutral
    Q_INVOKABLE QVariant value(const QString &input) const;

    void setValue(const QString &input, double value);

signals:
    void valuesChanged();

private:
    GamepadInfo info_;
    QVariantMap values_;
};

// The physical pads connected to the machine, read by one backend from a
// timer. Internal to the GameController module: games use
// GameController.gamepads, numConnectedGamepads and selectGamepad(). One
// instance per process, shared by every QML engine.
class GamepadHub : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(GamepadHub)
    QML_SINGLETON

    Q_PROPERTY(QString backend READ backend CONSTANT)
    Q_PROPERTY(QList<QObject *> gamepads READ gamepads NOTIFY gamepadsChanged)
    Q_PROPERTY(int count READ count NOTIFY gamepadsChanged)

public:
    static GamepadHub *instance();
    static GamepadHub *create(QQmlEngine *, QJSEngine *);

    // The backend's name, "none" where this build reads no pads
    QString backend() const;
    QList<QObject *> gamepads() const;
    int count() const { return int(pads_.size()); }

    // The pad with that deviceId, null when it is not connected
    Q_INVOKABLE QObject *gamepad(int deviceId) const;

    // A pad that exists only in software, for tests: plugged in by
    // attachVirtualGamepad() (its deviceId, -1 where the backend has none),
    // driven input by input with the names a ClayGamepad reports, unplugged by
    // detachVirtualGamepad(). Each takes effect before it returns.
    Q_INVOKABLE int attachVirtualGamepad(const QString &name);
    Q_INVOKABLE bool setVirtualGamepadInput(int deviceId, const QString &input, double value);
    Q_INVOKABLE bool detachVirtualGamepad(int deviceId);

    // Reads the backend now rather than at the next tick
    Q_INVOKABLE void poll();

signals:
    void gamepadsChanged();
    void gamepadRemoved(int deviceId);

private:
    explicit GamepadHub(QObject *parent = nullptr);

    void onPadAdded(const GamepadInfo &info);
    void onPadRemoved(int deviceId);
    void onInputChanged(int deviceId, const QString &input, double value);

    GamepadBackend *backend_ = nullptr;
    QList<ClayGamepad *> pads_;
    QTimer timer_;
};

#endif // GAMEPADHUB_H
