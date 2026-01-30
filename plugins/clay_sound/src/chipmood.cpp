// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "chipmood.h"
#include <QDebug>

#ifdef EMSCRIPTEN
#include <emscripten.h>

// Initialize ChipMood audio engine
EM_JS(void, js_chipmood_init, (int instanceId), {
    if (!Module.chipMoodInstances) Module.chipMoodInstances = {};
    if (Module.chipMoodInstances[instanceId]) return;

    const SCALES = {
        dorian: [0, 2, 3, 5, 7, 9, 10],
        minor: [0, 2, 3, 5, 7, 8, 10],
        phrygian: [0, 1, 3, 5, 7, 8, 10],
        major: [0, 2, 4, 5, 7, 9, 11],
        pentatonic: [0, 2, 4, 7, 9]
    };

    const MOODS = {
        mysterious_forest: {
            scale: 'dorian', root: 51, tempo: 85,
            sections: [
                { bars: 16, rootOffset: 0, layers: [0,1,2,3] },  // A: Full, tonic (i)
                { bars: 16, rootOffset: 5, layers: [0,2,3] },    // B: No melody, V
                { bars: 16, rootOffset: 0, layers: [0,1,2,3] },  // A': Full again
                { bars: 8,  rootOffset: 3, layers: [1,2] }       // C: Sparse, III
            ],
            layers: [
                // Arpeggio - 32 steps for 8-bar phrase
                { wave: 'triangle', octave: 1, pattern: [
                    0,2,4,6, 0,2,4,7, 0,2,5,6, 0,2,4,6,
                    0,2,4,6, 1,3,5,6, 0,2,4,6, 0,2,4,7
                ], rhythm: 0.25, volume: 0.3 },
                // Melody - 32 steps evolving phrase
                { wave: 'sine', octave: 0, pattern: [
                    4,3,2,1, 2,-1,-1,-1, 4,5,4,3, 2,-1,-1,-1,
                    2,3,4,5, 6,-1,-1,-1, 4,3,2,1, 0,-1,-1,-1
                ], rhythm: 0.5, volume: 0.25 },
                // Pad - sustained drone
                { wave: 'sine', octave: -1, pattern: [0,-1,-1,-1, 0,-1,-1,-1], rhythm: 4, volume: 0.15 },
                // Bass - 16-step groove
                { wave: 'triangle', octave: -2, pattern: [
                    0,-1,0,-1, 2,-1,0,-1, 0,-1,0,-1, 4,-1,2,-1
                ], rhythm: 0.5, volume: 0.2 }
            ],
            echo: 0.3, warmth: 0.6
        },
        dark_dungeon: {
            scale: 'phrygian', root: 48, tempo: 100,
            sections: [
                { bars: 16, rootOffset: 0, layers: [0,2,3] },    // A: Tense, no melody
                { bars: 16, rootOffset: 1, layers: [0,1,2,3] },  // B: Full, bII (dissonant)
                { bars: 16, rootOffset: 0, layers: [0,2,3] },    // A': Back to tense
                { bars: 16, rootOffset: 5, layers: [0,1,2] }     // C: V chord, ominous
            ],
            layers: [
                // Pulsing bass - 32 steps (triangle at -1 for speaker-friendly freq)
                { wave: 'triangle', octave: -1, pattern: [
                    0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,2,0,
                    0,0,1,0, 0,0,1,0, 0,0,3,0, 0,0,1,0
                ], rhythm: 0.25, volume: 0.25 },
                // Melody - sparse, tense
                { wave: 'square', octave: 0, pattern: [
                    0,-1,1,-1, 0,-1,-1,-1, -1,-1,2,-1, 1,-1,-1,-1,
                    0,-1,1,-1, 2,-1,-1,-1, 1,-1,0,-1, -1,-1,-1,-1
                ], rhythm: 0.5, volume: 0.15 },
                // Percussion hits
                { wave: 'noise', pattern: [
                    1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,1,0,
                    1,0,0,0, 1,0,0,0, 1,0,1,0, 1,0,0,0
                ], rhythm: 0.25, volume: 0.1 },
                // Drone pad
                { wave: 'sine', octave: -1, pattern: [0,-1,-1,-1, 0,-1,-1,-1], rhythm: 2, volume: 0.12 }
            ],
            echo: 0.4, warmth: 0.7
        },
        peaceful_village: {
            scale: 'major', root: 55, tempo: 95,
            sections: [
                { bars: 12, rootOffset: 0, layers: [0,1,2,3] },  // A: Full, I
                { bars: 12, rootOffset: 5, layers: [0,2,3] },    // B: V chord, lighter
                { bars: 12, rootOffset: 0, layers: [0,1,2,3] },  // A': Full again
                { bars: 12, rootOffset: 3, layers: [0,1,2] }     // C: IV chord, warm
            ],
            layers: [
                // Bright arpeggio - 32 steps
                { wave: 'triangle', octave: 1, pattern: [
                    0,2,4,2, 0,2,4,5, 0,2,4,2, 0,4,2,0,
                    0,2,4,2, 0,2,5,4, 0,2,4,2, 4,2,0,-1
                ], rhythm: 0.25, volume: 0.25 },
                // Simple melody - folk-like
                { wave: 'sine', octave: 0, pattern: [
                    4,2,0,2, 4,4,4,-1, 5,4,2,4, 5,5,5,-1,
                    4,4,5,5, 4,4,2,-1, 0,2,4,2, 0,-1,-1,-1
                ], rhythm: 0.5, volume: 0.3 },
                // Walking bass
                { wave: 'triangle', octave: -2, pattern: [
                    0,-1,4,-1, 0,-1,4,-1, 2,-1,4,-1, 0,-1,2,-1
                ], rhythm: 0.5, volume: 0.2 },
                // Sustained harmony
                { wave: 'sine', octave: -1, pattern: [0,4, 0,4, 2,4, 0,4], rhythm: 2, volume: 0.1 }
            ],
            echo: 0.2, warmth: 0.5
        }
    };

    const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const masterGain = audioCtx.createGain();
    masterGain.gain.value = 0.7;

    const lowpass = audioCtx.createBiquadFilter();
    lowpass.type = 'lowpass';
    lowpass.frequency.value = 8000;

    const echoDelay = audioCtx.createDelay(1.0);
    echoDelay.delayTime.value = 0.15;
    const echoGain = audioCtx.createGain();
    echoGain.gain.value = 0.3;

    lowpass.connect(masterGain);
    masterGain.connect(audioCtx.destination);
    masterGain.connect(echoDelay);
    echoDelay.connect(echoGain);
    echoGain.connect(lowpass);

    function midiToFreq(m) { return 440 * Math.pow(2, (m - 69) / 12); }

    function getScaleNote(scaleName, degree, root, octaveOffset) {
        const scale = SCALES[scaleName];
        const oct = Math.floor(degree / scale.length);
        const note = ((degree % scale.length) + scale.length) % scale.length;
        return midiToFreq(root + scale[note] + oct * 12 + octaveOffset * 12);
    }

    function playNote(freq, wave, vol, dur, startTime) {
        const gain = audioCtx.createGain();
        gain.connect(lowpass);

        if (wave === 'noise') {
            const bufSize = Math.floor(audioCtx.sampleRate * dur);
            const buf = audioCtx.createBuffer(1, bufSize, audioCtx.sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = audioCtx.createBufferSource();
            noise.buffer = buf;
            const bp = audioCtx.createBiquadFilter();
            bp.type = 'bandpass'; bp.frequency.value = 1000;
            noise.connect(bp); bp.connect(gain);
            gain.gain.setValueAtTime(vol, startTime);
            gain.gain.exponentialRampToValueAtTime(0.001, startTime + dur * 0.8);
            noise.start(startTime); noise.stop(startTime + dur);
            return;
        }

        const osc = audioCtx.createOscillator();
        osc.type = wave; osc.frequency.value = freq;
        osc.connect(gain);
        gain.gain.setValueAtTime(0, startTime);
        gain.gain.linearRampToValueAtTime(vol, startTime + 0.01);
        gain.gain.linearRampToValueAtTime(vol * 0.6, startTime + 0.11);
        gain.gain.setValueAtTime(vol * 0.6, startTime + dur * 0.7);
        gain.gain.exponentialRampToValueAtTime(0.001, startTime + dur);
        osc.start(startTime); osc.stop(startTime + dur + 0.1);
    }

    Module.chipMoodInstances[instanceId] = {
        audioCtx, masterGain, lowpass, echoDelay, echoGain,
        SCALES, MOODS, midiToFreq, getScaleNote, playNote,
        currentMood: 'mysterious_forest',
        tempo: 85, intensity: 0.5, volume: 0.7,
        octaveShift: 0, swing: 0, variation: 0,
        isPlaying: false, schedulerTimer: null,
        nextNoteTime: 0, currentStep: 0,
        // Section tracking for longer loops
        currentSection: 0,
        currentBeat: 0,
        beatsPerBar: 4
    };
});

// Set mood
EM_JS(int, js_chipmood_set_mood, (int instanceId, const char* moodName), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst) return 0;
    const mood = UTF8ToString(moodName);
    if (!inst.MOODS[mood]) return 0;
    inst.currentMood = mood;
    inst.tempo = inst.MOODS[mood].tempo;
    inst.echoGain.gain.value = inst.MOODS[mood].echo;
    inst.lowpass.frequency.value = 4000 + (1 - inst.MOODS[mood].warmth) * 12000;
    // Reset section tracking
    inst.currentSection = 0;
    inst.currentBeat = 0;
    return inst.tempo;
});

