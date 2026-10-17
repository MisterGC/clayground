// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// EchoEffect, ReverbEffect — the QML face of one bus's echo and reverb
// (engine/bus_effects.h). SoundMixer owns one of each per bus, as
// sfxEcho, musicReverb and so on. The values live in the process-wide
// engine, like the bus volumes, so every QML engine sees the same.

#ifndef CLAY_SOUND_BUS_EFFECT_OBJECTS_H
#define CLAY_SOUND_BUS_EFFECT_OBJECTS_H

#include "engine/bus.h"

#include <QList>
#include <QObject>
#include <QQmlEngine>

namespace clay::sound { class Echo; class Reverb; }

class EchoEffect : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("EchoEffect is a bus's echo; use SoundMixer.sfxEcho, musicEcho or voiceEcho.")

    Q_PROPERTY(bool  enabled  READ enabled  WRITE setEnabled  NOTIFY enabledChanged)
    Q_PROPERTY(qreal delay    READ delay    WRITE setDelay    NOTIFY delayChanged)
    Q_PROPERTY(qreal feedback READ feedback WRITE setFeedback NOTIFY feedbackChanged)
    Q_PROPERTY(qreal volume   READ volume   WRITE setVolume   NOTIFY volumeChanged)
    Q_PROPERTY(QList<qreal> fir READ fir WRITE setFir NOTIFY firChanged)

public:
    EchoEffect(clay::sound::Bus bus, QObject *parent = nullptr);

    bool  enabled() const;
    void  setEnabled(bool on);
    qreal delay() const;                 // milliseconds
    void  setDelay(qreal ms);
    qreal feedback() const;
    void  setFeedback(qreal fb);
    qreal volume() const;
    void  setVolume(qreal v);
    QList<qreal> fir() const;            // always 8 taps
    // Fewer than 8 values leave the remaining taps 0; more are refused.
    void  setFir(const QList<qreal> &taps);

signals:
    void enabledChanged();
    void delayChanged();
    void feedbackChanged();
    void volumeChanged();
    void firChanged();

private:
    clay::sound::Echo &echo() const;
    clay::sound::Bus bus_;
};

class ReverbEffect : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("ReverbEffect is a bus's reverb; use SoundMixer.sfxReverb, musicReverb or voiceReverb.")

    Q_PROPERTY(bool  enabled  READ enabled  WRITE setEnabled  NOTIFY enabledChanged)
    Q_PROPERTY(qreal roomSize READ roomSize WRITE setRoomSize NOTIFY roomSizeChanged)
    Q_PROPERTY(qreal damping  READ damping  WRITE setDamping  NOTIFY dampingChanged)
    Q_PROPERTY(qreal volume   READ volume   WRITE setVolume   NOTIFY volumeChanged)

public:
    ReverbEffect(clay::sound::Bus bus, QObject *parent = nullptr);

    bool  enabled() const;
    void  setEnabled(bool on);
    qreal roomSize() const;
    void  setRoomSize(qreal r);
    qreal damping() const;
    void  setDamping(qreal d);
    qreal volume() const;
    void  setVolume(qreal v);

signals:
    void enabledChanged();
    void roomSizeChanged();
    void dampingChanged();
    void volumeChanged();

private:
    clay::sound::Reverb &reverb() const;
    clay::sound::Bus bus_;
};

#endif // CLAY_SOUND_BUS_EFFECT_OBJECTS_H
