// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QElapsedTimer>
#include <QList>
#include <QObject>
#include <QTimer>
#include <QVariantMap>
#include <functional>

namespace clay::network {

// Simulates a bad link on one node: everything the node sends and receives
// over its data channels passes through here and is delayed, lost, rate
// limited or held back as Network.linkConditions says (#301). The native
// backend uses this class; the browser backend has the same rules in
// link_conditioner.js, and the two unit suites check both against them.
//
// Rules, per direction (outgoing and incoming are separate links):
//   - loss: that share of the state channel's packets is dropped. The
//     reliable channel loses nothing - it stands for a transport that
//     retransmits, so its packets arrive late instead.
//   - latencyMs + a random 0..jitterMs: added to every packet. State packets
//     may overtake each other this way; reliable ones keep their order.
//   - bandwidthKbps: packets leave one after another at that rate, both
//     channels in one queue, so a full link delays everything behind it.
//   - blackout: while on, state packets are dropped and reliable ones are
//     held; when it ends, the held ones go out in order.
// Packets already under way when the conditions change keep their schedule.
// With no conditions set and nothing under way, a packet is delivered
// immediately, inside offer() - the conditioner then changes nothing.
class LinkConditioner : public QObject
{
    Q_OBJECT

public:
    enum Direction { Outgoing = 0, Incoming = 1 };

    explicit LinkConditioner(QObject *parent = nullptr);

    // Keys: loss (0..1), latencyMs, jitterMs, bandwidthKbps (0 = no cap),
    // blackout, dropSignaling. Unknown keys are ignored, missing ones are 0
    // or false; out-of-range values are clamped.
    void setConditions(const QVariantMap &conditions);
    QVariantMap conditions() const;

    bool active() const;
    bool dropSignaling() const { return dropSignaling_; }

    // Hands one packet of `bytes` to the link. `deliver` runs once it gets
    // through, and never if it is lost. `stateChannel` marks the lossy one.
    void offer(Direction dir, bool stateChannel, qsizetype bytes,
               std::function<void()> deliver);

    // Forgets every packet under way or held, e.g. when leaving a network
    void clear();

    // Delivers everything due at nowMs. The internal timer calls it with
    // the real clock; tests call it with their own.
    void pump(qint64 nowMs);

    // Test hooks: a clock in ms and a random source in [0, 1). With a
    // clock set, nothing is scheduled on a timer - the test pumps.
    void setClock(std::function<qint64()> clock);
    void setRandom(std::function<double()> random);

    // Packets this conditioner dropped (loss and blackout) and packets
    // held back by a blackout, since construction
    qint64 droppedCount() const { return dropped_; }
    qint64 heldCount() const { return heldTotal_; }

private:
    struct Pending {
        qint64 due;
        quint64 order;
        std::function<void()> deliver;
    };
    struct Held {
        bool stateChannel;
        qsizetype bytes;
        std::function<void()> deliver;
    };

    qint64 now() const;
    double random() const;
    void schedule(Direction dir, bool stateChannel, qsizetype bytes,
                  std::function<void()> deliver);
    void releaseHeld();
    void armTimer();

    double loss_ = 0.0;
    int latencyMs_ = 0;
    int jitterMs_ = 0;
    int bandwidthKbps_ = 0;
    bool blackout_ = false;
    bool dropSignaling_ = false;

    QList<Pending> pending_;          // ordered by (due, order)
    QList<Held> held_[2];             // reliable packets held by a blackout
    qint64 lastReliableDue_[2] = {0, 0};
    double linkFreeAt_[2] = {0, 0};   // when the bandwidth cap frees the link
    quint64 nextOrder_ = 0;
    qint64 dropped_ = 0;
    qint64 heldTotal_ = 0;

    QElapsedTimer elapsed_;
    QTimer timer_;
    std::function<qint64()> clock_;
    std::function<double()> random_;
};

} // namespace clay::network
