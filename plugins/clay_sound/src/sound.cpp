// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sound.h"

#ifndef __EMSCRIPTEN__

Sound::Sound(QObject *parent)
    : SampleInstrument(parent)
{
    connect(this, &SampleInstrument::activeVoicesChanged,
            this, &Sound::onActiveVoicesChangedInternal);
    connect(this, &SampleInstrument::playbackFinished,
            this, &Sound::finished);
    connect(this, &SampleInstrument::errorStringChanged, this, [this]() {
        const QString msg = errorString();
        if (!msg.isEmpty())
            emit errorOccurred(msg);
        emit statusChanged();
    });
    connect(this, &SampleInstrument::loadedChanged, this, [this]() {
        emit statusChanged();
    });
}

void Sound::setLazyLoading(bool v)
{
    if (lazyLoading_ == v) return;
    lazyLoading_ = v;
    emit lazyLoadingChanged();
}

int Sound::status() const
{
    if (!errorString().isEmpty()) return 3; // Error
    if (loaded()) return 2;                 // Ready
    if (source().isEmpty()) return 0;       // Null
    return 1;                               // Loading
}

void Sound::onActiveVoicesChangedInternal()
{
    const bool nowPlaying = activeVoices() > 0;
    const bool wasPlaying = lastActive_ > 0;
    lastActive_ = activeVoices();
    if (nowPlaying != wasPlaying)
        emit playingChanged();
}

#endif // !__EMSCRIPTEN__
