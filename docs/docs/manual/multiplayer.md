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

Every peer pair is connected by two WebRTC data channels - natively, in the
browser, and between a native and a browser node:

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

### Many objects: one key each

A snapshot without a key is sequenced per sender: a newer one from that node
makes every older one stale. That suits one snapshot per node. A node that
owns many objects - the host streaming every enemy - gives each object its
own key instead, so a late update for one enemy is never dropped because
another enemy's was newer:

```qml
Timer {
    interval: 33; repeat: true
    running: network.connected && network.isHost
    onTriggered: for (const e of enemies)
        network.broadcastState({x: e.xWu, y: e.yWu, h: e.hp}, e.uid)
}

Network {
    onStateReceived: (from, data, sentAt, key) => {
        if (key) enemyById[key].pushState(data, sentAt)
    }
}
```

Keyed updates are sent together when control returns to the event loop -
once per frame for the updates of one frame's handlers - or right away with
`network.flushState()`, packed into datagrams of about 1200 bytes, so a
frame of 100 objects costs a few datagrams, not 100. `syncStats` shows them
per key, and `stateAgeMs(nodeId, key)` says how fresh one object is.

## One clock for everyone: sessionTime

Each node's wall clock is its own, and NTP moves it now and then. The network
has one clock all nodes share instead: `network.sessionTime`, milliseconds
since the host created the network. A joiner syncs to it from the pings it
already sends the host, and is within a few milliseconds of it about 2 s
after joining (`network.sessionTimeSynced`) - also over an internet link
with 100 ms of latency and jitter.

Every message and every state carries the session time it was sent at, as
`sentAt`:

```qml
Network {
    // how long the hit took to arrive
    onMessageReceived: (from, data, sentAt) => {
        if (data.hit) applyHit(data, network.sessionTime - sentAt)
    }
}
```

and an event can be scheduled for the same moment on every node by sending a
session time ahead: `network.broadcast({wave: 3, at: network.sessionTime +
500})`, with each node starting the wave once its own `sessionTime` reaches
`at`.

## Rendering remote entities: StateInterpolator

Raw 20 Hz updates rendered directly look jittery, and smoothing them with
`Behavior` animations fights the property system (see below). Use
`StateInterpolator`: it buffers timestamped snapshots and renders the entity
a small constant delay in the past, always blending between two known
states - the standard technique used by fast-paced multiplayer games. Hand
it the sender's timestamp (third argument of `stateReceived`): snapshots
then sit on the sender's timeline, so a burst that arrives late after a
stall plays back at the sender's speed instead of being squeezed into the
milliseconds of its arrival.

```qml
// Remote avatar
PhysicsItem {
    id: avatar

    function pushState(data, sentAt) { sync.push(data, sentAt) }

    StateInterpolator {
        id: sync
        autoDelay: true         // sized from the observed jitter; or set
                                // delayMs >= 2x the sender's update interval
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
    onStateReceived: (from, data, sentAt) => remoteAvatars[from]?.pushState(data, sentAt)
}
```

Call `sync.reset()` when the entity teleports (level change, respawn) so it
snaps instead of gliding across the map.

Give the interpolator the network and the node whose state it shows -
`network: theNetwork` and `nodeId: from` - and it runs on the session clock
and places snapshots with `network.transitMs(nodeId)`, the offset of that
node's stream, which the network estimates once per sender. A host streaming
100 enemies then has its offset estimated once on each receiver, not once per
enemy.

One interpolator per replicated object is affordable: an interpolator works
per frame only while it has something to blend. Once its value rests - a
single snapshot, or the newest one held after `maxExtrapolationMs` -
`updated` fires once more and its frame loop stops until the next `push`.
While it blends it writes into two value objects in turn instead of making a
new one every frame, so copy what you keep from `value` beyond the frame.

The delay is the visible lag: every 10 ms puts a 7.5 Wu/s entity 0.075 Wu
behind where it really is, so keep it as small as the stream allows.
`autoDelay` derives it from the sender's period and the observed lateness
of updates (about twice the period plus the 95th-percentile jitter) and
glides towards that value, so a LAN session ends up around 50 ms at 60 Hz
sends while an internet session gets what its jitter needs. The period is
the median of the last nine intervals between updates, so an object that
rests and sends nothing keeps its delay when it moves again. Sending on
every physics step instead of a 20 Hz timer is what makes the small delay
possible; the lossy channel makes the rate cheap.

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
- `hostId` names the host on every node (on the host it equals `nodeId`).
  Compare a sender against it to tell the host's word from a joiner's;
  don't assume the host's id looks a certain way - it is `"HOST"` with
  Local signaling and the network code with Cloud. The host names itself
  in the welcome it answers a joiner's handshake with.
- Joining is a handshake: a joiner from another build (`wireVersion`),
  another app (`appId`) or with the wrong room `password` is refused with
  `joinRefused(reason, message)` and never shows up in `nodes`. Set a
  `password` when a code could leak - a stream, a public chat - and show
  the joiner a password prompt on `"wrong-password"` and an "update the
  game" note on `"incompatible-version"`. The host keeps each joiner's
  `clientToken` in `clientTokens`; store the token on the joiner and set it
  again to be recognised when it comes back.
- With Cloud signaling, a host is joinable only while its connection to the
  signaling server is up. A host keeps it alive on its own; if it drops
  anyway, `signalingLost()` fires - the nodes already in stay connected,
  `acceptingJoins` is false, and the host reconnects under the same code
  on its own. Show "not open for joiners" while it is false.
