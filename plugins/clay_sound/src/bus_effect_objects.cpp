// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "bus_effect_objects.h"

#include "audio_output.h"

namespace cs = clay::sound;

// A setter emits only when the engine's value moved, after clamping.
template <typename Get, typename Set>
static bool assign(Get get, Set set, float v)
{
    const float before = get();
    set(v);
    return get() != before;
}

EchoEffect::EchoEffect(cs::Bus bus, QObject *parent) : QObject(parent), bus_(bus) {}

cs::Echo &EchoEffect::echo() const { return cs::AudioOutput::instance().engine().echo(bus_); }

bool EchoEffect::enabled() const { return echo().enabled(); }

void EchoEffect::setEnabled(bool on)
{
    if (echo().enabled() == on) return;
    echo().setEnabled(on);
    emit enabledChanged();
}

qreal EchoEffect::delay() const { return echo().delayMs(); }

void EchoEffect::setDelay(qreal ms)
{
    auto &e = echo();
    if (assign([&] { return e.delayMs(); }, [&](float v) { e.setDelayMs(v); }, float(ms)))
        emit delayChanged();
}

qreal EchoEffect::feedback() const { return echo().feedback(); }

void EchoEffect::setFeedback(qreal fb)
{
    auto &e = echo();
    if (assign([&] { return e.feedback(); }, [&](float v) { e.setFeedback(v); }, float(fb)))
        emit feedbackChanged();
}

qreal EchoEffect::volume() const { return echo().volume(); }

void EchoEffect::setVolume(qreal v)
{
    auto &e = echo();
    if (assign([&] { return e.volume(); }, [&](float x) { e.setVolume(x); }, float(v)))
        emit volumeChanged();
}

QList<qreal> EchoEffect::fir() const
{
    QList<qreal> taps;
    for (int k = 0; k < cs::Echo::kTaps; ++k) taps << echo().firTap(k);
    return taps;
}

void EchoEffect::setFir(const QList<qreal> &taps)
{
    if (taps.size() > cs::Echo::kTaps) {
        qWarning("EchoEffect: fir takes at most %d taps, got %d; ignored",
                 cs::Echo::kTaps, int(taps.size()));
        return;
    }
    const QList<qreal> before = fir();
    for (int k = 0; k < cs::Echo::kTaps; ++k)
        echo().setFirTap(k, k < taps.size() ? float(taps[k]) : 0.0f);
    if (fir() != before) emit firChanged();
}

ReverbEffect::ReverbEffect(cs::Bus bus, QObject *parent) : QObject(parent), bus_(bus) {}

cs::Reverb &ReverbEffect::reverb() const { return cs::AudioOutput::instance().engine().reverb(bus_); }

bool ReverbEffect::enabled() const { return reverb().enabled(); }

void ReverbEffect::setEnabled(bool on)
{
    if (reverb().enabled() == on) return;
    reverb().setEnabled(on);
    emit enabledChanged();
}

qreal ReverbEffect::roomSize() const { return reverb().roomSize(); }

void ReverbEffect::setRoomSize(qreal r)
{
    auto &e = reverb();
    if (assign([&] { return e.roomSize(); }, [&](float v) { e.setRoomSize(v); }, float(r)))
        emit roomSizeChanged();
}

qreal ReverbEffect::damping() const { return reverb().damping(); }

void ReverbEffect::setDamping(qreal d)
{
    auto &e = reverb();
    if (assign([&] { return e.damping(); }, [&](float v) { e.setDamping(v); }, float(d)))
        emit dampingChanged();
}

qreal ReverbEffect::volume() const { return reverb().volume(); }

void ReverbEffect::setVolume(qreal v)
{
    auto &e = reverb();
    if (assign([&] { return e.volume(); }, [&](float x) { e.setVolume(x); }, float(v)))
        emit volumeChanged();
}
