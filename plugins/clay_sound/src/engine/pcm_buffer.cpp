// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "pcm_buffer.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <utility>

namespace clay::sound {

PcmBuffer PcmBuffer::fromFloats(std::vector<float> mono, int sampleRate)
{
    PcmBuffer b;
    b.samples = std::move(mono);
    b.sampleRate = sampleRate;
    return b;
}

namespace {

struct FmtChunk
{
    uint16_t audioFormat = 0;   // 1 = PCM, 3 = IEEE float
    uint16_t channels    = 0;
    uint32_t sampleRate  = 0;
    uint32_t byteRate    = 0;
    uint16_t blockAlign  = 0;
    uint16_t bitsPerSample = 0;
};

static uint32_t read_u32(const uint8_t* p) { return static_cast<uint32_t>(p[0]) | (static_cast<uint32_t>(p[1]) << 8) | (static_cast<uint32_t>(p[2]) << 16) | (static_cast<uint32_t>(p[3]) << 24); }
static uint16_t read_u16(const uint8_t* p) { return static_cast<uint16_t>(p[0]) | (static_cast<uint16_t>(p[1]) << 8); }
static int16_t  read_i16(const uint8_t* p) { return static_cast<int16_t>(read_u16(p)); }
static int32_t  read_i24(const uint8_t* p) {
    int32_t v = static_cast<int32_t>(p[0]) | (static_cast<int32_t>(p[1]) << 8) | (static_cast<int32_t>(p[2]) << 16);
    if (v & 0x00800000) v |= 0xff000000; // sign-extend 24 -> 32
    return v;
}
static int32_t read_i32(const uint8_t* p) { return static_cast<int32_t>(read_u32(p)); }
static float   read_f32(const uint8_t* p) { float f; std::memcpy(&f, p, 4); return f; }

static bool setError(std::string* err, const char* msg)
{
    if (err) *err = msg;
    return false;
}

} // namespace

std::optional<PcmBuffer> PcmBuffer::loadWav(const std::string& path, std::string* error)
{
    std::FILE* f = std::fopen(path.c_str(), "rb");
    if (!f) { setError(error, "open failed"); return std::nullopt; }

    std::fseek(f, 0, SEEK_END);
    long fileSize = std::ftell(f);
    std::fseek(f, 0, SEEK_SET);
    if (fileSize < 44) { std::fclose(f); setError(error, "file too small"); return std::nullopt; }

    std::vector<uint8_t> data(static_cast<size_t>(fileSize));
    if (std::fread(data.data(), 1, data.size(), f) != data.size()) {
        std::fclose(f); setError(error, "read failed"); return std::nullopt;
    }
    std::fclose(f);

    const uint8_t* p = data.data();
    if (std::memcmp(p, "RIFF", 4) != 0) { setError(error, "not RIFF"); return std::nullopt; }
    if (std::memcmp(p + 8, "WAVE", 4) != 0) { setError(error, "not WAVE"); return std::nullopt; }

    FmtChunk fmt;
    const uint8_t* dataPtr = nullptr;
    uint32_t dataBytes = 0;

    size_t pos = 12;
    while (pos + 8 <= data.size()) {
        const uint8_t* chunk = p + pos;
        const char* id = reinterpret_cast<const char*>(chunk);
        const uint32_t sz = read_u32(chunk + 4);
        const uint8_t* body = chunk + 8;
        if (std::memcmp(id, "fmt ", 4) == 0) {
            if (sz < 16) { setError(error, "fmt too small"); return std::nullopt; }
            fmt.audioFormat   = read_u16(body + 0);
            fmt.channels      = read_u16(body + 2);
            fmt.sampleRate    = read_u32(body + 4);
            fmt.byteRate      = read_u32(body + 8);
            fmt.blockAlign    = read_u16(body + 12);
            fmt.bitsPerSample = read_u16(body + 14);
        } else if (std::memcmp(id, "data", 4) == 0) {
            dataPtr = body;
            dataBytes = sz;
        }
        pos += 8 + sz + (sz & 1); // chunks padded to even size
    }

    if (!dataPtr) { setError(error, "no data chunk"); return std::nullopt; }
    if (fmt.channels == 0) { setError(error, "no fmt chunk"); return std::nullopt; }

    const int channels = fmt.channels;
    const int bps      = fmt.bitsPerSample;
    const int fmtCode  = fmt.audioFormat;

    const int bytesPerSample = bps / 8;
    const size_t frameBytes  = static_cast<size_t>(bytesPerSample) * channels;
    if (frameBytes == 0) { setError(error, "bad block align"); return std::nullopt; }
    const size_t frameCount  = dataBytes / frameBytes;

    std::vector<float> mono;
    mono.reserve(frameCount);

    auto decodeSample = [&](const uint8_t* sp) -> float {
        if (fmtCode == 3 && bps == 32)     return read_f32(sp);
        if (fmtCode == 1 && bps == 16)     return static_cast<float>(read_i16(sp)) / 32768.0f;
        if (fmtCode == 1 && bps == 24)     return static_cast<float>(read_i24(sp)) / 8388608.0f;
        if (fmtCode == 1 && bps == 32)     return static_cast<float>(read_i32(sp)) / 2147483648.0f;
        if (fmtCode == 1 && bps == 8) {
            // unsigned 8-bit PCM, centered at 128
            return (static_cast<float>(sp[0]) - 128.0f) / 128.0f;
        }
        return 0.0f;
    };

    const bool formatOk =
        (fmtCode == 3 && bps == 32) ||
        (fmtCode == 1 && (bps == 8 || bps == 16 || bps == 24 || bps == 32));
    if (!formatOk) {
        setError(error, "unsupported PCM format");
        return std::nullopt;
    }

    for (size_t i = 0; i < frameCount; ++i) {
        const uint8_t* framePtr = dataPtr + i * frameBytes;
        float sum = 0.0f;
        for (int c = 0; c < channels; ++c)
            sum += decodeSample(framePtr + static_cast<size_t>(c) * bytesPerSample);
        mono.push_back(sum / static_cast<float>(channels));
    }

    PcmBuffer out;
    out.samples = std::move(mono);
    out.sampleRate = static_cast<int>(fmt.sampleRate);
    return out;
}

} // namespace clay::sound
