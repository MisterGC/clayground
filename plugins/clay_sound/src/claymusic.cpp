// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claymusic.h"
#include <QDebug>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/val.h>
#include <map>

// Global registry for callback routing
static std::map<int, ClayMusic*> g_musicRegistry;
int ClayMusic::nextBufferId_ = 1000; // Start at 1000 to avoid collision with Sound

// JavaScript: Initialize audio context (shared with ClaySound)
EM_JS(void, js_music_init_audio_context, (), {
    if (!Module.clayAudioCtx) {
        Module.clayAudioCtx = new (window.AudioContext || window.webkitAudioContext)();
        Module.clayAudioBuffers = Module.clayAudioBuffers || {};
        Module.clayMusicInstances = {};
    }
    if (Module.clayAudioCtx.state === 'suspended') {
        Module.clayAudioCtx.resume();
    }
});

// JavaScript: Fetch and decode audio, return duration
EM_JS(void, js_music_load, (const char* url, int bufferId), {
    const urlStr = UTF8ToString(url);
    js_music_init_audio_context();

    fetch(urlStr)
        .then(response => {
            if (!response.ok) throw new Error('HTTP ' + response.status);
            return response.arrayBuffer();
        })
        .then(buffer => Module.clayAudioCtx.decodeAudioData(buffer))
        .then(audioBuffer => {
            Module.clayAudioBuffers[bufferId] = audioBuffer;
            const durationMs = Math.floor(audioBuffer.duration * 1000);
            Module._clay_music_load_complete(bufferId, 1, durationMs);
        })
        .catch(err => {
            console.error('Music load error:', urlStr, err);
            Module._clay_music_load_complete(bufferId, 0, 0);
        });
});

// JavaScript: Play music from offset
EM_JS(int, js_music_play, (int bufferId, float volume, int loop, double offsetSec), {
    js_music_init_audio_context();

    const buffer = Module.clayAudioBuffers[bufferId];
    if (!buffer) {
        console.error('Music buffer not found:', bufferId);
        return -1;
    }

    // Stop any existing instance for this buffer
    if (Module.clayMusicInstances && Module.clayMusicInstances[bufferId]) {
        try {
            Module.clayMusicInstances[bufferId].source.stop();
        } catch (e) {}
    }

    const ctx = Module.clayAudioCtx;
    const source = ctx.createBufferSource();
    const gainNode = ctx.createGain();

    source.buffer = buffer;
    source.loop = !!loop;
    gainNode.gain.value = volume;

    source.connect(gainNode);
    gainNode.connect(ctx.destination);

    const startOffset = Math.max(0, Math.min(offsetSec, buffer.duration));
    source.start(0, startOffset);

    Module.clayMusicInstances = Module.clayMusicInstances || {};
    Module.clayMusicInstances[bufferId] = {
        source,
        gainNode,
        startTime: ctx.currentTime - startOffset
    };

    source.onended = () => {
        if (Module.clayMusicInstances[bufferId] &&
            Module.clayMusicInstances[bufferId].source === source) {
            delete Module.clayMusicInstances[bufferId];
            Module._clay_music_playback_finished(bufferId);
        }
    };

    return bufferId;
});

// JavaScript: Pause music
EM_JS(double, js_music_pause, (int bufferId), {
    const instance = Module.clayMusicInstances ? Module.clayMusicInstances[bufferId] : null;
    if (!instance) return -1;

    const ctx = Module.clayAudioCtx;
    const elapsed = ctx.currentTime - instance.startTime;

    try {
        instance.source.stop();
    } catch (e) {}

    delete Module.clayMusicInstances[bufferId];
    return elapsed;
});

// JavaScript: Stop music
EM_JS(void, js_music_stop, (int bufferId), {
    const instance = Module.clayMusicInstances ? Module.clayMusicInstances[bufferId] : null;
    if (instance) {
        try {
            instance.source.stop();
        } catch (e) {}
        delete Module.clayMusicInstances[bufferId];
    }
});

// JavaScript: Set volume on playing music
EM_JS(void, js_music_set_volume, (int bufferId, float volume), {
    const instance = Module.clayMusicInstances ? Module.clayMusicInstances[bufferId] : null;
    if (instance && instance.gainNode) {
        instance.gainNode.gain.value = volume;
    }
});

// JavaScript: Get current position
EM_JS(double, js_music_get_position, (int bufferId), {
    const instance = Module.clayMusicInstances ? Module.clayMusicInstances[bufferId] : null;
    if (!instance) return -1;
    const ctx = Module.clayAudioCtx;
    return ctx.currentTime - instance.startTime;
});

// C callback: Music load completed
extern "C" EMSCRIPTEN_KEEPALIVE
void clay_music_load_complete(int bufferId, int success, int durationMs)
{
    auto it = g_musicRegistry.find(bufferId);
    if (it != g_musicRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [music = it->second, success, durationMs]() {
            music->onLoadComplete(success != 0, durationMs);
        }, Qt::QueuedConnection);
    }
}

