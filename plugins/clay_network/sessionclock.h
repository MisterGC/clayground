// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <algorithm>
#include <cmath>
#include <deque>
#include <limits>
#include <vector>
#include <QHash>
#include <QString>

// The session clock (#304), shared by the native and the WASM backend.
//
// Session time is the host's monotonic clock, in ms since it created the
// network. A wall clock jumps when NTP adjusts it; a monotonic one does
// not, and every node reads the host's through its own:
//
//   sessionTime = localMonotonicMs + offset
//
// A joiner learns the offset from the pings it already sends the host
// every 2 s (#299). The ping carries the joiner's local time, the host's
// pong echoes it and adds its session time:
//
//   {"t":"p","ts":<sender local ms>}
//   {"t":"P","ts":<echoed>,"st":<host session ms>}
//
// One round trip is one sample: the host read "st" somewhere between
// sending and receiving, so offset = st - (sent + received) / 2, off by
// half the difference of the two legs. The legs of a fast round trip were
// both close to their minimum, so the estimate is the mean of the faster
// half of the last kWindow samples - robust to a slow or held-back leg,
// which only makes a round trip slow. Samples older than kMaxSampleAgeMs
// go, so two clocks that drift apart are followed. Right after the welcome
// a joiner sends kBurstPings pings kBurstIntervalMs apart to fill the
// window.
//
// Until kSyncedAfter samples are in, the offset steps to each new
// estimate; after that it slews towards it at kSlewRate, so session time
// never steps back once it is synced.
namespace clay::network::sessionclock {

// Samples kept, and how many of the fastest are averaged at most
constexpr int kWindow = 64;
constexpr int kBest = 32;
// A sample older than this goes, unless fewer than kMinKept are left
constexpr int kMaxSampleAgeMs = 60000;
constexpr int kMinKept = 16;
// Synced once this many samples are in
constexpr int kSyncedAfter = 32;
// The pings that fill the window after the welcome, and their spacing:
// wider than a typical jitter, so a ping is not held back behind the one
// before it on the ordered channel
constexpr int kBurstPings = kWindow;
constexpr int kBurstIntervalMs = 50;
// After sync, an adjustment moves the clock by at most this many ms per ms
constexpr double kSlewRate = 0.05;

class Clock
{
public:
    // The host: the session starts at localNow
    void start(double localNow)
    {
        reset();
        base_ = target_ = -localNow;
        baseAt_ = localNow;
        valid_ = true;
        synced_ = true;
        reference_ = true;
    }

    // A joiner's first guess from the host's welcome, off by the one-way
    // latency of the welcome; the burst's samples replace it
    void seed(double hostTime, double localNow)
    {
        if (reference_ || samples_.size() > 0)
            return;
        base_ = target_ = hostTime - localNow;
        baseAt_ = localNow;
        valid_ = true;
    }

    // One ping round trip to the host. Returns true when this sample made
    // the clock synced.
    bool sample(double sentLocal, double hostTime, double receivedLocal)
    {
        if (reference_ || hostTime < 0)
            return false;
        const double rtt = receivedLocal - sentLocal;
        if (!(rtt >= 0) || !std::isfinite(hostTime))
            return false;
        samples_.push_back({receivedLocal, rtt, hostTime - (sentLocal + receivedLocal) / 2.0});
        while (int(samples_.size()) > kWindow
               || (int(samples_.size()) > kMinKept
                   && samples_.front().at < receivedLocal - kMaxSampleAgeMs))
            samples_.pop_front();

        std::vector<Sample> sorted(samples_.begin(), samples_.end());
        std::sort(sorted.begin(), sorted.end(),
                  [](const Sample &a, const Sample &b) { return a.rtt < b.rtt; });
        const int n = std::clamp(int(sorted.size()) / 2, 1, kBest);
        double sum = 0;
        for (int i = 0; i < n; ++i)
            sum += sorted[i].offset;
        const double estimate = sum / n;
        bestRtt_ = sorted.front().rtt;

        if (synced_) {
            base_ = offsetAt(receivedLocal);
            baseAt_ = receivedLocal;
            target_ = estimate;
        } else {
            base_ = target_ = estimate;
            baseAt_ = receivedLocal;
        }
        valid_ = true;
        if (!synced_ && int(samples_.size()) >= kSyncedAfter) {
            synced_ = true;
            return true;
        }
        return false;
    }

    // Session time at localNow, -1 while there is none
    double time(double localNow) const
    {
        return valid_ ? localNow + offsetAt(localNow) : -1.0;
    }

    bool valid() const { return valid_; }
    bool synced() const { return synced_; }
    int sampleCount() const { return int(samples_.size()); }
    double bestRtt() const { return bestRtt_; }
    double offset(double localNow) const { return offsetAt(localNow); }

    void reset()
    {
        samples_.clear();
        base_ = target_ = baseAt_ = 0;
        bestRtt_ = -1;
        valid_ = synced_ = reference_ = false;
    }

private:
    struct Sample { double at; double rtt; double offset; };

    double offsetAt(double localNow) const
    {
        const double room = kSlewRate * std::max(0.0, localNow - baseAt_);
        return base_ + std::clamp(target_ - base_, -room, room);
    }

    std::deque<Sample> samples_;
    double base_ = 0;     // offset applied at baseAt_
    double target_ = 0;   // where the offset slews to
    double baseAt_ = 0;
    double bestRtt_ = -1;
    bool valid_ = false;
    bool synced_ = false;
    bool reference_ = false;
};

// How long a sender's states take to arrive, estimated once per sender
// (#304) rather than once per StateInterpolator. Both ends of a transit
// are in session time, so it is the one-way delay; the fastest of the last
// kTransitWindowMs is the offset at which a sender's timeline is placed on
// this node's. Arrivals are kept in local time minus sentAt and the
// current clock offset is added when asked, so a clock that is still being
// synced does not leave a stale minimum behind.
//
// Every StateInterpolator on a sender asks for its transit with each state
// it is pushed, so a window is kept as a sliding minimum (#305): an arrival
// is dropped as soon as a newer one is at least as fast - it can never be
// the minimum again - which leaves the window ascending, its fastest
// arrival first. Noting is amortised O(1), asking is O(1).
constexpr int kTransitWindowMs = 3000;

class TransitTracker
{
public:
    void note(const QString &nodeId, double sentAt, double localNow)
    {
        if (sentAt < 0)
            return;
        auto &w = windows_[nodeId];
        const double raw = localNow - sentAt;
        while (!w.empty() && w.back().raw >= raw)
            w.pop_back();
        w.push_back({localNow, raw});
        while (w.size() > 1 && w.front().at < localNow - kTransitWindowMs)
            w.pop_front();
    }

    // The fastest transit from nodeId in session ms, NaN if none was seen
    double transit(const QString &nodeId, double clockOffset) const
    {
        const auto it = windows_.constFind(nodeId);
        if (it == windows_.constEnd() || it->empty())
            return std::numeric_limits<double>::quiet_NaN();
        return it->front().raw + clockOffset;
    }

    void forget(const QString &nodeId) { windows_.remove(nodeId); }
    void clear() { windows_.clear(); }

private:
    struct Arrival { double at; double raw; };
    QHash<QString, std::deque<Arrival>> windows_;
};

} // namespace clay::network::sessionclock
