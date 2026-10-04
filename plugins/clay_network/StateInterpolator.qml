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

    Give it the \l network and the \l nodeId whose state it shows, and it
    runs on the network's \l {Network::sessionTime}{session clock} and
    places snapshots with the network's \l {Network::transitMs}{transit
    estimate} for that node - estimated once per sender, however many
    interpolators show that sender's objects. Without them every
    interpolator estimates the offset from the states pushed into it, on
    the local wall clock.

    An interpolator costs per frame only while it has something to blend:
    with a single snapshot, or once the newest one is held after
    \l maxExtrapolationMs, its frame loop stops until the next push(), and
    blending writes into two value objects in turn instead of making a new
    one every frame - so a replicated world can run one per object.

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
        network: theNetwork      // optional: the shared clock and offset
        nodeId: avatarOwner
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
        \qmlproperty Network StateInterpolator::network
        \brief The network the pushed states come from (default null).

        Together with \l nodeId it makes the interpolator run on the
        network's session clock and take the clock offset from
        \l Network::transitMs instead of estimating it itself.
    */
    property var network: null

    /*!
        \qmlproperty string StateInterpolator::nodeId
        \brief The node whose state is pushed, the \c fromId of
               \l Network::stateReceived. Used with \l network.
    */
    property string nodeId: ""

    /*!
        \qmlproperty bool StateInterpolator::autoDelay
        \brief Derive the delay from the observed stream instead of
               \l delayMs (default false).

        The delay becomes twice the sender's update period plus the 95th
        percentile of how late updates arrived in the last three seconds
        (relative to the fastest one seen), clamped to \l minDelayMs ..
        \l maxDelayMs. The period is the median of the last nine intervals
        between updates, so the pause of an object at rest - which sends
        nothing - is taken for neither a period nor lateness, and the delay
        stays at its streaming value when the object moves again. A state
        with the key \c{$rest} set is a copy of the one before, sent because
        the object rests: the interval up to it and the one after it count
        as neither period nor lateness, and the key is dropped from the
        state. A ReplicatedObject marks its stop and settle that way, so an
        object that stops often, or is hit while it stands, keeps its
        streaming delay; a sender of its own may do the same. The delay
        moves towards that target by at most 1 ms per frame, never in a
        jump. A LAN stream ends up with a small delay, an internet stream
        with whatever its jitter needs.
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
               NaN while no sender timestamps have been pushed. With
               \l network and \l nodeId set, the network's
               \l Network::transitMs for that node.
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

        A blended value is one of two objects the interpolator writes into
        in turn, so it is overwritten two frames later: copy what you keep
        beyond the frame.
    */
    readonly property alias value: internal.current

    /*!
        \qmlproperty bool StateInterpolator::active
        \brief True once at least one state has been pushed.
    */
    readonly property bool active: internal.count > 0

    /*!
        \qmlsignal StateInterpolator::updated()
        \brief Emitted every frame with a fresh \l value while there is
               something to blend.

        Once the value comes to rest - a single snapshot, or the newest one
        held after \l maxExtrapolationMs - it is emitted once more and then
        not again until the next push().
    */
    signal updated()

    onAngleKeysChanged: internal.refreshAngles()

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
        let now = internal.now();
        let hasSent = typeof sentAt === "number" && sentAt >= 0;
        let t = now;
        let lateness = 0;
        let shared = hasSent && internal.shared() ? root.network.transitMs(root.nodeId) : NaN;
        // A copy of the state before, sent because the object rests: the
        // interval up to it and the one after it are no update period
        let copy = state[internal.restKey] !== undefined && state[internal.restKey] !== false;
        if (copy) state = internal.withoutRestKey(state);
        let streamed = !copy && !internal.lastCopy;
        internal.lastCopy = copy;
        if (!isNaN(shared)) {
            // The network estimates the offset once per sender (#304);
            // both clocks are its session clock
            if (shared !== internal.offset) {
                internal.offset = shared;
                let buf = internal.buffer;
                for (let i = 0; i < buf.length; ++i)
                    if (buf[i].sa !== undefined) buf[i].t = buf[i].sa + shared;
            }
            t = sentAt + shared;
            lateness = (now - sentAt) - shared;
            if (internal.lastSent > 0 && streamed) internal.notePeriod(sentAt - internal.lastSent);
            internal.lastSent = sentAt;
        } else if (hasSent) {
            // Clock offset = the smallest (arrival - sent) seen in the
            // last few seconds: the update that travelled fastest defines
            // the sender's timeline on our clock, every other one arrived
            // that much later than it was sent. The window keeps only the
            // arrivals that can still become its minimum, ascending, so
            // the minimum is its first entry - no rescan per push (#305).
            let offs = internal.offsets = internal.onClock(internal.offsets, now);
            let o = now - sentAt;
            while (offs.length > 0 && offs[offs.length - 1].o >= o) offs.pop();
            offs.push({t: now, o: o});
            let cutoff = now - internal.windowMs;
            while (offs.length > 1 && offs[0].t < cutoff) offs.shift();
            let minOff = offs[0].o;
            if (minOff !== internal.offset) {
                internal.offset = minOff;
                // Earlier snapshots were stamped with the old estimate
                let buf = internal.buffer;
                for (let i = 0; i < buf.length; ++i)
                    if (buf[i].sa !== undefined) buf[i].t = buf[i].sa + minOff;
            }
            t = sentAt + minOff;
            lateness = (now - sentAt) - minOff;
            if (internal.lastSent > 0 && streamed) internal.notePeriod(sentAt - internal.lastSent);
            internal.lastSent = sentAt;
        } else {
            // A pause is no late update: the first state after an
            // object's rest would hold the delay at its maximum (#366)
            if (internal.lastArrival > 0 && streamed) {
                let dt = now - internal.lastArrival;
                internal.notePeriod(dt);
                if (dt <= internal.pauseMs)
                    lateness = Math.max(0, dt - internal.period);
            }
        }
        internal.lastArrival = now;
        internal.noteLateness(now, lateness);

        // Insert keeping the buffer ordered by t (re-stamping or a very
        // late straggler can put a snapshot before the newest one)
        let buf = internal.buffer;
        let entry = {t: t, s: state, sa: hasSent ? sentAt : undefined,
                     sh: internal.shapeOf(state)};
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

        // The keys of the states pushed and which of them are angles,
        // shared by every snapshot of that shape, so blending walks a
        // list instead of enumerating keys and searching angleKeys per
        // frame (#305)
        property var shape: null
        function shapeOf(state) {
            let k = Object.keys(state);
            let sh = shape;
            if (sh !== null && sh.k.length === k.length) {
                let same = true;
                for (let i = 0; i < k.length && same; ++i) same = sh.k[i] === k[i];
                if (same) return sh;
            }
            sh = {k: k, ang: k.map(key => root.angleKeys.indexOf(key) >= 0)};
            shape = sh;
            return sh;
        }
        function refreshAngles() {
            shape = null;
            for (let i = 0; i < buffer.length; ++i) {
                let sh = buffer[i].sh;
                for (let j = 0; j < sh.k.length; ++j)
                    sh.ang[j] = root.angleKeys.indexOf(sh.k[j]) >= 0;
            }
        }

        // The two value objects blending writes into in turn: value
        // changes identity every frame, so bindings on it re-evaluate,
        // without an object made per frame (#305). A buffer is made anew
        // only when the shape it was filled with changes.
        property var out0: null
        property var out1: null
        property var outShape0: null
        property var outShape1: null
        property bool outTurn: false

        // On the network's session clock with its per-sender offset (#304)
        function shared() {
            return root.network !== null && root.network !== undefined
                && root.nodeId !== "" && root.network.sessionTime >= 0;
        }
        function now() {
            return root.network ? root.network.sessionTime : Date.now();
        }

        // Sender-clock placement
        property var offsets: []
        property real offset: NaN
        property real lastSent: 0
        property real lastArrival: 0

        // Auto delay: sender period and lateness distribution
        property real period: 0
        property var intervals: []
        property var lateness: []
        property real delay: 0
        property real target: 0

        // The sender marks the copies of its last state it sends because
        // the object rests - ReplicatedObject's stop, 1.5 periods after the
        // last motion, and its settle, 200 ms after it - with this key. The
        // gaps up to those copies, and the one from them to the next state
        // - the next motion, a hit while it stands - are no periods. An
        // enemy that stops and is hit often has more of them than moving
        // intervals between, and their median, 176 ms between the stop and
        // the settle, rendered it 2 x 176 + 4 ms late (#374). Told by the
        // sender, not guessed from states that repeat: a sender may repeat
        // a state at its rate, or send each one twice (#374).
        readonly property string restKey: "$rest"
        property bool lastCopy: false
        function withoutRestKey(state) {
            let out = {};
            for (let k in state)
                if (k !== restKey) out[k] = state[k];
            return out;
        }

        // The period is the median of the last nine of those intervals,
        // not their average: a gap around a rest that passes for one - an
        // object at rest whose stop state got lost, say - would count as a
        // period several times as long and render it twice as late long
        // after it moves again (#366). A median leaves up to four of them
        // out and still follows a sender that changes its rate within five
        // states.
        readonly property real pauseMs: 2000
        readonly property int periodSamples: 9
        function notePeriod(dt) {
            if (dt <= 0 || dt > pauseMs) return;
            let iv = intervals;
            iv.push(dt);
            if (iv.length > periodSamples) iv.shift();
            let sorted = iv.slice().sort((a, b) => a - b);
            let mid = sorted.length >> 1;
            period = sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
        }
        // The offset and lateness windows hold the last 3 s on the clock
        // they were stamped with. When that clock changes under them - the
        // interpolator gets or loses its network, the session starts
        // again - their entries lie ahead of now and never fall behind the
        // cutoff: the window stops pruning, grows without end, and its
        // percentile keeps answering for the old stream (#363). A step back
        // shorter than the window ages out on its own; a longer one starts
        // the window again.
        readonly property real windowMs: 3000
        function onClock(win, now) {
            return win.length > 0 && win[win.length - 1].t > now + windowMs ? [] : win;
        }
        function noteLateness(now, l) {
            lateness = onClock(lateness, now);
            lateness.push({t: now, l: l});
            let cutoff = now - windowMs;
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
                    return blend(a, b, f);
                }
            }

            // Past the newest snapshot: extrapolate a bounded amount from
            // the last two, then hold position
            let last = buf[buf.length - 1];
            if (buf.length < 2) return last.s;
            let prev = buf[buf.length - 2];
            let over = Math.min(renderT - last.t, root.maxExtrapolationMs);
            let f = 1 + over / Math.max(1, last.t - prev.t);
            return blend(prev, last, f);
        }

        // The value no longer moves: one snapshot, or the newest one held
        // after the extrapolation
        function settled(renderT) {
            let buf = buffer;
            if (buf.length < 2) return true;
            return renderT - buf[buf.length - 1].t >= root.maxExtrapolationMs;
        }

        // Blend the states of snapshots a and b into the next value
        // object, over b's keys
        function blend(a, b, f) {
            let sa = a.s, sb = b.s, sh = b.sh;
            outTurn = !outTurn;
            let out;
            if (outTurn) {
                if (outShape1 !== sh) { out1 = {}; outShape1 = sh; }
                out = out1;
            } else {
                if (outShape0 !== sh) { out0 = {}; outShape0 = sh; }
                out = out0;
            }
            let keys = sh.k, ang = sh.ang;
            for (let i = 0; i < keys.length; ++i) {
                let k = keys[i];
                let va = sa[k], vb = sb[k];
                if (typeof va === "number" && typeof vb === "number")
                    out[k] = lerp(va, vb, f, ang[i]);
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
            let now = internal.now();
            // Out of the network, there is no session clock to render on;
            // the next push starts the loop again
            if (now < 0) {
                running = false;
                return;
            }
            let renderT = now - root.effectiveDelayMs;
            let s = internal.sample(renderT);
            if (s && s !== internal.current) {
                internal.current = s;
                root.updated();
            }
            // Nothing left to blend - the value rests on the newest
            // snapshot - so no work per frame until the next push (#305)
            if (internal.settled(renderT)) running = false;
        }
    }
}