// Set volume
EM_JS(void, js_chipmood_set_volume, (int instanceId, double volume), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (inst) inst.masterGain.gain.value = Math.max(0, Math.min(1, volume));
});

// Set intensity
EM_JS(void, js_chipmood_set_intensity, (int instanceId, double intensity), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (inst) inst.intensity = Math.max(0, Math.min(1, intensity));
});

// Set tempo
EM_JS(void, js_chipmood_set_tempo, (int instanceId, int tempo), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (inst) inst.tempo = Math.max(60, Math.min(180, tempo));
});

// Set octave shift
EM_JS(void, js_chipmood_set_octave_shift, (int instanceId, int shift), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (inst) inst.octaveShift = Math.max(-2, Math.min(2, shift));
});

// Set swing (0-1)
EM_JS(void, js_chipmood_set_swing, (int instanceId, double swing), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (inst) inst.swing = Math.max(0, Math.min(1, swing));
});

// Set variation (0-1)
EM_JS(void, js_chipmood_set_variation, (int instanceId, double variation), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (inst) inst.variation = Math.max(0, Math.min(1, variation));
});

// Randomize patterns
EM_JS(void, js_chipmood_randomize, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst) return;
    const mood = inst.MOODS[inst.currentMood];
    // Slight tempo variation
    inst.tempo = mood.tempo + Math.floor((Math.random() - 0.5) * 20);
    // Jump to random section and position
    const sections = mood.sections || [{ bars: 16 }];
    inst.currentSection = Math.floor(Math.random() * sections.length);
    inst.currentBeat = Math.floor(Math.random() * 8);
    inst.currentStep = Math.floor(Math.random() * 32);
});