// C callback: Playback finished
extern "C" EMSCRIPTEN_KEEPALIVE
void clay_music_playback_finished(int bufferId)
{
    auto it = g_musicRegistry.find(bufferId);
    if (it != g_musicRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [music = it->second]() {
            music->onPlaybackFinished();
        }, Qt::QueuedConnection);
    }
}
#endif // __EMSCRIPTEN__

ClayMusic::ClayMusic(QObject *parent)
    : QObject(parent)
{
#ifndef __EMSCRIPTEN__
    mediaPlayer_ = new QMediaPlayer(this);
    audioOutput_ = new QAudioOutput(this);
    mediaPlayer_->setAudioOutput(audioOutput_);

    connect(mediaPlayer_, &QMediaPlayer::mediaStatusChanged, this, [this](QMediaPlayer::MediaStatus status) {
        if (status == QMediaPlayer::LoadedMedia) {
            onLoadComplete(true, static_cast<int>(mediaPlayer_->duration()));
        } else if (status == QMediaPlayer::InvalidMedia) {
            onLoadComplete(false, 0);
        } else if (status == QMediaPlayer::EndOfMedia) {
            onPlaybackFinished();
        }
    });

    connect(mediaPlayer_, &QMediaPlayer::playbackStateChanged, this, [this](QMediaPlayer::PlaybackState state) {
        bool wasPlaying = playing_;
        bool wasPaused = paused_;

        playing_ = (state == QMediaPlayer::PlayingState);
        paused_ = (state == QMediaPlayer::PausedState);

        if (playing_ != wasPlaying) emit playingChanged();
        if (paused_ != wasPaused) emit pausedChanged();
    });

    connect(mediaPlayer_, &QMediaPlayer::positionChanged, this, [this](qint64 pos) {
        position_ = static_cast<int>(pos);
        emit positionChanged();
    });

    connect(mediaPlayer_, &QMediaPlayer::durationChanged, this, [this](qint64 dur) {
        duration_ = static_cast<int>(dur);
        emit durationChanged();
    });

    connect(mediaPlayer_, &QMediaPlayer::errorOccurred, this, [this](QMediaPlayer::Error error, const QString &errorString) {
        Q_UNUSED(error)
        emit errorOccurred(errorString);
    });
#endif
}

ClayMusic::~ClayMusic()
{
#ifdef __EMSCRIPTEN__
    if (bufferId_ >= 0) {
        js_music_stop(bufferId_);
        g_musicRegistry.erase(bufferId_);
    }
#endif
}

QUrl ClayMusic::source() const
{
    return source_;
}

void ClayMusic::setSource(const QUrl &url)
{
    if (source_ == url)
        return;

#ifdef __EMSCRIPTEN__
    // Stop and clean up previous
    if (bufferId_ >= 0) {
        js_music_stop(bufferId_);
        g_musicRegistry.erase(bufferId_);
        bufferId_ = -1;
    }
#else
    if (mediaPlayer_) {
        mediaPlayer_->stop();
    }
#endif

    source_ = url;
    loaded_ = false;
    playing_ = false;
    paused_ = false;
    position_ = 0;
    duration_ = 0;
    status_ = Null;

    emit sourceChanged();
    emit loadedChanged();
    emit playingChanged();
    emit pausedChanged();
    emit positionChanged();
    emit durationChanged();
    emit statusChanged();

    if (!lazyLoading_ && !source_.isEmpty()) {
        doLoad();
    }
}

qreal ClayMusic::volume() const
{
    return volume_;
}

void ClayMusic::setVolume(qreal vol)
{
    vol = qBound(0.0, vol, 1.0);
    if (qFuzzyCompare(volume_, vol))
        return;

    volume_ = vol;
    emit volumeChanged();

#ifdef __EMSCRIPTEN__
    // Update playing instance volume
    if (playing_ && bufferId_ >= 0) {
        js_music_set_volume(bufferId_, static_cast<float>(volume_));
    }
#else
    if (audioOutput_) {
        audioOutput_->setVolume(static_cast<float>(volume_));
    }
#endif
}

bool ClayMusic::lazyLoading() const
{
    return lazyLoading_;
}

void ClayMusic::setLazyLoading(bool lazy)
{
    if (lazyLoading_ == lazy)
        return;

    lazyLoading_ = lazy;
    emit lazyLoadingChanged();
}

bool ClayMusic::loaded() const
{
    return loaded_;
}

bool ClayMusic::playing() const
{
    return playing_;
}

bool ClayMusic::paused() const
{
    return paused_;
}

bool ClayMusic::loop() const
{
    return loop_;
}

