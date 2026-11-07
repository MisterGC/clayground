// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Engine — hosts instruments + scheduler + voice pool. The single
// offline renderer entrypoint used both by tests and (at later stages)
// by platform sinks that pull sample buffers.
//
// The mix is stereo: every voice renders mono, is panned into the
// stereo buffer of its instrument's bus, and the buses are summed into
// the output, each scaled by its volume. A bus runs its echo and its
// reverb (bus_effects.h) over its mix before the volume, both off by
// default. Live playback and offline renders run this one mix; a mono
// render is its downmix.

#pragma once

#include "bus.h"
#include "bus_effects.h"
#include "scheduler.h"
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <vector>

namespace clay::sound {

class IInstrument;
class IVoice;

class Engine
{
public:
    explicit Engine(int sampleRate);
    ~Engine();

    Engine(const Engine&) = delete;
    Engine& operator=(const Engine&) = delete;

    // Register an instrument. Takes ownership. Returns its id (>= 0).
    // Ids are stable for the lifetime of the engine — removeInstrument()
    // tombstones the slot rather than reindexing, so existing ids never
    // change meaning.
    int addInstrument(std::unique_ptr<IInstrument> inst);

    // Drop an instrument and any of its still-active voices. Idempotent.
    void removeInstrument(int id);

    // Non-owning lookup; returns nullptr for unknown or removed ids.
    IInstrument* instrumentAt(int id) const;

    // Enqueue an event on the scheduler. Returns the scheduler ticket.
    EventId schedule(const NoteEvent& ev);

    // Cancel a pending event (before it fires).
    bool cancel(EventId id);

    // Remove all pending events; active voices keep ringing until they
    // self-finish. Use resetVoices() to also silence the voice pool.
    void clearSchedule();

    // End what one instrument plays: cancel its pending events and let
    // each of its active voices run its own release from the current
    // frame (IVoice::onRelease). The voices are reaped once released;
    // the instrument stays registered and plays on the next event.
    void releaseInstrument(int id);

    // Drop all active voices immediately (hard cut).
    void resetVoices();

    // A note whose instrument already rings maxVoices() voices cuts the
    // oldest of them when it starts (a hard cut, no release).

    // Render `frames` stereo frames into `out` (interleaved L, R; length
    // 2 * frames). `out` is overwritten, not accumulated. Advances
    // currentFrame by `frames`. Each voice's contribution is scaled by
    // its instrument's `gain()`, its note's gain stage and the pan
    // gains of instrument pan + note pan, mixed into the instrument's
    // bus; every bus runs its echo, then its reverb, and is scaled by
    // its gain into `out`. A send (addSend()) runs its echo, then its
    // reverb, and adds them to its bus before the bus effects. A bus or
    // a send with an effect on renders even while none of its voices
    // ring, so the tail plays out.
    void renderStereo(float* out, int frames);

    // Render `frames` mono samples into `out`: the stereo mix folded
    // down as (L + R) / 2. Content panned to the centre renders exactly
    // the samples of a centred voice, the same as before stereo.
    void renderOffline(float* out, int frames);

    // Linear volume of a bus in [0, 1], default 1. Read on every mix
    // pass; safe to update while the audio thread renders.
    void  setBusGain(Bus bus, float g);
    float busGain(Bus bus) const;

    // The echo and the reverb of a bus. Their setters are safe to call
    // while the audio thread renders; process() is the engine's.
    Echo&   echo(Bus bus)   { return echo_[static_cast<int>(bus)]; }
    Reverb& reverb(Bus bus) { return reverb_[static_cast<int>(bus)]; }

    // A send is an echo and a reverb of their own that a set of notes
    // feeds besides its bus (a song's, so that its echo hears only the
    // tracks the song lets into it). Every note naming the send through
    // NoteEvent::send feeds its reverb; one that also sets sendEcho
    // feeds the echo, whose repeats then feed the reverb too. What both
    // add plays on the send's bus; the notes themselves play on their
    // instrument's bus exactly as without a send. Gains and pans are
    // the note's, as on the bus. Both effects start off; a send with
    // neither on adds nothing. Ids are never reused; a removed or
    // unknown id is no send, and its effects are nullptr.
    int     addSend(Bus bus);
    void    removeSend(int id);
    Echo*   sendEcho(int id);
    Reverb* sendReverb(int id);

    // A gain stage is a volume a set of notes shares, whatever
    // instrument plays them (a SongPlayer's volume). A note names one
    // through NoteEvent::gainStage; its gain is read on every mix pass,
    // so changing it fades notes already ringing. Ids are never reused;
    // an unknown id is unity.
    int   addGainStage(float g = 1.0f);
    void  setGainStage(int id, float g);
    float gainStage(int id) const;

    int sampleRate() const { return sampleRate_; }
    int64_t currentFrame() const { return currentFrame_; }
    size_t activeVoices() const { return voices_.size(); }
    // Voices currently active for a specific instrument id.
    size_t activeVoices(int instrumentId) const;
    size_t pendingEvents() const { return scheduler_.pending(); }

private:
    struct ActiveVoice {
        int instrumentId = -1;          // owner; -1 means tombstoned
        std::unique_ptr<IVoice> voice;
        float pan = 0.0f;               // the note's own pan
        int gainStage = -1;
        int send = -1;
        bool sendEcho = false;
    };

    struct Send {
        Bus bus = Bus::Music;
        Echo echo;
        Reverb reverb;
        std::vector<float> echoIn;      // interleaved stereo, the notes the echo hears
        std::vector<float> reverbIn;    // every note of the send, then the echo
        std::vector<float> wet;         // what the send adds to its bus
        bool echoFed = false;           // per pass: a voice fed echoIn
        bool reverbFed = false;
    };
    Send* sendAt(int id) const;

    int sampleRate_;
    int64_t currentFrame_ = 0;

    Scheduler scheduler_;
    std::vector<std::unique_ptr<IInstrument>> instruments_; // sparse: nullptr after remove
    std::vector<ActiveVoice> voices_;
    std::vector<float> scratch_;        // one voice, mono; reused per render pass
    std::vector<float> stereo_;         // renderOffline's stereo mix before the fold
    std::vector<float> busMix_[kBusCount]; // interleaved stereo per bus
    std::atomic<float> busGain_[kBusCount] = {1.0f, 1.0f, 1.0f};
    Echo   echo_[kBusCount];
    Reverb reverb_[kBusCount];
    // unique_ptr so the atomics stay put when the vector grows.
    std::vector<std::unique_ptr<std::atomic<float>>> gainStages_;
    std::vector<std::unique_ptr<Send>> sends_;  // sparse: nullptr after remove
};

} // namespace clay::sound
