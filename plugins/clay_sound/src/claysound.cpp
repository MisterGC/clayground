// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "claysound.h"
#include <QDebug>
#include <emscripten.h>
#include <emscripten/val.h>
#include <map>

// Global registry for callback routing
static std::map<int, ClaySound*> g_soundRegistry;
int ClaySound::nextBufferId_ = 0;

// JavaScript: Initialize audio context (lazily on first use)
EM_JS(void, js_init_audio_context, (), {
    if (!Module.clayAudioCtx) {
        Module.clayAudioCtx = new (window.AudioContext || window.webkitAudioContext)();
        Module.clayAudioBuffers = {};
        Module.clayAudioInstances = {};
        Module.clayNextInstanceId = 0;
    }
    // Resume if suspended (browser autoplay policy)
    if (Module.clayAudioCtx.state === 'suspended') {
        Module.clayAudioCtx.resume();
    }
});

// JavaScript: Fetch and decode audio from URL
EM_JS(void, js_load_audio, (const char* url, int bufferId), {
    const urlStr = UTF8ToString(url);
    js_init_audio_context();

    fetch(urlStr)
        .then(response => {
            if (!response.ok) throw new Error('HTTP ' + response.status);
            return response.arrayBuffer();
        })
        .then(buffer => Module.clayAudioCtx.decodeAudioData(buffer))
        .then(audioBuffer => {
            Module.clayAudioBuffers[bufferId] = audioBuffer;
            Module._clay_sound_load_complete(bufferId, 1);
        })
        .catch(err => {
            console.error('Audio load error:', urlStr, err);
            Module._clay_sound_load_complete(bufferId, 0);
        });
});

// JavaScript: Play a loaded audio buffer
EM_JS(int, js_play_audio, (int bufferId, float volume, int loop), {
    js_init_audio_context();

    const buffer = Module.clayAudioBuffers[bufferId];
    if (!buffer) {
        console.error('Audio buffer not found:', bufferId);
        return -1;
    }

    const ctx = Module.clayAudioCtx;
    const source = ctx.createBufferSource();
    const gainNode = ctx.createGain();

    source.buffer = buffer;
    source.loop = !!loop;
    gainNode.gain.value = volume;

    source.connect(gainNode);
    gainNode.connect(ctx.destination);
    source.start(0);

    const instanceId = Module.clayNextInstanceId++;
    Module.clayAudioInstances[instanceId] = { source, gainNode, bufferId };

    source.onended = () => {
        delete Module.clayAudioInstances[instanceId];
        Module._clay_sound_playback_finished(bufferId, instanceId);
    };

    return instanceId;
});

// JavaScript: Stop a playing instance
EM_JS(void, js_stop_audio, (int instanceId), {
    const instance = Module.clayAudioInstances ? Module.clayAudioInstances[instanceId] : null;
    if (instance) {
        try {
            instance.source.stop();
        } catch (e) {
            // Already stopped
        }
        delete Module.clayAudioInstances[instanceId];
    }
});

// JavaScript: Stop all instances of a buffer
EM_JS(void, js_stop_all_audio, (int bufferId), {
    if (!Module.clayAudioInstances) return;
    const toStop = [];
    for (const id in Module.clayAudioInstances) {
        if (Module.clayAudioInstances[id].bufferId === bufferId) {
            toStop.push(parseInt(id));
        }
    }
    toStop.forEach(id => {
        try {
            Module.clayAudioInstances[id].source.stop();
        } catch (e) {}
        delete Module.clayAudioInstances[id];
    });
});

// C callback: Audio load completed
extern "C" EMSCRIPTEN_KEEPALIVE
void clay_sound_load_complete(int bufferId, int success)
{
    auto it = g_soundRegistry.find(bufferId);
    if (it != g_soundRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [sound = it->second, success]() {
            sound->onLoadComplete(success != 0);
        }, Qt::QueuedConnection);
    }
}

// C callback: Playback finished
extern "C" EMSCRIPTEN_KEEPALIVE
void clay_sound_playback_finished(int bufferId, int instanceId)
{
    auto it = g_soundRegistry.find(bufferId);
    if (it != g_soundRegistry.end()) {
        QMetaObject::invokeMethod(it->second, [sound = it->second, instanceId]() {
            sound->onPlaybackFinished(instanceId);
        }, Qt::QueuedConnection);
    }
}

ClaySound::ClaySound(QObject *parent)
    : QObject(parent)
{
}

ClaySound::~ClaySound()
{
    if (bufferId_ >= 0) {
        js_stop_all_audio(bufferId_);
        g_soundRegistry.erase(bufferId_);
    }
}

QUrl ClaySound::source() const
{
    return source_;
}

void ClaySound::setSource(const QUrl &url)
{
    if (source_ == url)
        return;

    // Clean up previous buffer
    if (bufferId_ >= 0) {
        js_stop_all_audio(bufferId_);
        g_soundRegistry.erase(bufferId_);
        bufferId_ = -1;
    }

    source_ = url;
    loaded_ = false;
    status_ = Null;

    emit sourceChanged();
    emit loadedChanged();
    emit statusChanged();

    if (!lazyLoading_ && !source_.isEmpty()) {
        doLoad();
    }
}

qreal ClaySound::volume() const
{
    return volume_;
}

void ClaySound::setVolume(qreal vol)
{
    vol = qBound(0.0, vol, 1.0);
    if (qFuzzyCompare(volume_, vol))
        return;

    volume_ = vol;
    emit volumeChanged();
}

bool ClaySound::lazyLoading() const
{
    return lazyLoading_;
}

void ClaySound::setLazyLoading(bool lazy)
{
    if (lazyLoading_ == lazy)
        return;

    lazyLoading_ = lazy;
    emit lazyLoadingChanged();
}

bool ClaySound::loaded() const
{
    return loaded_;
}

ClaySound::Status ClaySound::status() const
{
    return status_;
}

void ClaySound::play()
{
    if (!loaded_) {
        if (status_ == Null && !source_.isEmpty()) {
            // Lazy load then play
            doLoad();
            // Will play after load completes - queue the play request
            connect(this, &ClaySound::loadedChanged, this, [this]() {
                if (loaded_) {
                    disconnect(this, &ClaySound::loadedChanged, this, nullptr);
                    play();
                }
            }, Qt::SingleShotConnection);
        }
        return;
    }

    int instanceId = js_play_audio(bufferId_, static_cast<float>(volume_), 0);
    if (instanceId >= 0) {
        activeInstances_.append(instanceId);
    }
}

void ClaySound::stop()
{
    if (bufferId_ >= 0) {
        js_stop_all_audio(bufferId_);
        activeInstances_.clear();
    }
}

void ClaySound::load()
{
    if (status_ == Loading || loaded_)
        return;

    if (!source_.isEmpty()) {
        doLoad();
    }
}

void ClaySound::doLoad()
{
    if (source_.isEmpty())
        return;

    bufferId_ = nextBufferId_++;
    g_soundRegistry[bufferId_] = this;

    status_ = Loading;
    emit statusChanged();

    QByteArray urlBytes = source_.toString().toUtf8();
    js_load_audio(urlBytes.constData(), bufferId_);
}

void ClaySound::onLoadComplete(bool success)
{
    if (success) {
        loaded_ = true;
        status_ = Ready;
        emit loadedChanged();
        emit statusChanged();
    } else {
        status_ = Error;
        emit statusChanged();
        emit errorOccurred(QStringLiteral("Failed to load audio: %1").arg(source_.toString()));
    }
}

void ClaySound::onPlaybackFinished(int instanceId)
{
    activeInstances_.removeOne(instanceId);
    emit finished();
}
