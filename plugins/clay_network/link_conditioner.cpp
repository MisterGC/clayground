// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "link_conditioner.h"
#include <QRandomGenerator>
#include <algorithm>
#include <cmath>

namespace clay::network {

LinkConditioner::LinkConditioner(QObject *parent)
    : QObject(parent)
{
    elapsed_.start();
    timer_.setSingleShot(true);
    timer_.setTimerType(Qt::PreciseTimer);
    connect(&timer_, &QTimer::timeout, this, [this]() { pump(now()); });
}

void LinkConditioner::setConditions(const QVariantMap &c)
{
    const bool wasBlackout = blackout_;
    loss_ = std::clamp(c.value("loss").toDouble(), 0.0, 1.0);
    latencyMs_ = std::max(0, c.value("latencyMs").toInt());
    jitterMs_ = std::max(0, c.value("jitterMs").toInt());
    bandwidthKbps_ = std::max(0, c.value("bandwidthKbps").toInt());
    blackout_ = c.value("blackout").toBool();
    dropSignaling_ = c.value("dropSignaling").toBool();
    if (wasBlackout && !blackout_)
        releaseHeld();
}

QVariantMap LinkConditioner::conditions() const
{
    return {
        {"loss", loss_},
        {"latencyMs", latencyMs_},
        {"jitterMs", jitterMs_},
        {"bandwidthKbps", bandwidthKbps_},
        {"blackout", blackout_},
        {"dropSignaling", dropSignaling_},
    };
}

bool LinkConditioner::active() const
{
    return loss_ > 0 || latencyMs_ > 0 || jitterMs_ > 0 || bandwidthKbps_ > 0 || blackout_;
}

void LinkConditioner::offer(Direction dir, bool stateChannel, qsizetype bytes,
                            std::function<void()> deliver)
{
    // Nothing to simulate and nothing under way that this one could overtake
    if (!active() && pending_.isEmpty()) {
        deliver();
        return;
    }
    if (stateChannel && (blackout_ || (loss_ > 0 && random() < loss_))) {
        ++dropped_;
        return;
    }
    if (!stateChannel && blackout_) {
        held_[dir].append({stateChannel, bytes, std::move(deliver)});
        ++heldTotal_;
        return;
    }
    schedule(dir, stateChannel, bytes, std::move(deliver));
}

void LinkConditioner::schedule(Direction dir, bool stateChannel, qsizetype bytes,
                               std::function<void()> deliver)
{
    const qint64 t = now();
    double departure = t;
    if (bandwidthKbps_ > 0) {
        // kbit/s is bit/ms: a packet occupies the link for bits / kbps ms
        linkFreeAt_[dir] = std::max(double(t), linkFreeAt_[dir])
                           + double(bytes) * 8.0 / bandwidthKbps_;
        departure = linkFreeAt_[dir];
    }
    qint64 due = qint64(std::ceil(departure)) + latencyMs_;
    if (jitterMs_ > 0)
        due += qint64(std::floor(random() * (jitterMs_ + 1)));
    if (!stateChannel) {
        due = std::max(due, lastReliableDue_[dir]);
        lastReliableDue_[dir] = due;
    }

    Pending p{due, nextOrder_++, std::move(deliver)};
    auto pos = std::upper_bound(pending_.begin(), pending_.end(), p,
                                [](const Pending &a, const Pending &b) {
                                    return a.due < b.due || (a.due == b.due && a.order < b.order);
                                });
    pending_.insert(pos, std::move(p));
    armTimer();
}

void LinkConditioner::releaseHeld()
{
    for (int dir = 0; dir < 2; ++dir) {
        QList<Held> held;
        held.swap(held_[dir]);
        for (Held &h : held)
            schedule(Direction(dir), h.stateChannel, h.bytes, std::move(h.deliver));
    }
}

void LinkConditioner::clear()
{
    pending_.clear();
    held_[Outgoing].clear();
    held_[Incoming].clear();
    lastReliableDue_[Outgoing] = lastReliableDue_[Incoming] = 0;
    linkFreeAt_[Outgoing] = linkFreeAt_[Incoming] = 0;
    timer_.stop();
}

void LinkConditioner::pump(qint64 nowMs)
{
    // A delivery may offer new packets (a ping answered with a pong), so
    // each one is taken off the list before it runs
    while (!pending_.isEmpty() && pending_.first().due <= nowMs) {
        Pending p = pending_.takeFirst();
        p.deliver();
    }
    armTimer();
}

void LinkConditioner::armTimer()
{
    if (clock_)
        return;
    if (pending_.isEmpty()) {
        timer_.stop();
        return;
    }
    timer_.start(int(std::max<qint64>(0, pending_.first().due - now())));
}

qint64 LinkConditioner::now() const
{
    return clock_ ? clock_() : elapsed_.elapsed();
}

double LinkConditioner::random() const
{
    return random_ ? random_() : QRandomGenerator::global()->generateDouble();
}

void LinkConditioner::setClock(std::function<qint64()> clock)
{
    clock_ = std::move(clock);
    timer_.stop();
}

void LinkConditioner::setRandom(std::function<double()> random)
{
    random_ = std::move(random);
}

} // namespace clay::network
