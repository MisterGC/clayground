// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Sample interpolation and the voice cap, measured (#427). The modes are
// told apart by what they do to a spectrum: the Gaussian taps roll off
// a tone at a quarter of the sample rate, and an octave down nearest
// leaves the strongest image above the tone, Gaussian the weakest. The
// cap counts the voices still ringing and which ones were cut. Sample
// equality is only asserted between renders on the same machine.

#include "audio_output.h"
#include "engine/engine.h"
#include "engine/instrument.h"
#include "engine/note_event.h"
#include "engine/pcm_buffer.h"
#include "engine/sample_voice.h"
#include "engine/sampler_instrument.h"
#include "engine/voice.h"
#include "sample_instrument.h"
#include "synth_instrument.h"

#include <QQmlComponent>
#include <QQmlEngine>
#include <QTemporaryDir>
#include <QtTest/QtTest>
#include <cmath>
#include <complex>
#include <memory>
#include <vector>

namespace cs = clay::sound;

static constexpr int    kRate = 44100;
static constexpr double kPi   = 3.14159265358979323846;

// Amplitude of `freq` in buf[from, from + n).
static double amplitudeAt(const std::vector<float> &buf, int from, int n, double freq)
{
    std::complex<double> acc = 0.0;
    for (int i = 0; i < n; ++i) {
        const double w = 2.0 * kPi * freq * i / kRate;
        acc += static_cast<double>(buf[from + i]) * std::complex<double>(std::cos(w), -std::sin(w));
    }
    return 2.0 * std::abs(acc) / n;
}

// A low and a high tone: 100 Hz and a quarter of the rate both divide
// 44.1 kHz, so a window of whole periods puts each on a bin of its own.
static constexpr double kLow     = 100.0;
static constexpr double kQuarter = kRate / 4.0;
static constexpr float  kToneAmp = 0.4f;

static std::vector<float> lowPlusQuarter(int frames)
{
    std::vector<float> s(frames);
    for (int i = 0; i < frames; ++i)
        s[i] = kToneAmp * static_cast<float>(std::sin(2.0 * kPi * kLow * i / kRate)
                                             + std::sin(2.0 * kPi * kQuarter * i / kRate));
    return s;
}

static std::shared_ptr<const cs::PcmBuffer> sineBuffer(double freq, int frames)
{
    std::vector<float> s(frames);
    for (int i = 0; i < frames; ++i)
        s[i] = static_cast<float>(std::sin(2.0 * kPi * freq * i / kRate));
    return std::make_shared<const cs::PcmBuffer>(cs::PcmBuffer::fromFloats(std::move(s), kRate));
}

// Plays `source` once through a SampleVoice on an engine of its own and
// returns the mono render. `ratio` is the playback rate: 1 reads every
// source sample, 0.5 plays an octave down.
static std::vector<float> playSample(std::shared_ptr<const cs::PcmBuffer> source,
                                     const cs::SampleVoice::Patch *patch,
                                     double ratio, int frames)
{
    cs::Engine eng(kRate);
    auto core = std::make_unique<cs::SamplerInstrument>();
    core->setSource(std::move(source));
    core->setRootMidiNote(69);                       // 440 Hz plays at the native rate
    if (patch) core->setDefaultPatch(*patch);
    cs::NoteEvent ev;
    ev.durationFrames = frames;
    ev.freqHz         = 440.0 * ratio;
    ev.instrumentId   = eng.addInstrument(std::move(core));
    eng.schedule(ev);
    std::vector<float> out(frames);
    eng.renderOffline(out.data(), frames);
    return out;
}

static cs::SampleVoice::Patch patchWith(cs::SampleVoice::Interpolation mode)
{
    cs::SampleVoice::Patch p;
    p.interpolation = mode;
    return p;
}

// A voice that only says when it is cut: its destructor logs its tag.
class TaggedVoice : public cs::IVoice
{
public:
    TaggedVoice(int tag, std::vector<int> &dropped) : tag_(tag), dropped_(dropped) {}
    ~TaggedVoice() override { dropped_.push_back(tag_); }
    void onNoteOn(const cs::NoteEvent &, int) override {}
    void onNoteOff(int64_t) override {}
    void render(float *, int, int64_t) override {}
    bool isFinished(int64_t) const override { return false; }
private:
    int tag_;
    std::vector<int> &dropped_;
};

