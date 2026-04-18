// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "chipmood.h"
#include <QDebug>
#ifndef __EMSCRIPTEN__
#include "softsynth.h"
#include "engine/pcm_buffer.h"
#endif
#include <QJsonDocument>
#include <QJsonObject>

#ifdef EMSCRIPTEN
#include <emscripten.h>

// Initialize ChipMood audio engine with seeded RNG and preset-based configuration
EM_JS(void, js_chipmood_init, (int instanceId), {
    if (!Module.chipMoodInstances) Module.chipMoodInstances = {};
    if (Module.chipMoodInstances[instanceId]) return;

    // Seeded PRNG (mulberry32) for deterministic generation
    function createRng(seed) {
        let state = seed >>> 0;
        return function() {
            state = (state + 0x6D2B79F5) >>> 0;
            let t = state;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }

    // Musical scales
    const SCALES = {
        major:      [0, 2, 4, 5, 7, 9, 11],
        minor:      [0, 2, 3, 5, 7, 8, 10],
        dorian:     [0, 2, 3, 5, 7, 9, 10],
        phrygian:   [0, 1, 3, 5, 7, 8, 10],
        lydian:     [0, 2, 4, 6, 7, 9, 11],
        mixolydian: [0, 2, 4, 5, 7, 9, 10],
        pentatonic: [0, 2, 4, 7, 9],
        blues:      [0, 3, 5, 6, 7, 10]
    };

    // Pattern generators based on style and seed
    function generateArpPattern(style, rng, scaleLen) {
        const patterns = {
            flowing:     () => [0,2,4,6, 0,2,4,7, 0,2,5,6, 0,2,4,6, 0,2,4,6, 1,3,5,6, 0,2,4,6, 0,2,4,7],
            pulsing:     () => [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,2,0, 0,0,1,0, 0,0,1,0, 0,0,3,0, 0,0,1,0],
            bright:      () => [0,2,4,2, 0,2,4,5, 0,2,4,2, 0,4,2,0, 0,2,4,2, 0,2,5,4, 0,2,4,2, 4,2,0,-1],
            sparse:      () => [0,-1,-1,-1, 2,-1,-1,-1, 4,-1,-1,-1, 2,-1,-1,-1, 0,-1,-1,-1, 3,-1,-1,-1, 5,-1,-1,-1, 0,-1,-1,-1],
            majestic:    () => [0,-1,4,-1, 0,-1,7,-1, 0,-1,4,-1, 0,-1,5,-1, 0,-1,4,-1, 0,-1,7,-1, 0,-1,4,-1, 0,-1,2,-1],
            wave:        () => [0,1,2,3, 4,3,2,1, 0,1,2,3, 4,5,4,3, 0,1,2,3, 4,3,2,1, 0,1,2,3, 2,1,0,-1],
            exotic:      () => [0,1,4,1, 0,1,5,1, 0,1,4,1, 0,3,1,0, 0,1,4,1, 0,1,5,1, 0,1,4,1, 3,1,0,-1],
            crystalline: () => [0,-1,4,-1, 7,-1,4,-1, 0,-1,5,-1, 7,-1,5,-1, 0,-1,4,-1, 7,-1,4,-1, 0,-1,2,-1, 4,-1,0,-1]
        };
        const basePat = (patterns[style] || patterns.flowing)();
        // Add seed-based variation
        return basePat.map((n, i) => {
            if (n === -1) return -1;
            if (rng() < 0.1) return (n + Math.floor(rng() * 3) - 1 + scaleLen) % scaleLen;
            return n;
        });
    }

    function generateMelodyPattern(style, rng, scaleLen) {
        const patterns = {
            flowing:     () => [4,3,2,1, 2,-1,-1,-1, 4,5,4,3, 2,-1,-1,-1, 2,3,4,5, 6,-1,-1,-1, 4,3,2,1, 0,-1,-1,-1],
            pulsing:     () => [0,-1,1,-1, 0,-1,-1,-1, -1,-1,2,-1, 1,-1,-1,-1, 0,-1,1,-1, 2,-1,-1,-1, 1,-1,0,-1, -1,-1,-1,-1],
            bright:      () => [4,2,0,2, 4,4,4,-1, 5,4,2,4, 5,5,5,-1, 4,4,5,5, 4,4,2,-1, 0,2,4,2, 0,-1,-1,-1],
            sparse:      () => [2,-1,-1,-1, -1,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1, 3,-1,-1,-1, -1,-1,-1,-1, 0,-1,-1,-1, -1,-1,-1,-1],
            majestic:    () => [4,-1,5,-1, 7,-1,-1,-1, 5,-1,4,-1, 2,-1,-1,-1, 4,-1,5,-1, 7,-1,-1,-1, 5,-1,4,-1, 0,-1,-1,-1],
            wave:        () => [2,3,4,5, 4,3,2,-1, 3,4,5,6, 5,4,3,-1, 2,3,4,5, 4,3,2,-1, 1,2,3,2, 0,-1,-1,-1],
            exotic:      () => [0,1,3,-1, 5,-1,-1,-1, 3,1,0,-1, -1,-1,-1,-1, 0,1,3,-1, 6,-1,-1,-1, 3,1,0,-1, -1,-1,-1,-1],
            crystalline: () => [7,-1,-1,-1, 5,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1, 7,-1,-1,-1, 4,-1,-1,-1, 2,-1,-1,-1, 0,-1,-1,-1]
        };
        const basePat = (patterns[style] || patterns.flowing)();
        return basePat.map((n, i) => {
            if (n === -1) return -1;
            if (rng() < 0.15) return (n + Math.floor(rng() * 5) - 2 + scaleLen) % scaleLen;
            return n;
        });
    }

    function generateBassPattern(style, rng) {
        const patterns = {
            gentle:   () => [0,-1,0,-1, 2,-1,0,-1, 0,-1,0,-1, 4,-1,2,-1],
            driving:  () => [0,0,0,0, 0,0,2,0, 0,0,0,0, 3,0,2,0],
            walking:  () => [0,-1,4,-1, 0,-1,4,-1, 2,-1,4,-1, 0,-1,2,-1],
            rumbling: () => [0,-1,-1,-1, -1,-1,0,-1, -1,-1,-1,-1, 0,-1,-1,-1],
            grounded: () => [0,-1,-1,-1, 0,-1,2,-1, 0,-1,-1,-1, 0,-1,4,-1],
            deep:     () => [0,-1,0,-1, -1,-1,0,-1, 2,-1,0,-1, -1,-1,2,-1],
            sparse:   () => [0,-1,-1,-1, -1,-1,-1,-1, 2,-1,-1,-1, -1,-1,-1,-1],
            minimal:  () => [0,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, 0,-1,-1,-1]
        };
        return (patterns[style] || patterns.gentle)();
    }

    function generatePadPattern(style, rng) {
        const patterns = {
            sustained:  () => [0,-1,-1,-1, 0,-1,-1,-1],
            dark:       () => [0,-1,-1,-1, -1,-1,-1,-1, 0,-1,-1,-1, -1,-1,-1,-1],
            warm:       () => [0,4, 0,4, 2,4, 0,4],
            droning:    () => [0,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, 0,-1,-1,-1],
            airy:       () => [4,-1,-1,-1, 4,-1,-1,-1],
            flowing:    () => [0,2, 0,2, 0,4, 0,2],
            shimmering: () => [0,2,4,2, 0,2,4,2],
            ethereal:   () => [4,-1,-1,-1, -1,-1,-1,-1, 7,-1,-1,-1, -1,-1,-1,-1]
        };
        return (patterns[style] || patterns.sustained)();
    }

    // Build composition from preset config, scale, and seed
    function buildComposition(config, scaleName, seed, enabledLayers) {
        const env = config || {};
        const scale = SCALES[scaleName] || SCALES.dorian;
        const rng = createRng(seed);

        // Deterministic tempo and root from seed within preset ranges
        const tempo = env.tempoRange[0] + Math.floor(rng() * (env.tempoRange[1] - env.tempoRange[0]));
        const root = env.rootRange[0] + Math.floor(rng() * (env.rootRange[1] - env.rootRange[0]));

        // Generate patterns based on preset style
        const arpPattern = generateArpPattern(env.arpStyle, rng, scale.length);
        const melodyPattern = generateMelodyPattern(env.arpStyle, rng, scale.length);
        const bassPattern = generateBassPattern(env.bassStyle, rng);
        const padPattern = generatePadPattern(env.padStyle, rng);

        // Build sections with chord progressions
        const sections = env.sectionPattern.map((bars, i) => {
            const chordOffsets = [0, 5, 0, 3]; // i, V, i, IV pattern
            const baseLayers = [0, 1, 2, 3];
            // Vary layers per section
            let sectionLayers;
            if (i === 1) sectionLayers = [0, 2, 3];      // Drop melody in B
            else if (i === 3) sectionLayers = [1, 2];    // Sparse in C
            else sectionLayers = baseLayers;

            // Filter by enabled layers
            sectionLayers = sectionLayers.filter(l => {
                const layerNames = ['arp', 'melody', 'pad', 'bass'];
                return enabledLayers.includes(layerNames[l]);
            });

            return {
                bars: bars,
                rootOffset: chordOffsets[i % 4],
                layers: sectionLayers
            };
        });

        // Define layer configurations
        const waveTypes = {
            arp: env.warmth > 0.6 ? 'triangle' : 'square',
            melody: env.warmth > 0.5 ? 'sine' : 'square',
            pad: 'sine',
            bass: 'triangle'
        };

        const layers = [
            // Arp (layer 0)
            {
                wave: waveTypes.arp,
                octave: 1,
                pattern: arpPattern,
                rhythm: 0.25,
                volume: 0.28
            },
            // Melody (layer 1)
            {
                wave: waveTypes.melody,
                octave: 0,
                pattern: melodyPattern,
                rhythm: 0.5,
                volume: 0.25
            },
            // Pad (layer 2)
            {
                wave: waveTypes.pad,
                octave: -1,
                pattern: padPattern,
                rhythm: env.padStyle === 'shimmering' ? 0.5 : 4,
                volume: 0.14
            },
            // Bass (layer 3)
            {
                wave: waveTypes.bass,
                octave: -2,
                pattern: bassPattern,
                rhythm: 0.5,
                volume: 0.2
            }
        ];

        // Add percussion layer for environments that use it
        if (env.percStyle !== 'none') {
            const percPatterns = {
                sparse:   [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,1,0],
                drips:    [0,0,0,0, 1,0,0,0, 0,0,0,0, 0,0,1,0],
                rhythmic: [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,0,1]
            };
            layers.push({
                wave: 'noise',
                pattern: percPatterns[env.percStyle] || percPatterns.sparse,
                rhythm: 0.25,
                volume: 0.08
            });
        }

        return {
            scale: scaleName,
            scaleNotes: scale,
            root: root,
            tempo: tempo,
            sections: sections,
            layers: layers,
            echo: env.echo,
            warmth: env.warmth
        };
    }

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

    function getScaleNote(scaleNotes, degree, root, octaveOffset) {
        const oct = Math.floor(degree / scaleNotes.length);
        const note = ((degree % scaleNotes.length) + scaleNotes.length) % scaleNotes.length;
        return midiToFreq(root + scaleNotes[note] + oct * 12 + octaveOffset * 12);
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
        SCALES, buildComposition,
        midiToFreq, getScaleNote, playNote,
        // Configuration
        presetName: '',
        presetConfig: null,
        scale: 'dorian',
        enabledLayers: ['arp', 'melody', 'pad', 'bass'],
        seed: 0,
        composition: null,
        // Playback state
        tempo: 85, intensity: 0.5, volume: 0.7,
        octaveShift: 0, swing: 0, variation: 0, brightness: 0.5,
        isPlaying: false, schedulerTimer: null,
        nextNoteTime: 0, currentStep: 0,
        currentSection: 0, currentBeat: 0, beatsPerBar: 4,
        // Seeded RNG for variation
        variationRng: null
    };
});

// Configure and rebuild composition
EM_JS(int, js_chipmood_configure, (int instanceId, const char* presetJson, const char* scaleName, int seed, const char* layersJson), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst) return 0;

    const presetStr = UTF8ToString(presetJson);
    const scale = UTF8ToString(scaleName);
    const layersStr = UTF8ToString(layersJson);

    let config;
    try {
        config = JSON.parse(presetStr);
    } catch (e) {
        return 0;
    }
    if (!config || typeof config !== 'object') return 0;
    if (!inst.SCALES[scale]) return 0;

    let layers;
    try {
        layers = JSON.parse(layersStr);
    } catch (e) {
        layers = ['arp', 'melody', 'pad', 'bass'];
    }

    inst.presetConfig = config;
    inst.scale = scale;
    inst.seed = seed;
    inst.enabledLayers = layers;

    // Build new composition
    inst.composition = inst.buildComposition(config, scale, seed, layers);
    inst.tempo = inst.composition.tempo;

    // Apply audio settings
    inst.echoGain.gain.value = inst.composition.echo;
    const baseFreq = 4000 + (1 - inst.composition.warmth) * 12000;
    inst.lowpass.frequency.value = baseFreq * (0.5 + inst.brightness * 0.5);

    // Reset section tracking
    inst.currentSection = 0;
    inst.currentBeat = 0;

    return inst.tempo;
});