// Play
EM_JS(void, js_chipmood_play, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst) return;

    if (inst.audioCtx.state === 'suspended') inst.audioCtx.resume();

    inst.isPlaying = true;
    inst.currentStep = 0;
    inst.currentSection = 0;
    inst.currentBeat = 0;
    inst.nextNoteTime = inst.audioCtx.currentTime;

    function scheduler() {
        if (!inst.isPlaying) return;
        const mood = inst.MOODS[inst.currentMood];
        const sections = mood.sections || [{ bars: 16, rootOffset: 0, layers: [0,1,2,3] }];

        while (inst.nextNoteTime < inst.audioCtx.currentTime + 0.1) {
            const section = sections[inst.currentSection];
            const rootOffset = section.rootOffset || 0;
            const activeLayers = section.layers || [0,1,2,3];

            const isOffbeat = (inst.currentStep % 2) === 1;
            const swingOffset = isOffbeat ? inst.swing * 0.1 * (60 / inst.tempo) : 0;

            mood.layers.forEach((layer, i) => {
                // Check if layer is active in current section
                if (!activeLayers.includes(i)) return;
                // Apply intensity filtering
                if (inst.intensity < 0.3 && i > 1) return;
                if (inst.intensity < 0.6 && i > 2) return;

                const step = Math.floor(inst.currentStep / (layer.rhythm / 0.25));
                let noteVal = layer.pattern[step % layer.pattern.length];
                if (noteVal === -1) return;

                // Apply variation - occasionally shift notes
                if (inst.variation > 0 && Math.random() < inst.variation * 0.3) {
                    noteVal += Math.floor((Math.random() - 0.5) * 4);
                }

                const dur = layer.rhythm * (60 / inst.tempo) * 0.9;
                const vol = layer.volume * (0.5 + inst.intensity * 0.5) * inst.masterGain.gain.value;
                const noteTime = inst.nextNoteTime + swingOffset;

                if (layer.wave === 'noise') {
                    inst.playNote(0, 'noise', vol * (noteVal > 0 ? 1 : 0), dur, noteTime);
                } else {
                    const octave = layer.octave + inst.octaveShift;
                    // Apply section's rootOffset to the root note
                    const sectionRoot = mood.root + rootOffset;
                    inst.playNote(inst.getScaleNote(mood.scale, noteVal, sectionRoot, octave), layer.wave, vol, dur, noteTime);
                }
            });

            inst.nextNoteTime += 0.25 * (60 / inst.tempo);
            inst.currentStep++;
            inst.currentBeat += 0.25;

            // Check if we've completed the current section
            const sectionBeats = section.bars * inst.beatsPerBar;
            if (inst.currentBeat >= sectionBeats) {
                inst.currentBeat = 0;
                inst.currentSection = (inst.currentSection + 1) % sections.length;
            }
        }
        inst.schedulerTimer = setTimeout(scheduler, 25);
    }
    scheduler();
});

