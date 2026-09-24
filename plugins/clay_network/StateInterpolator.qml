// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype StateInterpolator
    \inqmlmodule Clayground.Network
    \brief Snapshot-buffer interpolation for remote entity state.

    Feed received state updates in via push() and read smoothly interpolated
    values from \l value each frame. The interpolator renders the remote
    entity a small, constant delay in the past (\l delayMs) so it always has
    two snapshots to blend between - the standard technique for hiding
    network jitter without the rubber-banding that naive per-update
    animations produce.

    Pass the sender's timestamp (the third argument of
    \l Network::stateReceived) to push(): snapshots are then placed on the
    sender's timeline, so a burst of updates that arrives late after a
    stall still plays back at the speed the sender moved instead of being
    compressed into the few milliseconds of its arrival. Without it,
    arrival time is used.

    Do NOT smooth remote entities with \c Behavior animations on physics
    world-unit properties - retargeting fights the property sync and the
    entity stalls short of its target.

    Example usage:
    \qml
    import Clayground.Network

    Network {
        onStateReceived: (from, data, sentAt) => remotePlayers[from]?.sync.push(data, sentAt)
    }

    // In the remote avatar component:
    StateInterpolator {
        id: sync
        angleKeys: ["a"]
        onUpdated: { parent.xWu = value.x; parent.yWu = value.y; }
    }
    \endqml

    \sa Network, NetworkMonitor
*/
import QtQuick

