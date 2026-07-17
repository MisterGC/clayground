// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QTimer>

// Exposed to QML as the context property ClayTimeCtrl. The Clayground
// singleton bridges it into Clayground.timeScale / Clayground.paused so
// sandboxes never talk to this type directly; worlds acknowledge consumed
// step requests so the inspector can tell "stepped" from "no world present".
class ClayTimeControl : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double timeScale READ timeScale WRITE setTimeScale NOTIFY timeScaleChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)

public:
    explicit ClayTimeControl(QObject* parent = nullptr);

    double timeScale() const { return m_timeScale; }
    void setTimeScale(double scale);
    bool paused() const { return m_paused; }
    void setPaused(bool paused);

    // Emits stepRequested and returns the number of frames acknowledged by
    // listening worlds (0 when no world consumed the request). Connections
    // are direct, so acknowledgement is complete when this returns.
    int requestStep(int frames);
    Q_INVOKABLE void ackStep(int frames);

signals:
    void timeScaleChanged();
    void pausedChanged();
    void stepRequested(int frames);

private:
    double m_timeScale = 1.0;
    bool m_paused = false;
    int m_ackedFrames = 0;
};

// Exposed to QML as the context property ClayInputCtrl. SyntheticGamepad
// (Clayground.GameController) mirrors this state into its GameController,
// writing imperatively just like KeyboardGamepad does — so human input and
// agent input coexist without binding fights.
class ClayInputControl : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(double axisX READ axisX NOTIFY stateChanged)
    Q_PROPERTY(double axisY READ axisY NOTIFY stateChanged)
    Q_PROPERTY(bool buttonA READ buttonA NOTIFY stateChanged)
    Q_PROPERTY(bool buttonB READ buttonB NOTIFY stateChanged)

public:
    explicit ClayInputControl(QObject* parent = nullptr);

    bool active() const { return m_active; }
    double axisX() const { return m_axisX; }
    double axisY() const { return m_axisY; }
    bool buttonA() const { return m_buttonA; }
    bool buttonB() const { return m_buttonB; }

    // durationMs > 0 resets to neutral (axes 0, buttons released) after the
    // given time — the "hold right for 600ms" primitive.
    void setGamepadState(double axisX, double axisY,
                         bool buttonA, bool buttonB, int durationMs = 0);
    void resetToNeutral();

signals:
    void activeChanged();
    void stateChanged();

private:
    bool m_active = false;
    double m_axisX = 0.0;
    double m_axisY = 0.0;
    bool m_buttonA = false;
    bool m_buttonB = false;
    QTimer m_neutralTimer;
};