// Stop
EM_JS(void, js_chipmood_stop, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst) return;
    inst.isPlaying = false;
    if (inst.schedulerTimer) {
        clearTimeout(inst.schedulerTimer);
        inst.schedulerTimer = null;
    }
});

// Check if playing
EM_JS(int, js_chipmood_is_playing, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    return inst?.isPlaying ? 1 : 0;
});

// Get current section index
EM_JS(int, js_chipmood_get_section, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    return inst ? inst.currentSection : 0;
});

// Get total sections count
EM_JS(int, js_chipmood_get_total_sections, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst) return 4;
    const mood = inst.MOODS[inst.currentMood];
    const sections = mood.sections || [{ bars: 16 }];
    return sections.length;
});

// Get section progress (0.0-1.0)
EM_JS(double, js_chipmood_get_section_progress, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst) return 0.0;
    const mood = inst.MOODS[inst.currentMood];
    const sections = mood.sections || [{ bars: 16, rootOffset: 0, layers: [0,1,2,3] }];
    const section = sections[inst.currentSection];
    const sectionBeats = section.bars * inst.beatsPerBar;
    return sectionBeats > 0 ? inst.currentBeat / sectionBeats : 0.0;
});

// Export as WAV file (using callback-based API, no Asyncify needed)
EM_JS(void, js_chipmood_export_wav, (int instanceId), {
    console.log('[ChipMood] Starting WAV export...');
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst) {
        console.error('[ChipMood] No instance found');
        return;
    }

    const mood = inst.MOODS[inst.currentMood];
    const sections = mood.sections || [{ bars: 16, rootOffset: 0, layers: [0,1,2,3] }];

    // Calculate total duration
    let totalBars = 0;
    sections.forEach(s => totalBars += s.bars);
    const beatsPerBar = 4;
    const totalBeats = totalBars * beatsPerBar;
    const beatDuration = 60 / inst.tempo;
    const totalDuration = totalBeats * beatDuration + 1;
    console.log('[ChipMood] Rendering', totalDuration.toFixed(1), 'seconds of audio...');

    const sampleRate = 44100;
    const offlineCtx = new OfflineAudioContext(2, sampleRate * totalDuration, sampleRate);

    // Create audio graph
    const masterGain = offlineCtx.createGain();
    masterGain.gain.value = inst.masterGain.gain.value;

    const lowpass = offlineCtx.createBiquadFilter();
    lowpass.type = 'lowpass';
    lowpass.frequency.value = 4000 + (1 - mood.warmth) * 12000;

    const echoDelay = offlineCtx.createDelay(1.0);
    echoDelay.delayTime.value = 0.15;
    const echoGain = offlineCtx.createGain();
    echoGain.gain.value = mood.echo;

    lowpass.connect(masterGain);
    masterGain.connect(offlineCtx.destination);
    masterGain.connect(echoDelay);
    echoDelay.connect(echoGain);
    echoGain.connect(lowpass);

    // Helper to play note into offline context
    function playNote(freq, wave, vol, dur, startTime) {
        const gain = offlineCtx.createGain();
        gain.connect(lowpass);

        if (wave === 'noise') {
            const bufSize = Math.floor(sampleRate * dur);
            const buf = offlineCtx.createBuffer(1, bufSize, sampleRate);
            const data = buf.getChannelData(0);
            for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
            const noise = offlineCtx.createBufferSource();
            noise.buffer = buf;
            const bp = offlineCtx.createBiquadFilter();
            bp.type = 'bandpass'; bp.frequency.value = 1000;
            noise.connect(bp); bp.connect(gain);
            gain.gain.setValueAtTime(vol, startTime);
            gain.gain.exponentialRampToValueAtTime(0.001, startTime + dur * 0.8);
            noise.start(startTime); noise.stop(startTime + dur);
            return;
        }

        const osc = offlineCtx.createOscillator();
        osc.type = wave; osc.frequency.value = freq;
        osc.connect(gain);
        gain.gain.setValueAtTime(0, startTime);
        gain.gain.linearRampToValueAtTime(vol, startTime + 0.01);
        gain.gain.linearRampToValueAtTime(vol * 0.6, startTime + 0.11);
        gain.gain.setValueAtTime(vol * 0.6, startTime + dur * 0.7);
        gain.gain.exponentialRampToValueAtTime(0.001, startTime + dur);
        osc.start(startTime); osc.stop(startTime + dur + 0.1);
    }

    // Schedule all notes
    let currentTime = 0;
    let currentStep = 0;
    let currentBeat = 0;
    let currentSection = 0;

    while (currentTime < totalDuration - 1) {
        const section = sections[currentSection];
        const rootOffset = section.rootOffset || 0;
        const activeLayers = section.layers || [0,1,2,3];
        const isOffbeat = (currentStep % 2) === 1;
        const swingOffset = isOffbeat ? inst.swing * 0.1 * beatDuration : 0;

        mood.layers.forEach((layer, i) => {
            if (!activeLayers.includes(i)) return;
            if (inst.intensity < 0.3 && i > 1) return;
            if (inst.intensity < 0.6 && i > 2) return;

            const step = Math.floor(currentStep / (layer.rhythm / 0.25));
            let noteVal = layer.pattern[step % layer.pattern.length];
            if (noteVal === -1) return;

            if (inst.variation > 0 && Math.random() < inst.variation * 0.3) {
                noteVal += Math.floor((Math.random() - 0.5) * 4);
            }

            const dur = layer.rhythm * beatDuration * 0.9;
            const vol = layer.volume * (0.5 + inst.intensity * 0.5) * masterGain.gain.value;
            const noteTime = currentTime + swingOffset;

            if (layer.wave === 'noise') {
                playNote(0, 'noise', vol * (noteVal > 0 ? 1 : 0), dur, noteTime);
            } else {
                const octave = layer.octave + inst.octaveShift;
                const sectionRoot = mood.root + rootOffset;
                playNote(inst.getScaleNote(mood.scale, noteVal, sectionRoot, octave), layer.wave, vol, dur, noteTime);
            }
        });

        currentTime += 0.25 * beatDuration;
        currentStep++;
        currentBeat += 0.25;

        const sectionBeats = section.bars * beatsPerBar;
        if (currentBeat >= sectionBeats) {
            currentBeat = 0;
            currentSection = (currentSection + 1) % sections.length;
        }
    }

    // Render using callback-based API
    console.log('[ChipMood] Scheduling notes complete, starting render...');
    offlineCtx.startRendering().then(function(audioBuffer) {
        console.log('[ChipMood] Render complete, encoding WAV...');

        // Encode as WAV
        const numChannels = audioBuffer.numberOfChannels;
        const sr = audioBuffer.sampleRate;
        const format = 1;
        const bitsPerSample = 16;
        const bytesPerSample = bitsPerSample / 8;
        const blockAlign = numChannels * bytesPerSample;
        const byteRate = sr * blockAlign;
        const dataSize = audioBuffer.length * blockAlign;
        const headerSize = 44;
        const totalSize = headerSize + dataSize;

        const wavBuffer = new ArrayBuffer(totalSize);
        const view = new DataView(wavBuffer);

        function writeString(offset, str) {
            for (let i = 0; i < str.length; i++) {
                view.setUint8(offset + i, str.charCodeAt(i));
            }
        }

        writeString(0, 'RIFF');
        view.setUint32(4, totalSize - 8, true);
        writeString(8, 'WAVE');
        writeString(12, 'fmt ');
        view.setUint32(16, 16, true);
        view.setUint16(20, format, true);
        view.setUint16(22, numChannels, true);
        view.setUint32(24, sr, true);
        view.setUint32(28, byteRate, true);
        view.setUint16(32, blockAlign, true);
        view.setUint16(34, bitsPerSample, true);
        writeString(36, 'data');
        view.setUint32(40, dataSize, true);

        const channels = [];
        for (let c = 0; c < numChannels; c++) {
            channels.push(audioBuffer.getChannelData(c));
        }

        let offset = 44;
        for (let i = 0; i < audioBuffer.length; i++) {
            for (let c = 0; c < numChannels; c++) {
                let sample = channels[c][i];
                sample = Math.max(-1, Math.min(1, sample));
                sample = sample < 0 ? sample * 0x8000 : sample * 0x7FFF;
                view.setInt16(offset, sample, true);
                offset += 2;
            }
        }

        const wavBlob = new Blob([wavBuffer], { type: 'audio/wav' });
        const url = URL.createObjectURL(wavBlob);
        const a = document.createElement('a');
        a.href = url;
        a.download = inst.currentMood + '_chipmood.wav';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        console.log('[ChipMood] Export complete! File size:', (wavBlob.size / 1024 / 1024).toFixed(1), 'MB');
    }).catch(function(e) {
        console.error('[ChipMood] Export failed:', e);
    });
});