class TaggedInstrument : public cs::IInstrument
{
public:
    explicit TaggedInstrument(std::vector<int> &dropped) : dropped_(dropped) {}
    std::unique_ptr<cs::IVoice> createVoice(const cs::NoteEvent &ev, cs::EventId, int) override
    {
        return std::make_unique<TaggedVoice>(static_cast<int>(ev.freqHz), dropped_);
    }
private:
    std::vector<int> &dropped_;
};

static cs::Engine &sharedEngine() { return cs::AudioOutput::instance().engine(); }

static std::vector<float> renderShared(int frames)
{
    std::vector<float> out(2 * static_cast<size_t>(frames));
    sharedEngine().renderStereo(out.data(), frames);
    return out;
}

static double peak(const std::vector<float> &buf)
{
    double p = 0.0;
    for (float s : buf) p = std::max(p, std::abs(static_cast<double>(s)));
    return p;
}

class SoundVoicesTest : public QObject
{
    Q_OBJECT
private slots:
    void initTestCase();
    void defaults();
    void defaultPatchIsLinear();
    void gaussianRollsOffTheHighs();
    void imagesOctaveDown();
    void modesSelectableFromQml();
    void unknownModeIsRejected();
    void capCutsTheOldest();
    void noCapKeepsEveryVoice();
    void thirtyTwoNotesAtEightVoices_data();
    void thirtyTwoNotesAtEightVoices();
    void cleanup();

private:
    QObject *createFromQml(const QByteArray &body);

    QQmlEngine qml_;
    QTemporaryDir dir_;
    QString wavPath_;
};

void SoundVoicesTest::initTestCase()
{
    qmlRegisterType<SampleInstrument>("Clayground.Sound", 1, 0, "SampleInstrument");
    qmlRegisterType<SynthInstrument>("Clayground.Sound", 1, 0, "SynthInstrument");

    // One second of the two tones, as a WAV a SampleInstrument loads.
    QVERIFY(dir_.isValid());
    wavPath_ = dir_.filePath("tones.wav");
    std::string err;
    QVERIFY2(cs::PcmBuffer::fromFloats(lowPlusQuarter(kRate), kRate)
                 .saveWav(wavPath_.toStdString(), &err),
             err.c_str());
}

void SoundVoicesTest::cleanup()
{
    sharedEngine().clearSchedule();
    sharedEngine().resetVoices();
}

QObject *SoundVoicesTest::createFromQml(const QByteArray &body)
{
    QQmlComponent c(&qml_);
    c.setData("import Clayground.Sound\n" + body, QUrl());
    QObject *o = c.create();
    if (!o) qWarning() << c.errorString();
    return o;
}

void SoundVoicesTest::defaults()
{
    SampleInstrument sample;
    QCOMPARE(sample.interpolation(), QStringLiteral("linear"));
    QCOMPARE(sample.maxVoices(), 0);
    SynthInstrument synth;
    QCOMPARE(synth.maxVoices(), 0);
    QCOMPARE(cs::SampleVoice::Patch{}.interpolation, cs::SampleVoice::Interpolation::Linear);
}

// The default patch renders the samples linear does, so a sample that
// names no mode sounds as it did before the modes existed.
void SoundVoicesTest::defaultPatchIsLinear()
{
    const auto src = sineBuffer(1000.0, kRate);
    const auto linear = patchWith(cs::SampleVoice::Interpolation::Linear);
    const auto a = playSample(src, nullptr, 0.73, 8820);
    const auto b = playSample(src, &linear, 0.73, 8820);
    QCOMPARE(a, b);
    QVERIFY(peak(a) > 0.9);
}

