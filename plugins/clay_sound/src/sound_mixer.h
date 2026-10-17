// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SoundMixer — QML singleton holding the volume of each bus of the
// shared engine: sfx, music and voice. An instrument picks its bus
// with its `bus` property; the bus volume scales everything mixed into
// it, on top of the instrument's own volume. The volumes live in the
// process-wide engine, so every QML engine in the process sees the
// same ones.

#ifndef CLAY_SOUND_SOUND_MIXER_H
#define CLAY_SOUND_SOUND_MIXER_H

#include "engine/bus.h"

#include <QObject>
#include <QQmlEngine>

class SoundMixer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(qreal sfxVolume   READ sfxVolume   WRITE setSfxVolume   NOTIFY sfxVolumeChanged)
    Q_PROPERTY(qreal musicVolume READ musicVolume WRITE setMusicVolume NOTIFY musicVolumeChanged)
    Q_PROPERTY(qreal voiceVolume READ voiceVolume WRITE setVoiceVolume NOTIFY voiceVolumeChanged)

public:
    explicit SoundMixer(QObject *parent = nullptr);

    qreal sfxVolume() const   { return volume(clay::sound::Bus::Sfx); }
    void  setSfxVolume(qreal v);
    qreal musicVolume() const { return volume(clay::sound::Bus::Music); }
    void  setMusicVolume(qreal v);
    qreal voiceVolume() const { return volume(clay::sound::Bus::Voice); }
    void  setVoiceVolume(qreal v);

signals:
    void sfxVolumeChanged();
    void musicVolumeChanged();
    void voiceVolumeChanged();

private:
    static qreal volume(clay::sound::Bus bus);
    // Clamps to [0, 1]; returns false when the bus already had `v`.
    static bool setVolume(clay::sound::Bus bus, qreal v);
};

#endif // CLAY_SOUND_SOUND_MIXER_H