#endif // EMSCRIPTEN

int ChipMood::nextInstanceId_ = 0;

ChipMood::ChipMood(QObject *parent)
    : QObject(parent)
{
    instanceId_ = nextInstanceId_++;
    initAudio();

    // Set up timer to poll section info from JS
    connect(&sectionTimer_, &QTimer::timeout, this, &ChipMood::updateSectionInfo);
    sectionTimer_.setInterval(100); // Update 10 times per second
}

ChipMood::~ChipMood()
{
    stop();
}

void ChipMood::initAudio()
{
#ifdef EMSCRIPTEN
    js_chipmood_init(instanceId_);
    ready_ = true;
    emit readyChanged();
#else
    qWarning() << "ChipMood: Desktop playback not yet implemented";
    ready_ = false;
#endif
}

void ChipMood::setMood(const QString &mood)
{
    if (mood_ == mood) return;
    mood_ = mood;
    emit moodChanged();

#ifdef EMSCRIPTEN
    int newTempo = js_chipmood_set_mood(instanceId_, mood.toUtf8().constData());
    if (newTempo > 0 && newTempo != tempo_) {
        tempo_ = newTempo;
        emit tempoChanged();
    }
    // Update section info for new mood
    int newTotal = js_chipmood_get_total_sections(instanceId_);
    if (newTotal != totalSections_) {
        totalSections_ = newTotal;
        emit totalSectionsChanged();
    }
    currentSection_ = 0;
    sectionProgress_ = 0.0;
    emit currentSectionChanged();
    emit sectionProgressChanged();
#endif
}