// At the native rate every read lands on a source sample. Nearest and
// linear give the sample back, so both tones keep their level; the
// Gaussian taps still weigh in the neighbours, which cancel half of a
// tone at a quarter of the rate and leave a 100 Hz tone all but whole.
void SoundVoicesTest::gaussianRollsOffTheHighs()
{
    using I = cs::SampleVoice::Interpolation;
    const auto src = std::make_shared<const cs::PcmBuffer>(
        cs::PcmBuffer::fromFloats(lowPlusQuarter(kRate), kRate));
    constexpr int kFrom = 441, kLen = 8820;          // 20 periods of 100 Hz

    for (I mode : {I::Nearest, I::Linear, I::Gaussian}) {
        const auto patch = patchWith(mode);
        const auto out = playSample(src, &patch, 1.0, kFrom + kLen);
        const double low  = amplitudeAt(out, kFrom, kLen, kLow) / kToneAmp;
        const double high = amplitudeAt(out, kFrom, kLen, kQuarter) / kToneAmp;
        qInfo("mode %d: 100 Hz %.4f, 11025 Hz %.4f of the source", int(mode), low, high);
        QVERIFY2(std::abs(low - 1.0) < 0.01, qPrintable(QString::number(low)));
        if (mode == I::Gaussian)
            QVERIFY2(high > 0.5 && high < 0.75, qPrintable(QString::number(high)));
        else
            QVERIFY2(std::abs(high - 1.0) < 0.01, qPrintable(QString::number(high)));
    }
}

// An octave down every other read falls halfway between two samples.
// Nearest repeats each sample, which leaves a strong image of the tone
// mirrored at half the rate; linear leaves less, Gaussian the least.
void SoundVoicesTest::imagesOctaveDown()
{
    using I = cs::SampleVoice::Interpolation;
    constexpr double kTone  = 1102.5;                // a 2205 Hz source, halved
    constexpr double kImage = kRate / 2.0 - kTone;   // 20947.5 Hz
    constexpr int kFrom = 441, kLen = 17640;         // whole periods of both
    const auto src = sineBuffer(2 * kTone, kRate);

    double image[3] = {};
    for (I mode : {I::Nearest, I::Linear, I::Gaussian}) {
        const auto patch = patchWith(mode);
        const auto out = playSample(src, &patch, 0.5, kFrom + kLen);
        const double tone = amplitudeAt(out, kFrom, kLen, kTone);
        image[int(mode)] = amplitudeAt(out, kFrom, kLen, kImage);
        qInfo("mode %d: tone %.4f, image %.4f", int(mode), tone, image[int(mode)]);
        QVERIFY2(tone > 0.9, qPrintable(QString::number(tone)));
    }
    QVERIFY(image[int(I::Nearest)] > image[int(I::Linear)]);
    QVERIFY(image[int(I::Linear)] > image[int(I::Gaussian)]);
    QVERIFY(image[int(I::Gaussian)] < 0.01);
}

// Each mode set in QML reaches the notes the instrument plays: the
// quarter-rate tone of the loaded WAV keeps its level under nearest and
// linear and drops under gaussian.
void SoundVoicesTest::modesSelectableFromQml()
{
    constexpr int kFrom = 441, kLen = 8820;
    const QByteArray src = QUrl::fromLocalFile(wavPath_).toString().toUtf8();
    for (const char *mode : {"nearest", "linear", "gaussian"}) {
        std::unique_ptr<QObject> o(createFromQml(
            "SampleInstrument { source: \"" + src + "\"; rootNote: 69; interpolation: \""
            + mode + "\" }"));
        QVERIFY(o);
        auto *inst = qobject_cast<SampleInstrument *>(o.get());
        QVERIFY(inst->loaded());
        QCOMPARE(inst->property("interpolation").toString(), QString::fromLatin1(mode));

        QVERIFY(inst->triggerNote(69, 1.0, 0.3));
        const auto stereo = renderShared(kFrom + kLen);
        std::vector<float> left(stereo.size() / 2);
        for (size_t i = 0; i < left.size(); ++i) left[i] = stereo[2 * i];
        // The 16-bit WAV costs a little precision, hence the margins.
        const double low  = amplitudeAt(left, kFrom, kLen, kLow) / kToneAmp;
        const double high = amplitudeAt(left, kFrom, kLen, kQuarter) / kToneAmp;
        qInfo("%s from QML: 100 Hz %.4f, 11025 Hz %.4f", mode, low, high);
        QVERIFY2(std::abs(low - 1.0) < 0.01, qPrintable(QString::number(low)));
        if (qstrcmp(mode, "gaussian") == 0)
            QVERIFY2(high > 0.5 && high < 0.75, qPrintable(QString::number(high)));
        else
            QVERIFY2(std::abs(high - 1.0) < 0.01, qPrintable(QString::number(high)));
        cleanup();
    }
}

