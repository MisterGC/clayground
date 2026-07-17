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

void ClayInputControl::setGamepadState(double axisX, double axisY,
                                       bool buttonA, bool buttonB,
                                       int durationMs)
{
    m_neutralTimer.stop();
    if (!m_active) {
        m_active = true;
        emit activeChanged();
    }
    m_axisX = axisX;
    m_axisY = axisY;
    m_buttonA = buttonA;
    m_buttonB = buttonB;
    emit stateChanged();
    if (durationMs > 0)
        m_neutralTimer.start(durationMs);
}

void ClayInputControl::resetToNeutral()
{
    m_axisX = 0.0;
    m_axisY = 0.0;
    m_buttonA = false;
    m_buttonB = false;
    emit stateChanged();
}
