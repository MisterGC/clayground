// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SoundMixer — QML singleton holding the volume of each bus of the
// shared engine: sfx, music and voice. An instrument picks its bus
// with its `bus` property; the bus volume scales everything mixed into
// it, on top of the instrument's own volume. The volumes live in the
// process-wide engine, so every QML engine in the process sees the
// same ones.
//
// Each bus also has an echo and a reverb (sfxEcho, musicReverb, ...),
// off by default; see bus_effect_objects.h.

#ifndef CLAY_SOUND_SOUND_MIXER_H
#define CLAY_SOUND_SOUND_MIXER_H

#include "bus_effect_objects.h"
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
    Q_PROPERTY(EchoEffect *sfxEcho     READ sfxEcho     CONSTANT)
    Q_PROPERTY(EchoEffect *musicEcho   READ musicEcho   CONSTANT)
    Q_PROPERTY(EchoEffect *voiceEcho   READ voiceEcho   CONSTANT)
    Q_PROPERTY(ReverbEffect *sfxReverb   READ sfxReverb   CONSTANT)
    Q_PROPERTY(ReverbEffect *musicReverb READ musicReverb CONSTANT)
    Q_PROPERTY(ReverbEffect *voiceReverb READ voiceReverb CONSTANT)

public:
    explicit SoundMixer(QObject *parent = nullptr);

    qreal sfxVolume() const   { return volume(clay::sound::Bus::Sfx); }
    void  setSfxVolume(qreal v);
    qreal musicVolume() const { return volume(clay::sound::Bus::Music); }
    void  setMusicVolume(qreal v);
    qreal voiceVolume() const { return volume(clay::sound::Bus::Voice); }
    void  setVoiceVolume(qreal v);

    EchoEffect *sfxEcho() const   { return sfxEcho_; }
    EchoEffect *musicEcho() const { return musicEcho_; }
    EchoEffect *voiceEcho() const { return voiceEcho_; }
    ReverbEffect *sfxReverb() const   { return sfxReverb_; }
    ReverbEffect *musicReverb() const { return musicReverb_; }
    ReverbEffect *voiceReverb() const { return voiceReverb_; }

signals:
    void sfxVolumeChanged();
    void musicVolumeChanged();
    void voiceVolumeChanged();

private:
    static qreal volume(clay::sound::Bus bus);
    // Clamps to [0, 1]; returns false when the bus already had `v`.
    static bool setVolume(clay::sound::Bus bus, qreal v);

    EchoEffect *sfxEcho_;
    EchoEffect *musicEcho_;
    EchoEffect *voiceEcho_;
    ReverbEffect *sfxReverb_;
    ReverbEffect *musicReverb_;
    ReverbEffect *voiceReverb_;
};

#endif // CLAY_SOUND_SOUND_MIXER_H