void SoundVoicesTest::unknownModeIsRejected()
{
    SampleInstrument inst;
    inst.setInterpolation("gaussian");
    QSignalSpy spy(&inst, &SampleInstrument::interpolationChanged);
    QTest::ignoreMessage(QtWarningMsg, QRegularExpression("unknown interpolation"));
    inst.setInterpolation("cubic");
    QCOMPARE(inst.interpolation(), QStringLiteral("gaussian"));
    QCOMPARE(spy.count(), 0);
}

// 32 notes one frame apart at a cap of 8: the 24 oldest are cut, in the
// order they started, and the 8 newest ring on.
void SoundVoicesTest::capCutsTheOldest()
{
    std::vector<int> dropped;
    {
        cs::Engine eng(kRate);
        auto inst = std::make_unique<TaggedInstrument>(dropped);
        inst->setMaxVoices(8);
        const int id = eng.addInstrument(std::move(inst));
        for (int i = 0; i < 32; ++i) {
            cs::NoteEvent ev;
            ev.timeFrames   = i;
            ev.freqHz       = i;                     // the voice's tag
            ev.instrumentId = id;
            eng.schedule(ev);
        }
        std::vector<float> out(64);
        eng.renderOffline(out.data(), 64);
        QCOMPARE(eng.activeVoices(id), size_t{8});

        std::vector<int> oldest(24);
        for (int i = 0; i < 24; ++i) oldest[i] = i;
        QCOMPARE(dropped, oldest);
        dropped.clear();
    }
    // The engine's teardown drops the 8 that were still ringing.
    QCOMPARE(dropped.size(), size_t{8});
    for (int tag : dropped) QVERIFY(tag >= 24);
}

void SoundVoicesTest::noCapKeepsEveryVoice()
{
    std::vector<int> dropped;
    cs::Engine eng(kRate);
    const int id = eng.addInstrument(std::make_unique<TaggedInstrument>(dropped));
    for (int i = 0; i < 32; ++i) {
        cs::NoteEvent ev;
        ev.timeFrames   = i;
        ev.instrumentId = id;
        eng.schedule(ev);
    }
    std::vector<float> out(64);
    eng.renderOffline(out.data(), 64);
    QCOMPARE(eng.activeVoices(id), size_t{32});
    QVERIFY(dropped.empty());
}

void SoundVoicesTest::thirtyTwoNotesAtEightVoices_data()
{
    QTest::addColumn<QByteArray>("qml");
    QTest::newRow("SynthInstrument")
        << QByteArray("SynthInstrument { maxVoices: 8; waveform: \"sine\"; sustain: 1.0 }");
    QTest::newRow("SampleInstrument")
        << QByteArray("SampleInstrument { maxVoices: 8; looping: true; source: \"%1\" }");
}

// The criterion of #427: an instrument with maxVoices: 8 in QML fires
// 32 long notes, and 8 voices are left sounding.
void SoundVoicesTest::thirtyTwoNotesAtEightVoices()
{
    QFETCH(QByteArray, qml);
    qml.replace("%1", QUrl::fromLocalFile(wavPath_).toString().toUtf8());
    std::unique_ptr<QObject> o(createFromQml(qml));
    QVERIFY(o);
    QCOMPARE(o->property("maxVoices").toInt(), 8);

    for (int i = 0; i < 32; ++i) {
        bool ok = false;
        QMetaObject::invokeMethod(o.get(), "triggerNote", Q_RETURN_ARG(bool, ok),
                                  Q_ARG(int, 48 + i), Q_ARG(qreal, 0.1), Q_ARG(qreal, 1.0));
        QVERIFY(ok);
        renderShared(64);                            // each note starts in a pass of its own
    }
    QCOMPARE(o->property("activeVoices").toInt(), 8);
    QCOMPARE(sharedEngine().activeVoices(), size_t{8});

    // The 8 survivors still sound.
    QVERIFY(peak(renderShared(2048)) > 0.05);
    QCOMPARE(o->property("activeVoices").toInt(), 8);
}

QTEST_MAIN(SoundVoicesTest)
#include "tst_sound_voices.moc"
