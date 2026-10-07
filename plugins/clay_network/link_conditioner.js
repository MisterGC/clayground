// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The browser backend's link conditioner (#301) - the same rules as the
// native one in link_conditioner.h, which says what each condition does.
// Everything a node sends and receives over its PeerJS connections passes
// through offer(); claynetwork_wasm.cpp embeds this file and evaluates it
// once per page. Plain JS without the browser, so node checks it too
// (link_conditioner.test.js).

function create(options) {
    const opts = options || {};
    // Injected clock and random source for tests; with a clock given,
    // nothing is put on a timer and the test calls pump()
    const clock = opts.now || null;
    const random = opts.random || Math.random;
    const now = clock || (() => (typeof performance !== 'undefined' ? performance.now() : Date.now()));

    let loss = 0, latencyMs = 0, jitterMs = 0, bandwidthKbps = 0;
    let blackout = false, dropSignaling = false;

    const pending = [];             // ordered by (due, order)
    const held = { out: [], in: [] };
    const lastReliableDue = { out: 0, in: 0 };
    const linkFreeAt = { out: 0, in: 0 };
    let nextOrder = 0;
    let timer = null;
    const stats = { dropped: 0, held: 0 };

    function num(v) { const n = Number(v); return isFinite(n) ? n : 0; }

    function active() {
        return loss > 0 || latencyMs > 0 || jitterMs > 0 || bandwidthKbps > 0 || blackout;
    }

    function setConditions(c) {
        c = c || {};
        const wasBlackout = blackout;
        loss = Math.min(1, Math.max(0, num(c.loss)));
        latencyMs = Math.max(0, Math.trunc(num(c.latencyMs)));
        jitterMs = Math.max(0, Math.trunc(num(c.jitterMs)));
        bandwidthKbps = Math.max(0, Math.trunc(num(c.bandwidthKbps)));
        blackout = !!c.blackout;
        dropSignaling = !!c.dropSignaling;
        if (wasBlackout && !blackout) releaseHeld();
    }

    function conditions() {
        return { loss, latencyMs, jitterMs, bandwidthKbps, blackout, dropSignaling };
    }

    // bytes may be a number or a function computing it, so the size of a
    // message is only worked out when a bandwidth cap needs it
    function offer(dir, stateChannel, bytes, deliver) {
        if (!active() && pending.length === 0) {
            deliver();
            return;
        }
        if (stateChannel && (blackout || (loss > 0 && random() < loss))) {
            stats.dropped++;
            return;
        }
        if (!stateChannel && blackout) {
            held[dir].push({ stateChannel, bytes, deliver });
            stats.held++;
            return;
        }
        schedule(dir, stateChannel, bytes, deliver);
    }

    function schedule(dir, stateChannel, bytes, deliver) {
        const t = Math.floor(now());
        let departure = t;
        if (bandwidthKbps > 0) {
            const size = typeof bytes === 'function' ? bytes() : bytes;
            // kbit/s is bit/ms
            linkFreeAt[dir] = Math.max(t, linkFreeAt[dir]) + size * 8 / bandwidthKbps;
            departure = linkFreeAt[dir];
        }
        let due = Math.ceil(departure) + latencyMs;
        if (jitterMs > 0) due += Math.floor(random() * (jitterMs + 1));
        if (!stateChannel) {
            due = Math.max(due, lastReliableDue[dir]);
            lastReliableDue[dir] = due;
        }
        const p = { due, order: nextOrder++, deliver };
        let pos = pending.length;
        while (pos > 0 && pending[pos - 1].due > due) --pos;
        pending.splice(pos, 0, p);
        armTimer();
    }

    function releaseHeld() {
        for (const dir of ['out', 'in']) {
            const h = held[dir];
            held[dir] = [];
            for (const e of h) schedule(dir, e.stateChannel, e.bytes, e.deliver);
        }
    }

    function clear() {
        pending.length = 0;
        held.out = []; held.in = [];
        lastReliableDue.out = lastReliableDue.in = 0;
        linkFreeAt.out = linkFreeAt.in = 0;
        if (timer !== null) { clearTimeout(timer); timer = null; }
    }

    function pump(nowMs) {
        // A delivery may offer new packets, so each one leaves the list first
        while (pending.length > 0 && pending[0].due <= nowMs) {
            const p = pending.shift();
            try { p.deliver(); } catch (e) { console.error('[ClayNetwork] conditioned delivery failed:', e); }
        }
        armTimer();
    }

    function armTimer() {
        if (clock) return;
        if (timer !== null) { clearTimeout(timer); timer = null; }
        if (pending.length === 0) return;
        const wait = Math.max(0, pending[0].due - Math.floor(now()));
        timer = setTimeout(() => { timer = null; pump(Math.floor(now())); }, wait);
    }

    return {
        setConditions, conditions, active, offer, clear, pump, stats,
        dropSignaling: () => dropSignaling,
    };
}

module.exports = { create };