// Set preset name (for display and export filenames)
EM_JS(void, js_chipmood_set_preset_name, (int instanceId, const char* name), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (inst) inst.presetName = UTF8ToString(name);
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
EM_JS(void, js_chipmood_set_variation, (int instanceId, double variation, int seed), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (inst) {
        inst.variation = Math.max(0, Math.min(1, variation));
        // Create seeded RNG for variation
        let state = seed >>> 0;
        inst.variationRng = function() {
            state = (state + 0x6D2B79F5) >>> 0;
            let t = state;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }
});

// Set brightness (0-1) - controls filter cutoff
EM_JS(void, js_chipmood_set_brightness, (int instanceId, double brightness), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (inst && inst.composition) {
        inst.brightness = Math.max(0, Math.min(1, brightness));
        const baseFreq = 4000 + (1 - inst.composition.warmth) * 12000;
        inst.lowpass.frequency.value = baseFreq * (0.5 + brightness * 0.5);
    }
});

// Randomize playback position (does not change the preset)
EM_JS(void, js_chipmood_randomize, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst || !inst.composition) return;

    const comp = inst.composition;
    // Jump to random section and position
    const sections = comp.sections || [{ bars: 16 }];
    inst.currentSection = Math.floor(Math.random() * sections.length);
    inst.currentBeat = Math.floor(Math.random() * 8);
    inst.currentStep = Math.floor(Math.random() * 32);
});

