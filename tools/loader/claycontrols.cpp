// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "claycontrols.h"

ClayTimeControl::ClayTimeControl(QObject* parent)
    : QObject(parent)
{
}

void ClayTimeControl::setTimeScale(double scale)
{
    if (qFuzzyCompare(m_timeScale, scale))
        return;
    m_timeScale = scale;
    emit timeScaleChanged();
}

void ClayTimeControl::setPaused(bool paused)
{
    if (m_paused == paused)
        return;
    m_paused = paused;
    emit pausedChanged();
}

int ClayTimeControl::requestStep(int frames)
{
    m_ackedFrames = 0;
    emit stepRequested(frames);
    return m_ackedFrames;
}

void ClayTimeControl::ackStep(int frames)
{
    m_ackedFrames += frames;
}

ClayInputControl::ClayInputControl(QObject* parent)
    : QObject(parent)
{
    m_neutralTimer.setSingleShot(true);
    connect(&m_neutralTimer, &QTimer::timeout,
            this, &ClayInputControl::resetToNeutral);
}

const QStringList& ClayInputControl::inputNames()
{
    static const QStringList names = {
        "axisX", "axisY", "axisRightX", "axisRightY",
        "buttonA", "buttonB", "buttonX", "buttonY",
        "buttonL1", "buttonR1", "triggerL2", "triggerR2",
        "buttonStart", "buttonSelect"};
    return names;
}

bool ClayInputControl::isButton(const QString& input)
{
    return input.startsWith(QLatin1String("button"));
}

QVariantMap ClayInputControl::neutral()
{
    QVariantMap state;
    for (const auto& name : inputNames())
        state[name] = isButton(name) ? QVariant(false) : QVariant(0.0);
    return state;
}

void ClayInputControl::setGamepadState(const QVariantMap& state,
                                       int durationMs)
{
    m_neutralTimer.stop();
    if (!m_active) {
        m_active = true;
        emit activeChanged();
    }
    m_gamepad = neutral();
    for (const auto& name : inputNames()) {
        if (!state.contains(name))
            continue;
        const auto v = state.value(name);
        m_gamepad[name] = isButton(name) ? QVariant(v.toBool())
                                         : QVariant(v.toDouble());
    }
    emit stateChanged();
    if (durationMs > 0)
        m_neutralTimer.start(durationMs);
}

void ClayInputControl::resetToNeutral()
{
    m_gamepad = neutral();
    emit stateChanged();
}