- When the host leaves - `leave()`, a crash, a lost connection - every
  joiner's network ends: `nodeLeft` for every node, then `status`
  `Disconnected` with `errorOccurred`. A clean leave arrives at once, a
  silent host after `gracePeriod` (5 s) plus under a second. Handle that error
  as "the session is over", not as a failed join.
- A sender id cannot be forged. Each message is attributed to the node at
  the other end of the connection it came over; only the host's relay may
  name another sender, and only one that is in the receiver's roster -
  anything else is dropped. So `from` in `messageReceived` and
  `stateReceived` names the node whose connection carried the message, not
  whatever the message claims.
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

## Replicated objects: spawn, owner, despawn

Most of a game's networked things are objects that come and go - enemies,
items, projectiles, avatars - and each needs the same bookkeeping: who may
move it, a spawn that every node and every later joiner sees, a despawn
that no late update undoes, and what happens when its owner leaves.
`Network` keeps that table for you; the game only says what an object is.

```qml
// every node: an item per enemy, made and destroyed with the object
Replicas {
    network: gameNetwork
    type: "enemy"
    delegate: Enemy {
        id: enemy
        required property string objectId
        required property int spawnIndex
        ReplicatedObject {
            network: gameNetwork; objectId: enemy.objectId
            properties: ["x", "y", "mood"]; interpolate: true
        }
    }
}

// the host, when the level starts
for (let i = 0; i < spawns.length; ++i)
    gameNetwork.spawn("enemy", {spawnIndex: i})
gameNetwork.setSessionProperty("seed", seed)
```

Give the `Network` an id other than `network`: inside a `ReplicatedObject`,
`network: network` names the property itself and binds it to nothing.

- **Owner.** An object belongs to the node that spawned it, or to the node
  the host spawns it for (`spawn(type, props, {owner})`). Only the owner's
  `ReplicatedObject` sends; every other node applies what arrives - and only
  what the owner sent: a state from any other node is dropped. Hand an
  object over with `setOwner(id, nodeId)` (the owner or the host may).
- **Ids are the network's.** `spawn()` returns an id that is never used
  again. Keep your own key in `props` - an enemy's spawn index, a player's
  `clientToken` - and find the object through it (`objects("avatar")`,
  then match `props.token`).
- **The host orders everything.** Spawns, despawns and owner changes go
  through the host, which checks who may and passes them on. A spawn
  appears on its spawner at once and on the others a hop later; a spawn
  the host refuses comes back to its spawner as `objectDespawned`.
- **Despawn is final.** State that was under way when an object despawned
  finds no object and is dropped; it cannot bring the object back.
- **Late joiners see the world.** The host sends a node that joins every
  live object with its owner and last state, then the session properties
  (`setSessionProperty`, `sessionProperties`) - a seed or the level travel
  this way instead of a start message a late joiner would miss.
- **When the owner leaves**, each of its objects despawns or passes to the
  host, as it was spawned: `{onOwnerLeft: "despawn"}` (default) for an
  avatar, `"host"` for an item that should stay in the world.
- **Resting objects stay right.** A `ReplicatedObject` sends while its
  properties change and, once they rest for `settleMs`, sends the last
  state once more over the reliable channel - a lost final update does not
  leave anyone with a stale position.
- **Stopped objects stop in place.** An object that stops dead sends its
  state once more about one and a half of its update periods later, so an
  interpolating node holds it where the owner stopped it instead of
  extrapolating its motion until the settle.

Properties may be numbers, strings, booleans or plain objects; with
`interpolate` the numbers are blended and a string switches with the
snapshot it came with, so an enemy's AI state changes in step with its
position. Objects travel only between a joiner and its host - in the
browser a joiner closes any other connection - and need the Star topology.
Object states go out with the keyed states of the same frame, batched; 30
objects at 20 Hz take two datagrams per frame.

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
- **rtt high but rate fine** - pure latency; use `autoDelay` (or raise
  `delayMs`) on your interpolators rather than fighting jitter.

The same numbers are available programmatically via `network.syncStats`,
`network.peerStats` and `network.stateAgeMs(nodeId)` - including from the
[Inspector]({{ site.baseurl }}/docs/manual/inspector/), which makes
multi-instance multiplayer sessions scriptable end to end (that is exactly
how `plugins/clay_network/tests/gym` verifies all of the above in CI,
natively and in the browser).

Two instances on one machine see a perfect network. To see what your game
does on a bad one, put a node behind a simulated link:

```qml
network.linkConditions = { loss: 0.1, latencyMs: 80, jitterMs: 20 }
network.linkConditions = { blackout: true }   // and back with {}
```

State updates are lost and delayed, reliable messages only delayed - see
the `Network.linkConditions` reference for every key. It works the same on
desktop and in the browser, so a test written against it covers both.

## Checklist

- [ ] Positions via `broadcastState`, events via `broadcast`
- [ ] Snapshots self-contained, 15-20 Hz
- [ ] Remote entities rendered through `StateInterpolator` (no `Behavior`)
- [ ] `reset()` on teleports and level changes
- [ ] Host authoritative for global events; shared seed for procedural content
- [ ] Remote avatars spawned per `nodes` entry, keyed by node id
- [ ] Things that come and go spawned as replicated objects, with an `onOwnerLeft` that fits
- [ ] `NetworkMonitor` visible in dev builds
- [ ] Played once with `linkConditions` set to loss, latency and a blackout
- [ ] Joiners end the session on the host's `errorOccurred`, and quit with `leave()`
- [ ] `appId` set; a `password` where a code could leak; `joinRefused` handled
