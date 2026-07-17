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

    Do NOT smooth remote entities with \c Behavior animations on physics
    world-unit properties - retargeting fights the property sync and the
    entity stalls short of its target.

    Example usage:
    \qml
    import Clayground.Network

    Network {
        onStateReceived: (from, data) => remotePlayers[from]?.sync.push(data)
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
        tolerate more jitter at the cost of visible delay.
    */
    property int delayMs: 120

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

    /*!
        \qmlmethod void StateInterpolator::push(var state)
        \brief Feed a received state update (a plain object of numbers;
               non-numeric entries are passed through unmodified).
    */
    function push(state) {
        let now = Date.now();
        internal.buffer.push({t: now, s: state});
        internal.count = internal.buffer.length;
        // Keep a little history beyond the render delay, drop the rest
        let cutoff = now - (delayMs + 1000);
        while (internal.buffer.length > 2 && internal.buffer[0].t < cutoff)
            internal.buffer.shift();
        frame.running = true;
    }

    /*!
        \qmlmethod void StateInterpolator::reset()
        \brief Drop all buffered snapshots (e.g. on teleport/level change),
               so the entity snaps instead of interpolating across worlds.
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
            let s = internal.sample(Date.now() - root.delayMs);
            if (s) {
                internal.current = s;
                root.updated();
            }
        }
    }
}