Item {
    id: root
    visible: false

    /*!
        \qmlproperty int StateInterpolator::delayMs
        \brief Interpolation delay in milliseconds (default 120).

        Should be at least one update interval larger than the sender's
        state period (e.g. 100-150 ms for 20 Hz updates). Larger values
        tolerate more jitter at the cost of visible delay. Ignored while
        \l autoDelay is on.
    */
    property int delayMs: 120

    /*!
        \qmlproperty bool StateInterpolator::autoDelay
        \brief Derive the delay from the observed stream instead of
               \l delayMs (default false).

        The delay becomes twice the sender's update period plus the 95th
        percentile of how late updates arrived in the last three seconds
        (relative to the fastest one seen), clamped to \l minDelayMs ..
        \l maxDelayMs. It moves towards that target by at most 1 ms per
        frame, never in a jump. A LAN stream ends up with a small delay, an
        internet stream with whatever its jitter needs.
    */
    property bool autoDelay: false

    /*!
        \qmlproperty int StateInterpolator::minDelayMs
        \brief Lower bound for \l autoDelay (default 30).
    */
    property int minDelayMs: 30

    /*!
        \qmlproperty int StateInterpolator::maxDelayMs
        \brief Upper bound for \l autoDelay (default 400).
    */
    property int maxDelayMs: 400

    /*!
        \qmlproperty real StateInterpolator::effectiveDelayMs
        \brief The delay currently rendered with: \l delayMs, or the
               adapted value while \l autoDelay is on.
    */
    readonly property real effectiveDelayMs: root.autoDelay ? internal.delay : root.delayMs

    /*!
        \qmlproperty real StateInterpolator::clockOffsetMs
        \brief Estimated offset between the sender's clock and ours
               (arrival minus send time of the fastest update seen), or
               NaN while no sender timestamps have been pushed.
    */
    readonly property real clockOffsetMs: internal.offset

    /*!
        \qmlproperty int StateInterpolator::maxExtrapolationMs
        \brief How far past the newest snapshot to extrapolate (default 200).

        When updates stall longer than this, the entity freezes at the last
        extrapolated position instead of flying off.
    */
    property int maxExtrapolationMs: 200

    /*!
        \qmlproperty list StateInterpolator::angleKeys
        \brief State keys holding angles in degrees; interpolated via the
               shortest arc so 350 -> 10 does not spin the long way around.
    */
    property var angleKeys: []

    /*!
        \qmlproperty var StateInterpolator::value
        \brief The current interpolated state (same keys as pushed states).
    */
    readonly property alias value: internal.current

    /*!
        \qmlproperty bool StateInterpolator::active
        \brief True once at least one state has been pushed.
    */
    readonly property bool active: internal.count > 0

    /*!
        \qmlsignal StateInterpolator::updated()
        \brief Emitted every frame with a fresh \l value while active.
    */
    signal updated()

    onAutoDelayChanged: {
        if (autoDelay) {
            internal.target = internal.delayTarget();
            internal.delay = internal.target;
        }
    }

    /*!
        \qmlmethod void StateInterpolator::push(var state, real sentAt)
        \brief Feed a received state update (a plain object of numbers;
               non-numeric entries are passed through unmodified).

        \a sentAt is the sender's timestamp from \l Network::stateReceived;
        leave it out (or pass a value below zero) to place the snapshot at
        its arrival time.
    */
    function push(state, sentAt) {
        let now = Date.now();
        let hasSent = typeof sentAt === "number" && sentAt > 0;
        let t = now;
        let lateness = 0;
        if (hasSent) {
            // Clock offset = the smallest (arrival - sent) seen in the
            // last few seconds: the update that travelled fastest defines
            // the sender's timeline on our clock, every other one arrived
            // that much later than it was sent.
            let offs = internal.offsets;
            offs.push({t: now, o: now - sentAt});
            let cutoff = now - 3000;
            while (offs.length > 1 && offs[0].t < cutoff) offs.shift();
            let minOff = offs[0].o;
            for (let i = 1; i < offs.length; ++i) if (offs[i].o < minOff) minOff = offs[i].o;
            if (minOff !== internal.offset) {
                internal.offset = minOff;
                // Earlier snapshots were stamped with the old estimate
                let buf = internal.buffer;
                for (let i = 0; i < buf.length; ++i)
                    if (buf[i].sa !== undefined) buf[i].t = buf[i].sa + minOff;
            }
            t = sentAt + minOff;
            lateness = (now - sentAt) - minOff;
            if (internal.lastSent > 0) internal.notePeriod(sentAt - internal.lastSent);
            internal.lastSent = sentAt;
        } else {
            if (internal.lastArrival > 0) {
                let dt = now - internal.lastArrival;
                internal.notePeriod(dt);
                lateness = Math.max(0, dt - internal.period);
            }
        }
        internal.lastArrival = now;
        internal.noteLateness(now, lateness);

        // Insert keeping the buffer ordered by t (re-stamping or a very
        // late straggler can put a snapshot before the newest one)
        let buf = internal.buffer;
        let entry = {t: t, s: state, sa: hasSent ? sentAt : undefined};
        let pos = buf.length;
        while (pos > 0 && buf[pos - 1].t > t) --pos;
        buf.splice(pos, 0, entry);
        internal.count = buf.length;
        // Keep a little history beyond the render delay, drop the rest
        let keep = now - (root.effectiveDelayMs + 1000);
        while (buf.length > 2 && buf[0].t < keep)
            buf.shift();

        if (root.autoDelay) {
            let target = internal.delayTarget();
            if (!(internal.delay > 0)) internal.delay = target;   // first push: no ramp
            internal.target = target;
        }
        frame.running = true;
    }

    /*!
        \qmlmethod void StateInterpolator::reset()
        \brief Drop all buffered snapshots (e.g. on teleport/level change),
               so the entity snaps instead of interpolating across worlds.
               The clock offset and delay estimates are kept.
    */
    function reset() {
        internal.buffer = [];
        internal.count = 0;
        frame.running = false;
    }

    QtObject {
        id: internal
        property var buffer: []
        property int count: 0
        property var current: ({})

        // Sender-clock placement
        property var offsets: []
        property real offset: NaN
        property real lastSent: 0
        property real lastArrival: 0

        // Auto delay: sender period and lateness distribution
        property real period: 0
        property var lateness: []
        property real delay: 0
        property real target: 0

        function notePeriod(dt) {
            if (dt <= 0 || dt > 2000) return;
            period = period > 0 ? period * 0.9 + dt * 0.1 : dt;
        }
        function noteLateness(now, l) {
            lateness.push({t: now, l: l});
            let cutoff = now - 3000;
            while (lateness.length > 1 && lateness[0].t < cutoff) lateness.shift();
        }
        function delayTarget() {
            let sorted = lateness.map(e => e.l).sort((a, b) => a - b);
            let p95 = sorted.length ? sorted[Math.floor((sorted.length - 1) * 0.95)] : 0;
            let per = period > 0 ? period : 50;
            let t = 2 * per + p95 + 4;
            return Math.max(root.minDelayMs, Math.min(root.maxDelayMs, t));
        }

        function lerp(a, b, f, isAngle) {
            if (isAngle) {
                let d = (b - a) % 360;
                if (d > 180) d -= 360;
                if (d < -180) d += 360;
                return a + d * f;
            }
            return a + (b - a) * f;
        }

        function sample(renderT) {
            let buf = buffer;
            if (buf.length === 0) return null;
            if (buf.length === 1 || renderT <= buf[0].t) return buf[0].s;

            // Interpolate between the two snapshots bracketing renderT
            for (let i = 1; i < buf.length; ++i) {
                if (buf[i].t >= renderT) {
                    let a = buf[i-1], b = buf[i];
                    let f = (renderT - a.t) / Math.max(1, b.t - a.t);
                    return blend(a.s, b.s, f);
                }
            }

            // Past the newest snapshot: extrapolate a bounded amount from
            // the last two, then hold position
            let last = buf[buf.length - 1];
            if (buf.length < 2) return last.s;
            let prev = buf[buf.length - 2];
            let over = Math.min(renderT - last.t, root.maxExtrapolationMs);
            let f = 1 + over / Math.max(1, last.t - prev.t);
            return blend(prev.s, last.s, f);
        }

        function blend(sa, sb, f) {
            let out = {};
            for (let k in sb) {
                let va = sa[k], vb = sb[k];
                if (typeof va === "number" && typeof vb === "number")
                    out[k] = lerp(va, vb, f, root.angleKeys.indexOf(k) >= 0);
                else
                    out[k] = vb;
            }
            return out;
        }
    }

    FrameAnimation {
        id: frame
        running: false
        onTriggered: {
            if (root.autoDelay && internal.target > 0) {
                // Glide towards the target: at most 1 ms per frame, which
                // moves a 7.5 Wu/s entity by 0.008 Wu - never a visible jump
                let d = internal.target - internal.delay;
                internal.delay += Math.max(-1, Math.min(1, d));
            }
            let s = internal.sample(Date.now() - root.effectiveDelayMs);
            if (s) {
                internal.current = s;
                root.updated();
            }
        }
    }
}