void ChipMood::setVolume(qreal volume)
{
    volume = qBound(0.0, volume, 1.0);
    if (qFuzzyCompare(volume_, volume)) return;
    volume_ = volume;
    emit volumeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_volume(instanceId_, volume);
#endif
}

void ChipMood::setIntensity(qreal intensity)
{
    intensity = qBound(0.0, intensity, 1.0);
    if (qFuzzyCompare(intensity_, intensity)) return;
    intensity_ = intensity;
    emit intensityChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_intensity(instanceId_, intensity);
#endif
}

QStringList ChipMood::availableMoods() const
{
    return QStringList() << "mysterious_forest" << "dark_dungeon" << "peaceful_village";
}

void ChipMood::play()
{
#ifdef EMSCRIPTEN
    js_chipmood_play(instanceId_);
    playing_ = true;
    emit playingChanged();
    sectionTimer_.start();
#endif
}

void ChipMood::stop()
{
#ifdef EMSCRIPTEN
    js_chipmood_stop(instanceId_);
#endif
    sectionTimer_.stop();
    playing_ = false;
    emit playingChanged();
}

void ChipMood::pause()
{
    stop();  // For now, pause is same as stop
}

void ChipMood::resume()
{
    play();
}

void ChipMood::setTempo(int tempo)
{
    tempo = qBound(60, tempo, 180);
    if (tempo_ == tempo) return;
    tempo_ = tempo;
    emit tempoChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_tempo(instanceId_, tempo);
#endif
}

