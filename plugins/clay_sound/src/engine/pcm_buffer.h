// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// PcmBuffer — mono float PCM held in memory, plus a minimal WAV loader
// covering the formats we actually see for game SFX: 8/16/24/32-bit
// signed PCM and 32-bit float, 1..N channels (downmixed to mono on load).

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace clay::sound {

struct PcmBuffer
{
    std::vector<float> samples;   // mono float, range ~[-1,1]
    int sampleRate = 0;

    bool empty() const { return samples.empty(); }
    size_t frames() const { return samples.size(); }

    // Load a WAV file into a PcmBuffer. Returns nullopt on I/O or
    // format errors; `error` (if non-null) is populated with a short
    // human-readable reason.
    static std::optional<PcmBuffer> loadWav(const std::string& path,
                                            std::string* error = nullptr);

    // Construct in-memory (for tests and synth-to-sample baking).
    static PcmBuffer fromFloats(std::vector<float> mono, int sampleRate);

    // Write this buffer to a 16-bit signed PCM mono WAV file. Returns
    // true on success; `error` (if non-null) carries the failure reason.
    bool saveWav(const std::string& path, std::string* error = nullptr) const;
};

} // namespace clay::sound
