// (c) Clayground Contributors - MIT License, see "LICENSE" file
// ChipMood: SNES-style atmospheric music generator using Web Audio API

(function(global) {
    'use strict';

    // Audio context (shared)
    let audioCtx = null;

    // Master nodes
    let masterGain = null;
    let echoDelay = null;
    let echoGain = null;
    let lowpassFilter = null;

    // Sequencer state
    let isPlaying = false;
    let currentMood = null;
    let tempo = 85;
    let intensity = 0.5;
    let schedulerTimer = null;
    let nextNoteTime = 0;
    let currentStep = 0;

    // Scheduling constants
    const LOOKAHEAD = 25.0;  // ms - how frequently to call scheduler
    const SCHEDULE_AHEAD = 0.1;  // seconds - how far ahead to schedule

    // Scale definitions (MIDI note offsets from root)
    const SCALES = {
        dorian: [0, 2, 3, 5, 7, 9, 10],      // Mysterious, hopeful minor
        minor: [0, 2, 3, 5, 7, 8, 10],       // Natural minor - dark
        phrygian: [0, 1, 3, 5, 7, 8, 10],    // Exotic, tense
        major: [0, 2, 4, 5, 7, 9, 11],       // Bright, peaceful
        pentatonic: [0, 2, 4, 7, 9]          // Simple, mystical
    };

    // Mood definitions
    const MOODS = {
        mysterious_forest: {
            scale: 'dorian',
            root: 51,  // Eb3
            tempo: 85,
            layers: [
                { type: 'arpeggio', wave: 'triangle', octave: 1, pattern: [0, 2, 4, 6], rhythm: 0.25, volume: 0.3 },
                { type: 'melody', wave: 'sine', octave: 0, pattern: [4, 3, 2, 1, 2, -1, -1, -1], rhythm: 0.5, volume: 0.25 },
                { type: 'pad', wave: 'sine', octave: -1, pattern: [0], rhythm: 4, volume: 0.15 },
                { type: 'bass', wave: 'triangle', octave: -2, pattern: [0, -1, 0, -1, 2, -1, 0, -1], rhythm: 0.5, volume: 0.2 }
            ],
            echo: 0.3,
            warmth: 0.6
        },
        dark_dungeon: {
            scale: 'phrygian',
            root: 48,  // C3
            tempo: 100,
            layers: [
                { type: 'bass', wave: 'sawtooth', octave: -2, pattern: [0, 0, 1, 0, 0, 0, 1, 0], rhythm: 0.25, volume: 0.25 },
                { type: 'pad', wave: 'sine', octave: -1, pattern: [0, 2], rhythm: 2, volume: 0.12 },
                { type: 'percussion', wave: 'noise', pattern: [1, 0, 0, 0, 1, 0, 0, 0], rhythm: 0.25, volume: 0.1 },
                { type: 'melody', wave: 'square', octave: 0, pattern: [0, -1, 1, -1, 0, -1, -1, -1], rhythm: 0.5, volume: 0.15 }
            ],
            echo: 0.4,
            warmth: 0.7
        },
        peaceful_village: {
            scale: 'major',
            root: 55,  // G3
            tempo: 95,
            layers: [
                { type: 'arpeggio', wave: 'triangle', octave: 1, pattern: [0, 2, 4, 2], rhythm: 0.25, volume: 0.25 },
                { type: 'melody', wave: 'sine', octave: 0, pattern: [4, 2, 0, 2, 4, 4, 4, -1], rhythm: 0.5, volume: 0.3 },
                { type: 'bass', wave: 'triangle', octave: -2, pattern: [0, -1, 4, -1], rhythm: 0.5, volume: 0.2 },
                { type: 'pad', wave: 'sine', octave: -1, pattern: [0, 4], rhythm: 2, volume: 0.1 }
            ],
            echo: 0.2,
            warmth: 0.5
        }
    };

    // Convert MIDI note to frequency
    function midiToFreq(midi) {
        return 440 * Math.pow(2, (midi - 69) / 12);
    }

    // Get scale note
    function getScaleNote(scaleName, degree, root, octaveOffset) {
        const scale = SCALES[scaleName];
        const octave = Math.floor(degree / scale.length);
        const noteInScale = degree % scale.length;
        const midiNote = root + scale[noteInScale] + (octave * 12) + (octaveOffset * 12);
        return midiToFreq(midiNote);
    }

    // Initialize audio context and effects
    function initAudio() {
        if (audioCtx) return;

        audioCtx = new (window.AudioContext || window.webkitAudioContext)();

        // Master gain
        masterGain = audioCtx.createGain();
        masterGain.gain.value = 0.7;

        // Low-pass filter (SNES warmth)
        lowpassFilter = audioCtx.createBiquadFilter();
        lowpassFilter.type = 'lowpass';
        lowpassFilter.frequency.value = 8000;
        lowpassFilter.Q.value = 0.7;

        // Echo/delay
        echoDelay = audioCtx.createDelay(1.0);
        echoDelay.delayTime.value = 0.15;

        echoGain = audioCtx.createGain();
        echoGain.gain.value = 0.3;

        // Routing: source -> lowpass -> master -> destination
        //                           \-> delay -> echoGain -> lowpass (feedback loop)
        lowpassFilter.connect(masterGain);
        masterGain.connect(audioCtx.destination);

        // Echo feedback loop
        masterGain.connect(echoDelay);
        echoDelay.connect(echoGain);
        echoGain.connect(lowpassFilter);
    }

    // Play a single note
    function playNote(freq, wave, volume, duration, startTime) {
        if (!audioCtx) return;

        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();

        if (wave === 'noise') {
            // White noise via buffer
            const bufferSize = audioCtx.sampleRate * duration;
            const buffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
            const data = buffer.getChannelData(0);
            for (let i = 0; i < bufferSize; i++) {
                data[i] = Math.random() * 2 - 1;
            }
            const noise = audioCtx.createBufferSource();
            noise.buffer = buffer;

            // Bandpass for more percussive sound
            const bandpass = audioCtx.createBiquadFilter();
            bandpass.type = 'bandpass';
            bandpass.frequency.value = 1000;
            bandpass.Q.value = 1;

            noise.connect(bandpass);
            bandpass.connect(gain);
            gain.connect(lowpassFilter);

            gain.gain.setValueAtTime(volume, startTime);
            gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration * 0.8);

            noise.start(startTime);
            noise.stop(startTime + duration);
            return;
        }

        osc.type = wave;
        osc.frequency.value = freq;

        osc.connect(gain);
        gain.connect(lowpassFilter);

        // ADSR-like envelope
        const attack = 0.01;
        const decay = 0.1;
        const sustain = 0.6;
        const release = duration * 0.3;

        gain.gain.setValueAtTime(0, startTime);
        gain.gain.linearRampToValueAtTime(volume, startTime + attack);
        gain.gain.linearRampToValueAtTime(volume * sustain, startTime + attack + decay);
        gain.gain.setValueAtTime(volume * sustain, startTime + duration - release);
        gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);

        osc.start(startTime);
        osc.stop(startTime + duration + 0.1);
    }

    // Schedule notes for a layer
    function scheduleLayer(layer, mood, stepTime, step) {
        const patternIndex = step % layer.pattern.length;
        const noteValue = layer.pattern[patternIndex];

        // -1 means rest
        if (noteValue === -1) return;

        const secondsPerBeat = 60.0 / tempo;
        const duration = layer.rhythm * secondsPerBeat * 0.9;

        // Adjust volume based on intensity
        const layerVolume = layer.volume * (0.5 + intensity * 0.5);

        if (layer.wave === 'noise') {
            playNote(0, 'noise', layerVolume * (noteValue > 0 ? 1 : 0), duration, stepTime);
        } else {
            const freq = getScaleNote(mood.scale, noteValue, mood.root, layer.octave);
            playNote(freq, layer.wave, layerVolume, duration, stepTime);
        }
    }

    // Main scheduler
    function scheduler() {
        if (!isPlaying || !currentMood) return;

        const mood = MOODS[currentMood];
        if (!mood) return;

        while (nextNoteTime < audioCtx.currentTime + SCHEDULE_AHEAD) {
            // Schedule each layer
            mood.layers.forEach((layer, i) => {
                // Skip some layers at low intensity
                if (intensity < 0.3 && i > 1) return;
                if (intensity < 0.6 && i > 2) return;

                const layerStep = Math.floor(currentStep / (layer.rhythm / 0.25));
                scheduleLayer(layer, mood, nextNoteTime, layerStep);
            });

            // Advance time (16th note resolution)
            const secondsPerBeat = 60.0 / tempo;
            nextNoteTime += 0.25 * secondsPerBeat;
            currentStep++;
        }

        schedulerTimer = setTimeout(scheduler, LOOKAHEAD);
    }

    // Public API
    const ChipMood = {
        // Initialize (must be called from user gesture)
        init: function() {
            initAudio();
            if (audioCtx.state === 'suspended') {
                audioCtx.resume();
            }
            return this;
        },

        // Set mood
        setMood: function(moodName) {
            if (!MOODS[moodName]) {
                console.warn('ChipMood: Unknown mood:', moodName);
                return this;
            }
            currentMood = moodName;
            const mood = MOODS[moodName];
            tempo = mood.tempo;

            // Update effects
            if (echoGain) echoGain.gain.value = mood.echo;
            if (lowpassFilter) {
                lowpassFilter.frequency.value = 4000 + (1 - mood.warmth) * 12000;
            }

            return this;
        },

        // Set tempo
        setTempo: function(bpm) {
            tempo = Math.max(60, Math.min(180, bpm));
            return this;
        },

        // Set intensity (0.0 - 1.0)
        setIntensity: function(value) {
            intensity = Math.max(0, Math.min(1, value));
            return this;
        },

        // Set volume (0.0 - 1.0)
        setVolume: function(value) {
            if (masterGain) {
                masterGain.gain.value = Math.max(0, Math.min(1, value));
            }
            return this;
        },

        // Play
        play: function() {
            if (!audioCtx) this.init();
            if (!currentMood) this.setMood('mysterious_forest');

            isPlaying = true;
            currentStep = 0;
            nextNoteTime = audioCtx.currentTime;
            scheduler();
            return this;
        },

        // Stop
        stop: function() {
            isPlaying = false;
            if (schedulerTimer) {
                clearTimeout(schedulerTimer);
                schedulerTimer = null;
            }
            return this;
        },

        // Pause
        pause: function() {
            isPlaying = false;
            if (schedulerTimer) {
                clearTimeout(schedulerTimer);
                schedulerTimer = null;
            }
            return this;
        },

        // Resume
        resume: function() {
            if (!isPlaying && currentMood) {
                isPlaying = true;
                nextNoteTime = audioCtx.currentTime;
                scheduler();
            }
            return this;
        },

        // Randomize (subtle variations)
        randomize: function() {
            // Slight tempo variation
            const mood = MOODS[currentMood];
            if (mood) {
                tempo = mood.tempo + (Math.random() - 0.5) * 10;
            }
            return this;
        },

        // Get available moods
        getMoods: function() {
            return Object.keys(MOODS);
        },

        // Check if playing
        isPlaying: function() {
            return isPlaying;
        },

        // Get current mood
        getCurrentMood: function() {
            return currentMood;
        }
    };

    // Export
    global.ChipMood = ChipMood;

})(typeof window !== 'undefined' ? window : this);
