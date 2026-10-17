// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "sound_files.h"

#include "engine/pcm_buffer.h"
#include "sfx/sfx_parser.h"
#include "song/song_parser.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>

namespace clay::sound {

namespace {

bool fail(std::string *error, const QString &why)
{
    if (error) *error = why.toStdString();
    return false;
}

bool readAll(const QString &path, QByteArray *out, std::string *error)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return fail(error, QStringLiteral("cannot open %1").arg(path));
    *out = f.readAll();
    return true;
}

void putU16(std::vector<uint8_t> &b, uint16_t v)
{
    b.push_back(static_cast<uint8_t>(v & 0xff));
    b.push_back(static_cast<uint8_t>(v >> 8));
}

void putU32(std::vector<uint8_t> &b, uint32_t v)
{
    for (int i = 0; i < 4; ++i) b.push_back(static_cast<uint8_t>((v >> (8 * i)) & 0xff));
}

void putTag(std::vector<uint8_t> &b, const char *tag)
{
    b.insert(b.end(), tag, tag + 4);
}

} // namespace

bool loadRecipe(const std::string &path, RecipeFile *out, std::string *error)
{
    const QString file = QString::fromStdString(path);
    QByteArray bytes;
    if (!readAll(file, &bytes, error)) return false;
    const auto res = SfxParser::parse(bytes);
    if (!res.ok) return fail(error, res.error);

    RecipeFile loaded;
    loaded.recipe = res.recipe;
    loaded.samples.resize(res.recipe.layers.size());
    // A sample path is relative to the recipe file.
    const QDir base = QFileInfo(file).absoluteDir();
    for (int i = 0; i < res.recipe.layers.size(); ++i) {
        const SfxLayer &layer = res.recipe.layers[i];
        if (layer.source != SfxSource::Sample) continue;
        const QString what = QStringLiteral("layers[%1].sample").arg(i);
        QByteArray wav;
        std::string why;
        if (!readAll(QDir::cleanPath(base.filePath(layer.sample)), &wav, &why))
            return fail(error, QStringLiteral("%1: %2").arg(what, QString::fromStdString(why)));
        auto pcm = PcmBuffer::loadWavFromBytes(reinterpret_cast<const std::uint8_t *>(wav.constData()),
                                               static_cast<std::size_t>(wav.size()), &why);
        if (!pcm) return fail(error, QStringLiteral("%1: %2").arg(what, QString::fromStdString(why)));
        loaded.samples[i] = std::make_shared<const PcmBuffer>(std::move(*pcm));
    }
    if (out) *out = std::move(loaded);
    return true;
}

bool loadSong(const std::string &path, SongModel *out, std::string *error)
{
    QByteArray bytes;
    if (!readAll(QString::fromStdString(path), &bytes, error)) return false;
    const auto res = SongParser::parse(bytes);
    if (!res.ok) return fail(error, res.error);
    if (out) *out = res.model;
    return true;
}

bool writeWav(const std::string &path, const std::vector<float> &samples,
              int channels, int sampleRate, WavFormat format, std::string *error)
{
    if (channels < 1 || channels > 2) return fail(error, QStringLiteral("channels must be 1 or 2"));
    if (sampleRate <= 0) return fail(error, QStringLiteral("invalid sample rate"));
    if (samples.size() % static_cast<size_t>(channels) != 0)
        return fail(error, QStringLiteral("sample count is not a multiple of the channels"));

    const bool isFloat = format == WavFormat::Float32;
    const uint16_t bits = isFloat ? 32 : 16;
    const uint16_t blockAlign = static_cast<uint16_t>(channels * bits / 8);
    const uint32_t dataBytes = static_cast<uint32_t>(samples.size() / channels) * blockAlign;

    std::vector<uint8_t> b;
    b.reserve(44 + dataBytes);
    putTag(b, "RIFF");
    putU32(b, 36 + dataBytes);
    putTag(b, "WAVE");
    putTag(b, "fmt ");
    putU32(b, 16);
    putU16(b, isFloat ? 3 : 1);         // WAVE_FORMAT_IEEE_FLOAT : PCM
    putU16(b, static_cast<uint16_t>(channels));
    putU32(b, static_cast<uint32_t>(sampleRate));
    putU32(b, static_cast<uint32_t>(sampleRate) * blockAlign);
    putU16(b, blockAlign);
    putU16(b, bits);
    putTag(b, "data");
    putU32(b, dataBytes);
    for (float s : samples) {
        if (isFloat) {
            uint32_t u;
            std::memcpy(&u, &s, 4);
            putU32(b, u);
        } else {
            const long q = std::lround(std::clamp(s, -1.0f, 1.0f) * 32767.0f);
            putU16(b, static_cast<uint16_t>(static_cast<int16_t>(std::clamp(q, -32768L, 32767L))));
        }
    }

    std::FILE *f = std::fopen(path.c_str(), "wb");
    if (!f) return fail(error, QStringLiteral("cannot write %1").arg(QString::fromStdString(path)));
    const bool ok = std::fwrite(b.data(), 1, b.size(), f) == b.size();
    return (std::fclose(f) == 0 && ok) || fail(error, QStringLiteral("write failed"));
}

} // namespace clay::sound
