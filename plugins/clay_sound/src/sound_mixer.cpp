// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sound_mixer.h"

#include "audio_output.h"

#include <algorithm>

namespace cs = clay::sound;

SoundMixer::SoundMixer(QObject *parent)
    : QObject(parent)
    , sfxEcho_(new EchoEffect(cs::Bus::Sfx, this))
    , musicEcho_(new EchoEffect(cs::Bus::Music, this))
    , voiceEcho_(new EchoEffect(cs::Bus::Voice, this))
    , sfxReverb_(new ReverbEffect(cs::Bus::Sfx, this))
    , musicReverb_(new ReverbEffect(cs::Bus::Music, this))
    , voiceReverb_(new ReverbEffect(cs::Bus::Voice, this))
{
}

qreal SoundMixer::volume(cs::Bus bus)
{
    return cs::AudioOutput::instance().engine().busGain(bus);
}

bool SoundMixer::setVolume(cs::Bus bus, qreal v)
{
    const float g = static_cast<float>(std::clamp(v, 0.0, 1.0));
    auto &out = cs::AudioOutput::instance();
    if (out.engine().busGain(bus) == g) return false;
    out.setBusGain(bus, g);
    return true;
}

void SoundMixer::setSfxVolume(qreal v)
{
    if (setVolume(cs::Bus::Sfx, v)) emit sfxVolumeChanged();
}

void SoundMixer::setMusicVolume(qreal v)
{
    if (setVolume(cs::Bus::Music, v)) emit musicVolumeChanged();
}

void SoundMixer::setVoiceVolume(qreal v)
{
    if (setVolume(cs::Bus::Voice, v)) emit voiceVolumeChanged();
}
