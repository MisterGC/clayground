---
layout: docs
title: Multiplayer Games
permalink: /docs/manual/multiplayer/
---

`Clayground.Network` gives you peer-to-peer connectivity out of the box, but a
*smooth* real-time game needs the right patterns on top of it. This guide
covers what to send on which channel, how to render remote entities, and how
to diagnose sync problems.

## Two channels, two jobs

Every peer pair is connected by two WebRTC data channels:

- **Message channel** (`broadcast`, `sendTo`) - reliable and ordered, like
  TCP. Everything sent arrives, in order, eventually.
- **State channel** (`broadcastState`) - unordered, lost packets are *not*
  retransmitted, and every update carries a sequence number so receivers
  silently drop anything older than what they already have.

The rule of thumb:

| Data | Channel | Why |
|---|---|---|
| Positions, velocities, aim angles | `broadcastState` | Only the newest value matters; a lost packet is obsolete 50 ms later anyway |
| Attacks, pickups, deaths, chat | `broadcast` | Missing one changes the game outcome |
| Level changes, seeds, game start | `broadcast` | Everyone must agree on these |

Never send continuous state over the reliable channel: one lost packet then
delays every newer update behind it (head-of-line blocking) and the lag
snowballs on a lossy connection - the game feels increasingly "behind" and
never recovers.

## State snapshots, not deltas

Broadcast complete little snapshots at a fixed rate (15-20 Hz is plenty for
a 2D action game):

```qml
Timer {
    interval: 50; repeat: true
    running: network.connected && player !== null
    onTriggered: network.broadcastState({
        x: player.xWu, y: player.yWu,
        a: player.facingAngle,
        h: player.hp
    })
}
```

Because updates can be lost, every snapshot must be self-contained - never
send "moved 0.2 to the left".

## Rendering remote entities: StateInterpolator

Raw 20 Hz updates rendered directly look jittery, and smoothing them with
`Behavior` animations fights the property system (see below). Use
`StateInterpolator`: it buffers timestamped snapshots and renders the entity
a small constant delay in the past, always blending between two known
states - the standard technique used by fast-paced multiplayer games.

```qml
// Remote avatar
PhysicsItem {
    id: avatar

    function pushState(data) { sync.push(data) }

    StateInterpolator {
        id: sync
        delayMs: 120            // >= 2x the sender's update interval
        angleKeys: ["a"]        // degrees, interpolated via shortest arc
        onUpdated: {
            avatar.xWu = value.x
            avatar.yWu = value.y
            avatar.facingAngle = value.a
        }
    }
}

// Feed it from the network
Network {
    onStateReceived: (from, data) => remoteAvatars[from]?.pushState(data)
}
```

Call `sync.reset()` when the entity teleports (level change, respawn) so it
snaps instead of gliding across the map.

**Do not use `Behavior` on `xWu`/`yWu`.** Beyond being the wrong model for
network smoothing (every update restarts an animation from wherever it is -
rubber-banding), physics world-unit properties are bidirectionally synced
with pixel coordinates, which historically caused animations on them to
stall entirely (clayground issue #139).

## Star topology: the host is the authority

In the default Star topology, joiners connect only to the host; the host
relays traffic between joiners (`autoRelay`). Consequences:

- `nodes` lists all *other* participants on every node (the host propagates
  the roster). Spawn one remote avatar per entry, keyed by node id - state
  updates arrive tagged with the *original* sender's id even when relayed.
- Joiner-to-joiner latency is two hops. Keep that in mind for hit
  judgments; favor letting each client be authoritative over things that
  only affect itself (own position, own attacks).
- Make the host the referee for anything global: level transitions, match
  start, enemy spawns. A joiner that triggers a global event asks the host
  (`broadcast` an intent) and the host answers with the authoritative event.
  Never let each client apply a global change locally on its own - with
  procedural content the worlds silently diverge.

```qml
// Level transitions, host-authoritative
onExitReached: {
    if (network.isHost) advanceLevel()               // broadcasts levelChange
    else network.broadcast({type: "exitReached"})    // host will answer
}
onMessageReceived: (from, data) => {
    if (data.type === "levelChange") applyLevel(data.levelIndex)
    if (data.type === "exitReached" && network.isHost) advanceLevel()
}
```

Shared procedural content needs a shared seed: the host picks it and sends
it with the start message; every client generates the identical world from
it.

## Diagnosing sync problems

Drop a `NetworkMonitor` into your UI during development:

```qml
NetworkMonitor {
    network: gameNetwork
    anchors.bottom: parent.bottom; anchors.right: parent.right
}
```

Per node it shows round-trip time, incoming state rate, the age of the
newest state and how many stale updates were dropped. How to read it:

- **age growing while rate is 0** - the sender stopped broadcasting (or
  left); check their `running` condition.
- **high drop count** - the network reorders/loses heavily; your game still
  works (that is the design), but consider a lower send rate.
- **`[fallback]` marker** - the lossy state channel didn't negotiate and
  state travels over the reliable channel; expect lag under loss.
- **rtt high but rate fine** - pure latency; increase `delayMs` on your
  interpolators rather than fighting jitter.

The same numbers are available programmatically via `network.syncStats`,
`network.peerStats` and `network.stateAgeMs(nodeId)` - including from the
[Inspector]({{ site.baseurl }}/docs/manual/inspector/), which makes
multi-instance multiplayer sessions scriptable end to end (that is exactly
how `plugins/clay_network/tests/gym` verifies all of the above in CI).

## Checklist

- [ ] Positions via `broadcastState`, events via `broadcast`
- [ ] Snapshots self-contained, 15-20 Hz
- [ ] Remote entities rendered through `StateInterpolator` (no `Behavior`)
- [ ] `reset()` on teleports and level changes
- [ ] Host authoritative for global events; shared seed for procedural content
- [ ] Remote avatars spawned per `nodes` entry, keyed by node id
- [ ] `NetworkMonitor` visible in dev builds