void ChipMood::setOctaveShift(int shift)
{
    shift = qBound(-2, shift, 2);
    if (octaveShift_ == shift) return;
    octaveShift_ = shift;
    emit octaveShiftChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_octave_shift(instanceId_, shift);
#endif
}

void ChipMood::setSwing(qreal swing)
{
    swing = qBound(0.0, swing, 1.0);
    if (qFuzzyCompare(swing_, swing)) return;
    swing_ = swing;
    emit swingChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_swing(instanceId_, swing);
#endif
}

void ChipMood::setVariation(qreal variation)
{
    variation = qBound(0.0, variation, 1.0);
    if (qFuzzyCompare(variation_, variation)) return;
    variation_ = variation;
    emit variationChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_variation(instanceId_, variation);
#endif
}

void ChipMood::randomize()
{
#ifdef EMSCRIPTEN
    js_chipmood_randomize(instanceId_);
#endif
}

QString ChipMood::sectionName() const
{
    static const QStringList names = {"A", "B", "A'", "C", "D", "E", "F", "G"};
    if (currentSection_ >= 0 && currentSection_ < names.size())
        return names[currentSection_];
    return QString::number(currentSection_ + 1);
}

void ChipMood::updateSectionInfo()
{
#ifdef EMSCRIPTEN
    int newSection = js_chipmood_get_section(instanceId_);
    int newTotal = js_chipmood_get_total_sections(instanceId_);
    qreal newProgress = js_chipmood_get_section_progress(instanceId_);

    if (newSection != currentSection_) {
        currentSection_ = newSection;
        emit currentSectionChanged();
    }
    if (newTotal != totalSections_) {
        totalSections_ = newTotal;
        emit totalSectionsChanged();
    }
    if (!qFuzzyCompare(newProgress, sectionProgress_)) {
        sectionProgress_ = newProgress;
        emit sectionProgressChanged();
    }
#endif
}

void ChipMood::exportWav()
{
#ifdef EMSCRIPTEN
    js_chipmood_export_wav(instanceId_);
#endif
}