// Play
EM_JS(void, js_chipmood_play, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst) return;

    // Build composition if not already built
    if (!inst.composition && inst.presetConfig) {
        inst.composition = inst.buildComposition(
            inst.presetConfig, inst.scale, inst.seed, inst.enabledLayers
        );
        inst.tempo = inst.composition.tempo;
        inst.echoGain.gain.value = inst.composition.echo;
        const baseFreq = 4000 + (1 - inst.composition.warmth) * 12000;
        inst.lowpass.frequency.value = baseFreq * (0.5 + inst.brightness * 0.5);
    }

    if (inst.audioCtx.state === 'suspended') inst.audioCtx.resume();

    inst.isPlaying = true;
    inst.currentStep = 0;
    inst.currentSection = 0;
    inst.currentBeat = 0;
    inst.nextNoteTime = inst.audioCtx.currentTime;

    // Initialize variation RNG
    let varState = (inst.seed + 12345) >>> 0;
    inst.variationRng = function() {
        varState = (varState + 0x6D2B79F5) >>> 0;
        let t = varState;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };

    function scheduler() {
        if (!inst.isPlaying) return;
        const comp = inst.composition;
        const sections = comp.sections;

        while (inst.nextNoteTime < inst.audioCtx.currentTime + 0.1) {
            const section = sections[inst.currentSection];
            const rootOffset = section.rootOffset || 0;
            const activeLayers = section.layers || [0,1,2,3];

            const isOffbeat = (inst.currentStep % 2) === 1;
            const swingOffset = isOffbeat ? inst.swing * 0.1 * (60 / inst.tempo) : 0;

            comp.layers.forEach((layer, i) => {
                // Check if layer is active in current section
                if (!activeLayers.includes(i)) return;
                // Apply intensity filtering
                if (inst.intensity < 0.3 && i > 1) return;
                if (inst.intensity < 0.6 && i > 2) return;

                const step = Math.floor(inst.currentStep / (layer.rhythm / 0.25));
                let noteVal = layer.pattern[step % layer.pattern.length];
                if (noteVal === -1) return;

                // Apply variation using seeded RNG
                if (inst.variation > 0 && inst.variationRng() < inst.variation * 0.3) {
                    noteVal += Math.floor((inst.variationRng() - 0.5) * 4);
                }

                const dur = layer.rhythm * (60 / inst.tempo) * 0.9;
                const vol = layer.volume * (0.5 + inst.intensity * 0.5) * inst.masterGain.gain.value;
                const noteTime = inst.nextNoteTime + swingOffset;

                if (layer.wave === 'noise') {
                    inst.playNote(0, 'noise', vol * (noteVal > 0 ? 1 : 0), dur, noteTime);
                } else {
                    const octave = layer.octave + inst.octaveShift;
                    const sectionRoot = comp.root + rootOffset;
                    inst.playNote(
                        inst.getScaleNote(comp.scaleNotes, noteVal, sectionRoot, octave),
                        layer.wave, vol, dur, noteTime
                    );
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
    if (!inst || !inst.composition) return 4;
    return inst.composition.sections.length;
});

// Get section progress (0.0-1.0)
EM_JS(double, js_chipmood_get_section_progress, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst || !inst.composition) return 0.0;
    const sections = inst.composition.sections;
    const section = sections[inst.currentSection];
    const sectionBeats = section.bars * inst.beatsPerBar;
    return sectionBeats > 0 ? inst.currentBeat / sectionBeats : 0.0;
});

// Get current tempo
EM_JS(int, js_chipmood_get_tempo, (int instanceId), {
    const inst = Module.chipMoodInstances?.[instanceId];
    return inst ? inst.tempo : 85;
});

// Export as WAV file
EM_JS(void, js_chipmood_export_wav, (int instanceId), {
    console.log('[ChipMood] Starting WAV export...');
    const inst = Module.chipMoodInstances?.[instanceId];
    if (!inst || !inst.composition) {
        console.error('[ChipMood] No composition to export');
        return;
    }

    const comp = inst.composition;
    const sections = comp.sections;

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
    const baseFreq = 4000 + (1 - comp.warmth) * 12000;
    lowpass.frequency.value = baseFreq * (0.5 + inst.brightness * 0.5);

    const echoDelay = offlineCtx.createDelay(1.0);
    echoDelay.delayTime.value = 0.15;
    const echoGain = offlineCtx.createGain();
    echoGain.gain.value = comp.echo;

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

    // Initialize variation RNG for export (same seed as playback)
    let varState = (inst.seed + 12345) >>> 0;
    function variationRng() {
        varState = (varState + 0x6D2B79F5) >>> 0;
        let t = varState;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
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

        comp.layers.forEach((layer, i) => {
            if (!activeLayers.includes(i)) return;
            // Note: Removed intensity-based layer dropout for export to ensure
            // all sections have audio content. Volume scaling still applies.

            const step = Math.floor(currentStep / (layer.rhythm / 0.25));
            let noteVal = layer.pattern[step % layer.pattern.length];
            if (noteVal === -1) return;

            if (inst.variation > 0 && variationRng() < inst.variation * 0.3) {
                noteVal += Math.floor((variationRng() - 0.5) * 4);
            }

            const dur = layer.rhythm * beatDuration * 0.9;
            const vol = layer.volume * (0.5 + inst.intensity * 0.5) * masterGain.gain.value;
            const noteTime = currentTime + swingOffset;

            if (layer.wave === 'noise') {
                playNote(0, 'noise', vol * (noteVal > 0 ? 1 : 0), dur, noteTime);
            } else {
                const octave = layer.octave + inst.octaveShift;
                const sectionRoot = comp.root + rootOffset;
                playNote(
                    inst.getScaleNote(comp.scaleNotes, noteVal, sectionRoot, octave),
                    layer.wave, vol, dur, noteTime
                );
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

    // Render and export
    console.log('[ChipMood] Scheduling notes complete, starting render...');
    offlineCtx.startRendering().then(function(audioBuffer) {
        console.log('[ChipMood] Render complete, encoding WAV...');

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
        a.download = (inst.presetName || 'custom') + '_' + inst.scale + '_s' + inst.seed + '_chipmood.wav';
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

    connect(&sectionTimer_, &QTimer::timeout, this, &ChipMood::updateSectionInfo);
    sectionTimer_.setInterval(100);
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
    synth_ = new SoftSynth(this);
    ready_ = true;
    emit readyChanged();
#endif
}

void ChipMood::applyConfiguration()
{
#ifdef EMSCRIPTEN
    if (preset_.isEmpty()) return;

    QByteArray presetJson = QJsonDocument(QJsonObject::fromVariantMap(preset_)).toJson(QJsonDocument::Compact);

    QByteArray layersJson = "[";
    for (int i = 0; i < layers_.size(); ++i) {
        if (i > 0) layersJson += ",";
        layersJson += "\"" + layers_[i].toUtf8() + "\"";
    }
    layersJson += "]";

    int newTempo = js_chipmood_configure(
        instanceId_,
        presetJson.constData(),
        scale_.toUtf8().constData(),
        seed_,
        layersJson.constData()
    );

    if (newTempo > 0 && newTempo != tempo_) {
        tempo_ = newTempo;
        emit tempoChanged();
    }

    int newTotal = js_chipmood_get_total_sections(instanceId_);
    if (newTotal != totalSections_) {
        totalSections_ = newTotal;
        emit totalSectionsChanged();
    }

    currentSection_ = 0;
    sectionProgress_ = 0.0;
    emit currentSectionChanged();
    emit sectionProgressChanged();
    emit shareCodeChanged();
#else
    if (preset_.isEmpty()) return;
    totalSections_ = 4;
    emit totalSectionsChanged();
    emit shareCodeChanged();
    if (synth_) {
        buildDesktopComposition();
        // Composition is swapped in-place; if already playing, continues seamlessly
    }
#endif
}

void ChipMood::setPreset(const QVariantMap &preset)
{
    if (preset_ == preset) return;
    preset_ = preset;
    emit presetChanged();
    applyConfiguration();
}

void ChipMood::setPresetName(const QString &name)
{
    if (presetName_ == name) return;
    presetName_ = name;
    emit presetNameChanged();
    emit shareCodeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_preset_name(instanceId_, presetName_.toUtf8().constData());
#endif
}

void ChipMood::setScale(const QString &scale)
{
    if (scale_ == scale) return;
    scale_ = scale;
    emit scaleChanged();
    applyConfiguration();
}

void ChipMood::setLayers(const QStringList &layers)
{
    if (layers_ == layers) return;
    layers_ = layers;
    emit layersChanged();
    applyConfiguration();
}

void ChipMood::setSeed(int seed)
{
    if (seed_ == seed) return;
    seed_ = seed;
    emit seedChanged();
    applyConfiguration();
}

void ChipMood::setVolume(qreal volume)
{
    volume = qBound(0.0, volume, 1.0);
    if (qFuzzyCompare(volume_, volume)) return;
    volume_ = volume;
    emit volumeChanged();
    emit shareCodeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_volume(instanceId_, volume);
#else
    if (synth_) synth_->setVolume(volume);
#endif
}

void ChipMood::setIntensity(qreal intensity)
{
    intensity = qBound(0.0, intensity, 1.0);
    if (qFuzzyCompare(intensity_, intensity)) return;
    intensity_ = intensity;
    emit intensityChanged();
    emit shareCodeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_intensity(instanceId_, intensity);
#else
    if (synth_ && !preset_.isEmpty()) buildDesktopComposition();
#endif
}

void ChipMood::setTempo(int tempo)
{
    tempo = qBound(60, tempo, 180);
    if (tempo_ == tempo) return;
    tempo_ = tempo;
    emit tempoChanged();
    emit shareCodeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_tempo(instanceId_, tempo);
#else
    if (synth_ && !preset_.isEmpty()) buildDesktopComposition();
#endif
}

void ChipMood::setSwing(qreal swing)
{
    swing = qBound(0.0, swing, 1.0);
    if (qFuzzyCompare(swing_, swing)) return;
    swing_ = swing;
    emit swingChanged();
    emit shareCodeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_swing(instanceId_, swing);
#else
    if (synth_ && !preset_.isEmpty()) buildDesktopComposition();
#endif
}

void ChipMood::setVariation(qreal variation)
{
    variation = qBound(0.0, variation, 1.0);
    if (qFuzzyCompare(variation_, variation)) return;
    variation_ = variation;
    emit variationChanged();
    emit shareCodeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_variation(instanceId_, variation, seed_);
#else
    if (synth_ && !preset_.isEmpty()) buildDesktopComposition();
#endif
}

void ChipMood::setOctaveShift(int shift)
{
    shift = qBound(-2, shift, 2);
    if (octaveShift_ == shift) return;
    octaveShift_ = shift;
    emit octaveShiftChanged();
    emit shareCodeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_octave_shift(instanceId_, shift);
#else
    if (synth_ && !preset_.isEmpty()) buildDesktopComposition();
#endif
}

void ChipMood::setBrightness(qreal brightness)
{
    brightness = qBound(0.0, brightness, 1.0);
    if (qFuzzyCompare(brightness_, brightness)) return;
    brightness_ = brightness;
    emit brightnessChanged();
    emit shareCodeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_brightness(instanceId_, brightness);
#else
    if (synth_) {
        double warmth = preset_.value("warmth", 0.5).toDouble();
        double filterHz = 4000.0 + (1.0 - warmth) * 12000.0;
        filterHz *= (0.5 + brightness_ * 0.5);
        synth_->setFilterCutoff(filterHz);
    }
#endif
}

QString ChipMood::shareCode() const
{
    // Format: env-scale-layers-intensity-variation-tempo-seed
    // Example: cave-dor-ampb-50-30-85-42

    // Scale abbreviations
    QMap<QString, QString> scaleAbbr;
    scaleAbbr["major"] = "maj";
    scaleAbbr["minor"] = "min";
    scaleAbbr["dorian"] = "dor";
    scaleAbbr["phrygian"] = "phr";
    scaleAbbr["lydian"] = "lyd";
    scaleAbbr["mixolydian"] = "mix";
    scaleAbbr["pentatonic"] = "pent";
    scaleAbbr["blues"] = "blu";

    QString scaleCode = scaleAbbr.value(scale_, scale_.left(3));

    // Layer encoding: a=arp, m=melody, p=pad, b=bass
    QString layerCode;
    if (layers_.contains("arp")) layerCode += "a";
    if (layers_.contains("melody")) layerCode += "m";
    if (layers_.contains("pad")) layerCode += "p";
    if (layers_.contains("bass")) layerCode += "b";
    if (layerCode.isEmpty()) layerCode = "none";

    return QString("%1-%2-%3-%4-%5-%6-%7")
        .arg(presetName_.isEmpty() ? QStringLiteral("custom") : presetName_)
        .arg(scaleCode)
        .arg(layerCode)
        .arg(qRound(intensity_ * 100))
        .arg(qRound(variation_ * 100))
        .arg(tempo_)
        .arg(seed_);
}

void ChipMood::setShareCode(const QString &code)
{
    QStringList parts = code.split('-');
    if (parts.size() < 7) return;

    // Parse preset name (actual preset config must be set separately by the caller)
    QString pName = parts[0];

    // Parse scale
    QMap<QString, QString> scaleExpand;
    scaleExpand["maj"] = "major";
    scaleExpand["min"] = "minor";
    scaleExpand["dor"] = "dorian";
    scaleExpand["phr"] = "phrygian";
    scaleExpand["lyd"] = "lydian";
    scaleExpand["mix"] = "mixolydian";
    scaleExpand["pent"] = "pentatonic";
    scaleExpand["blu"] = "blues";
    QString scl = scaleExpand.value(parts[1], parts[1]);

    // Parse layers
    QStringList lyrs;
    QString layerCode = parts[2];
    if (layerCode.contains('a')) lyrs << "arp";
    if (layerCode.contains('m')) lyrs << "melody";
    if (layerCode.contains('p')) lyrs << "pad";
    if (layerCode.contains('b')) lyrs << "bass";

    // Parse numeric values
    bool ok;
    int intensityPct = parts[3].toInt(&ok);
    if (!ok) return;
    int variationPct = parts[4].toInt(&ok);
    if (!ok) return;
    int tempoVal = parts[5].toInt(&ok);
    if (!ok) return;
    int seedVal = parts[6].toInt(&ok);
    if (!ok) return;

    // Apply all values (without triggering multiple reconfigurations)
    bool wasBlocked = blockSignals(true);

    presetName_ = pName;
    scale_ = scl;
    layers_ = lyrs;
    seed_ = seedVal;
    intensity_ = intensityPct / 100.0;
    variation_ = variationPct / 100.0;
    tempo_ = tempoVal;

    blockSignals(wasBlocked);

    // Apply configuration once (only if preset config is already set)
    applyConfiguration();

    // Emit all signals
    emit presetNameChanged();
    emit scaleChanged();
    emit layersChanged();
    emit seedChanged();
    emit intensityChanged();
    emit variationChanged();
    emit tempoChanged();
    emit shareCodeChanged();

#ifdef EMSCRIPTEN
    js_chipmood_set_preset_name(instanceId_, presetName_.toUtf8().constData());
    js_chipmood_set_intensity(instanceId_, intensity_);
    js_chipmood_set_variation(instanceId_, variation_, seed_);
    js_chipmood_set_tempo(instanceId_, tempo_);
#endif
}

QStringList ChipMood::availableScales() const
{
    return QStringList() << "major" << "minor" << "dorian" << "phrygian"
                         << "lydian" << "mixolydian" << "pentatonic" << "blues";
}

QStringList ChipMood::availableLayers() const
{
    return QStringList() << "arp" << "melody" << "pad" << "bass";
}

void ChipMood::play()
{
#ifdef EMSCRIPTEN
    js_chipmood_play(instanceId_);
#else
    if (synth_) {
        buildDesktopComposition();
        synth_->play();
    }
#endif
    playing_ = true;
    emit playingChanged();
    sectionTimer_.start();
}

void ChipMood::stop()
{
#ifdef EMSCRIPTEN
    js_chipmood_stop(instanceId_);
#else
    if (synth_) synth_->stop();
#endif
    sectionTimer_.stop();
    playing_ = false;
    emit playingChanged();
}

void ChipMood::pause()
{
#ifndef EMSCRIPTEN
    if (synth_) synth_->pause();
#endif
    playing_ = false;
    emit playingChanged();
}

void ChipMood::resume()
{
#ifndef EMSCRIPTEN
    if (synth_) synth_->resume();
#endif
    playing_ = true;
    emit playingChanged();
}

void ChipMood::randomize()
{
#ifdef EMSCRIPTEN
    js_chipmood_randomize(instanceId_);
    emit shareCodeChanged();
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

void ChipMood::exportWav(const QString &path)
{
#ifdef EMSCRIPTEN
    Q_UNUSED(path);
    js_chipmood_export_wav(instanceId_);
#else
    if (!synth_ || preset_.isEmpty() || path.isEmpty()) return;

    // Rebuild the composition and render it offline via a scratch
    // SoftSynth (live synth state is preserved).
    buildDesktopComposition();
    const int sampleRate = 44100;
    const int totalSamples = static_cast<int>(synth_->loopDuration() * sampleRate);
    if (totalSamples <= 0) return;

    SoftSynth renderer;
    const double warmth = preset_.value("warmth", 0.5).toDouble();
    double filterHz = (4000.0 + (1.0 - warmth) * 12000.0) * (0.5 + brightness_ * 0.5);
    renderer.setFilterCutoff(filterHz);
    renderer.setEchoMix(preset_.value("echo", 0.3).toDouble());
    renderer.setVolume(volume_);
    renderer.loadComposition(synth_->compositionData(), synth_->loopDuration());

    std::vector<float> samples(totalSamples);
    renderer.renderOffline(samples.data(), totalSamples);

    const auto pcm = clay::sound::PcmBuffer::fromFloats(std::move(samples), sampleRate);
    std::string err;
    if (!pcm.saveWav(path.toStdString(), &err)) {
        qWarning() << "ChipMood: failed to write WAV to" << path
                   << "reason:" << QString::fromStdString(err);
        return;
    }

    qDebug() << "[ChipMood] WAV exported to:" << path;
    emit exportFinished(path);
#endif
}

#ifndef __EMSCRIPTEN__

// Scale definitions (semitone offsets from root)
static const QMap<QString, QList<int>> kScales = {
    {"major",      {0, 2, 4, 5, 7, 9, 11}},
    {"minor",      {0, 2, 3, 5, 7, 8, 10}},
    {"dorian",     {0, 2, 3, 5, 7, 9, 10}},
    {"phrygian",   {0, 1, 3, 5, 7, 8, 10}},
    {"lydian",     {0, 2, 4, 6, 7, 9, 11}},
    {"mixolydian", {0, 2, 4, 5, 7, 9, 10}},
    {"pentatonic", {0, 2, 4, 7, 9}},
    {"blues",      {0, 3, 5, 6, 7, 10}}
};

static double midiToFreq(int midi) {
    return 440.0 * std::pow(2.0, (midi - 69) / 12.0);
}

static double scaleNote(const QList<int> &scale, int degree, int root, int octaveOff) {
    int oct = degree / scale.size();
    int idx = ((degree % scale.size()) + scale.size()) % scale.size();
    return midiToFreq(root + scale[idx] + oct * 12 + octaveOff * 12);
}

// Simple seeded PRNG (mulberry32)
static uint32_t mulberry32(uint32_t &state) {
    state += 0x6D2B79F5;
    uint32_t t = state;
    t = (t ^ (t >> 15)) * (t | 1);
    t ^= t + (t ^ (t >> 7)) * (t | 61);
    return t ^ (t >> 14);
}

static double rngFloat(uint32_t &state) {
    return mulberry32(state) / 4294967296.0;
}

// Map arpStyle to a base pattern
static QList<int> arpPattern(const QString &style) {
    if (style == "flowing")     return {0,2,4,6, 0,2,4,7, 0,2,5,6, 0,2,4,6};
    if (style == "pulsing")     return {0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,2,0};
    if (style == "bright")      return {0,2,4,2, 0,2,4,5, 0,2,4,2, 0,4,2,0};
    if (style == "sparse")      return {0,-1,-1,-1, 2,-1,-1,-1, 4,-1,-1,-1, 2,-1,-1,-1};
    if (style == "majestic")    return {0,-1,4,-1, 0,-1,7,-1, 0,-1,4,-1, 0,-1,5,-1};
    if (style == "wave")        return {0,1,2,3, 4,3,2,1, 0,1,2,3, 4,5,4,3};
    if (style == "exotic")      return {0,1,4,1, 0,1,5,1, 0,1,4,1, 0,3,1,0};
    if (style == "crystalline") return {0,-1,4,-1, 7,-1,4,-1, 0,-1,5,-1, 7,-1,5,-1};
    return {0,2,4,6, 0,2,4,7};
}

static QList<int> melodyPattern(const QString &style) {
    if (style == "flowing")     return {4,3,2,1, 2,-1,-1,-1, 4,5,4,3, 2,-1,-1,-1};
    if (style == "pulsing")     return {0,-1,1,-1, 0,-1,-1,-1, -1,-1,2,-1, 1,-1,-1,-1};
    if (style == "bright")      return {4,2,0,2, 4,4,4,-1, 5,4,2,4, 5,5,5,-1};
    if (style == "sparse")      return {2,-1,-1,-1, -1,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1};
    if (style == "majestic")    return {4,-1,5,-1, 7,-1,-1,-1, 5,-1,4,-1, 2,-1,-1,-1};
    if (style == "wave")        return {2,3,4,5, 4,3,2,-1, 3,4,5,6, 5,4,3,-1};
    if (style == "exotic")      return {0,1,3,-1, 5,-1,-1,-1, 3,1,0,-1, -1,-1,-1,-1};
    if (style == "crystalline") return {7,-1,-1,-1, 5,-1,-1,-1, 4,-1,-1,-1, -1,-1,-1,-1};
    return {4,3,2,1, 2,-1,-1,-1};
}

void ChipMood::buildDesktopComposition()
{
    if (!synth_ || preset_.isEmpty()) return;

    const auto scale = kScales.value(scale_, kScales["dorian"]);
    const auto tempoRange = preset_["tempoRange"].toList();
    const auto rootRange = preset_["rootRange"].toList();
    const double echo = preset_.value("echo", 0.3).toDouble();
    const double warmth = preset_.value("warmth", 0.5).toDouble();
    const QString arpStyle = preset_.value("arpStyle", "flowing").toString();
    const auto sectionPat = preset_.value("sectionPattern", QVariantList{16,16,16,8}).toList();

    uint32_t rng = static_cast<uint32_t>(seed_);

    // Derive tempo and root from seed within ranges
    int tLo = tempoRange.size() >= 2 ? tempoRange[0].toInt() : 80;
    int tHi = tempoRange.size() >= 2 ? tempoRange[1].toInt() : 100;
    tempo_ = tLo + static_cast<int>(rngFloat(rng) * (tHi - tLo));
    int rLo = rootRange.size() >= 2 ? rootRange[0].toInt() : 48;
    int rHi = rootRange.size() >= 2 ? rootRange[1].toInt() : 55;
    int root = rLo + static_cast<int>(rngFloat(rng) * (rHi - rLo));

    const double secPerBeat = 60.0 / tempo_;
    const double stepDur = 0.25 * secPerBeat; // 16th note

    // Calculate total beats across all sections
    int totalBeats = 0;
    for (const auto &s : sectionPat) totalBeats += s.toInt();
    int totalSteps = totalBeats * 4; // 16th notes
    double loopDuration = totalSteps * stepDur;

    // Get patterns
    auto arp = arpPattern(arpStyle);
    auto mel = melodyPattern(arpStyle); // use same style for melody

    std::vector<NoteEvent> notes;

    for (int step = 0; step < totalSteps; ++step) {
        double t = step * stepDur;

        // Swing: offset every other 16th note for shuffle feel
        if (step % 2 == 1)
            t += swing_ * stepDur * 0.33;

        // Per-step variation RNG (deterministic, independent of composition seed)
        uint32_t varRng = static_cast<uint32_t>(seed_ * 7 + step);

        // Arpeggio layer
        if (layers_.contains("arp") && !arp.isEmpty()) {
            int deg = arp[step % arp.size()];
            if (deg >= 0) {
                if (variation_ > 0 && rngFloat(varRng) < variation_ * 0.15)
                    deg += (rngFloat(varRng) < 0.5) ? 1 : -1;
                double noteT = t;
                if (variation_ > 0)
                    noteT += (rngFloat(varRng) - 0.5) * variation_ * stepDur * 0.1;
                double freq = scaleNote(scale, deg, root, 1 + octaveShift_);
                double vol = 0.3 * (0.5 + intensity_ * 0.5);
                notes.push_back({noteT, freq, stepDur * 0.9, vol, Voice::Triangle});
            }
        }

        // Melody layer (half-note resolution)
        if (layers_.contains("melody") && (step % 2 == 0) && !mel.isEmpty()) {
            int deg = mel[(step / 2) % mel.size()];
            if (deg >= 0) {
                if (variation_ > 0 && rngFloat(varRng) < variation_ * 0.1)
                    deg += (rngFloat(varRng) < 0.5) ? 1 : -1;
                double noteT = t;
                if (variation_ > 0)
                    noteT += (rngFloat(varRng) - 0.5) * variation_ * stepDur * 0.05;
                double freq = scaleNote(scale, deg, root, 0 + octaveShift_);
                double vol = 0.25 * (0.5 + intensity_ * 0.5);
                notes.push_back({noteT, freq, stepDur * 1.8, vol, Voice::Sine});
            }
        }

        // Pad layer (whole-note resolution)
        if (layers_.contains("pad") && (step % 16 == 0)) {
            double freq = scaleNote(scale, 0, root, -1 + octaveShift_);
            double vol = 0.15 * (0.5 + intensity_ * 0.5);
            notes.push_back({t, freq, stepDur * 16, vol, Voice::Sine});
        }

        // Bass layer (half-note resolution)
        if (layers_.contains("bass") && (step % 2 == 0)) {
            int bassPattern[] = {0, -1, 0, -1, 2, -1, 0, -1};
            int deg = bassPattern[(step / 2) % 8];
            if (deg >= 0) {
                double noteT = t;
                if (variation_ > 0)
                    noteT += (rngFloat(varRng) - 0.5) * variation_ * stepDur * 0.08;
                double freq = scaleNote(scale, deg, root, -2 + octaveShift_);
                double vol = 0.2 * (0.5 + intensity_ * 0.5);
                notes.push_back({noteT, freq, stepDur * 1.8, vol, Voice::Triangle});
            }
        }
    }

    // Configure synth effects
    double filterHz = 4000.0 + (1.0 - warmth) * 12000.0;
    filterHz *= (0.5 + brightness_ * 0.5);
    synth_->setFilterCutoff(filterHz);
    synth_->setEchoMix(echo);
    synth_->setVolume(volume_);

    synth_->loadComposition(notes, loopDuration);
}

#endif // !__EMSCRIPTEN__