void ClayMusic::setLoop(bool loop)
{
    if (loop_ == loop)
        return;

    loop_ = loop;
    emit loopChanged();

#ifndef __EMSCRIPTEN__
    if (mediaPlayer_) {
        mediaPlayer_->setLoops(loop_ ? QMediaPlayer::Infinite : 1);
    }
#endif
    // Note: For WASM, can't change loop on playing source in Web Audio,
    // would need to restart. For simplicity, only applies on next play.
}

int ClayMusic::position() const
{
    return position_;
}

int ClayMusic::duration() const
{
    return duration_;
}

ClayMusic::Status ClayMusic::status() const
{
    return status_;
}

void ClayMusic::play()
{
    if (!loaded_) {
        if (status_ == Null && !source_.isEmpty()) {
            doLoad();
            connect(this, &ClayMusic::loadedChanged, this, [this]() {
                if (loaded_) {
                    disconnect(this, &ClayMusic::loadedChanged, this, nullptr);
                    play();
                }
            }, Qt::SingleShotConnection);
        }
        return;
    }

#ifdef __EMSCRIPTEN__
    double offsetSec = paused_ ? (pauseTime_ / 1000.0) : 0;

    instanceId_ = js_music_play(bufferId_, static_cast<float>(volume_), loop_ ? 1 : 0, offsetSec);

    if (instanceId_ >= 0) {
        playing_ = true;
        paused_ = false;
        emit playingChanged();
        emit pausedChanged();
    }
#else
    if (mediaPlayer_) {
        mediaPlayer_->play();
    }
#endif
}

void ClayMusic::pause()
{
#ifdef __EMSCRIPTEN__
    if (!playing_ || bufferId_ < 0)
        return;

    double elapsed = js_music_pause(bufferId_);
    if (elapsed >= 0) {
        pauseTime_ = elapsed * 1000.0;
        position_ = static_cast<int>(pauseTime_);
        playing_ = false;
        paused_ = true;
        emit playingChanged();
        emit pausedChanged();
        emit positionChanged();
    }
#else
    if (mediaPlayer_) {
        mediaPlayer_->pause();
    }
#endif
}

void ClayMusic::stop()
{
#ifdef __EMSCRIPTEN__
    if (bufferId_ >= 0) {
        js_music_stop(bufferId_);
    }

    playing_ = false;
    paused_ = false;
    position_ = 0;
    pauseTime_ = 0;

    emit playingChanged();
    emit pausedChanged();
    emit positionChanged();
#else
    if (mediaPlayer_) {
        mediaPlayer_->stop();
    }
#endif
}

void ClayMusic::seek(int ms)
{
    if (!loaded_)
        return;

    ms = qBound(0, ms, duration_);

#ifdef __EMSCRIPTEN__
    if (bufferId_ < 0)
        return;

    if (playing_) {
        // Stop and restart at new position
        js_music_stop(bufferId_);
        js_music_play(bufferId_, static_cast<float>(volume_), loop_ ? 1 : 0, ms / 1000.0);
    } else {
        pauseTime_ = ms;
    }

    position_ = ms;
    emit positionChanged();
#else
    if (mediaPlayer_) {
        mediaPlayer_->setPosition(ms);
    }
#endif
}

void ClayMusic::load()
{
    if (status_ == Loading || loaded_)
        return;

    if (!source_.isEmpty()) {
        doLoad();
    }
}

void ClayMusic::doLoad()
{
    if (source_.isEmpty())
        return;

    status_ = Loading;
    emit statusChanged();

#ifdef __EMSCRIPTEN__
    bufferId_ = nextBufferId_++;
    g_musicRegistry[bufferId_] = this;

    // Resolve relative URL against QML context base URL
    QUrl resolvedUrl = source_;
    if (source_.isRelative()) {
        QQmlContext* context = QQmlEngine::contextForObject(this);
        if (context) {
            resolvedUrl = context->resolvedUrl(source_);
        }
    }
    QByteArray urlBytes = resolvedUrl.toString().toUtf8();
    js_music_load(urlBytes.constData(), bufferId_);
#else
    if (mediaPlayer_) {
        mediaPlayer_->setSource(source_);
        mediaPlayer_->setLoops(loop_ ? QMediaPlayer::Infinite : 1);
        if (audioOutput_) {
            audioOutput_->setVolume(static_cast<float>(volume_));
        }
    }
#endif
}

void ClayMusic::onLoadComplete(bool success, int durationMs)
{
    if (success) {
        loaded_ = true;
        duration_ = durationMs;
        status_ = Ready;
        emit loadedChanged();
        emit durationChanged();
        emit statusChanged();
    } else {
        status_ = Error;
        emit statusChanged();
        emit errorOccurred(QStringLiteral("Failed to load music: %1").arg(source_.toString()));
    }
}

void ClayMusic::onPlaybackFinished()
{
    if (!loop_) {
        playing_ = false;
        paused_ = false;
        position_ = 0;
        emit playingChanged();
        emit pausedChanged();
        emit positionChanged();
        emit finished();
    }
}
