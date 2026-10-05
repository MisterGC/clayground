# Changelog

All notable changes to Clayground are documented in this file. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are
calendar-style (`VERSION` at the repository root). Releases up to 2026.7 are
described on their [GitHub release pages](https://github.com/MisterGC/clayground/releases).

## [2026.8] - Unreleased

Games get a networking foundation: a host every node knows, a join handshake,
keyed state in batches, a session clock and replicated objects, on native and
in the browser, over LAN and the internet. The 2D world gains coloured lights,
screen effects and impact feel, and the Web Runtime runs a game that brings
its own shaders. One-line `broadcastState(data)` is unchanged; everything new
is opt-in.

### Added

#### Networking (#310)

- **Every node knows the host, and a sender cannot be forged.** `Network.hostId` names the host on every node (`"HOST"` with Local signaling, the network code with Cloud). Both backends credit a message to the node at the other end of the connection it arrived on; a `from` written by the sender no longer counts. (#298)
- **A join handshake.** A joiner is a node only once the host welcomes it: its first message carries the wire version, `appId`, room `password` and `clientToken`, and the host answers with a welcome or a refusal with a reason, `joinRefused(reason, message)`. `Network` gains `password`, `appId`, `clientToken`, `clientTokens` and `wireVersion`; with no password and no `appId`, joining works as before. (#323)
- **Keyed state in batches.** `broadcastState(data, key)` sequences state per sender and key, so a late update for one object is not dropped behind another's; one frame's keyed states leave packed into datagrams of at most 1136 B. `stateReceived` gains `key`, `flushState()`, `stateAgeMs(nodeId, key)` and per-key `syncStats` report it. (#302)
- **A session clock.** `Network.sessionTime` is the host's monotonic time, shared by every node through the pings joiners already send; every message and state carries `sentAt` on it, and `messageReceived(fromId, data, sentAt)` passes it on. `Network.transitMs(nodeId)` gives each sender's offset, which `StateInterpolator { network; nodeId }` uses instead of estimating its own. (#304)
- **Replicated objects.** `Network.spawn(type, props, {owner, onOwnerLeft})` creates an object with a network-made id on every node; only its owner's state counts, the host orders spawns, despawns and owner changes, and a node that joins late gets every live object with its last state and the host's session properties. In QML, `ReplicatedObject` binds an item's properties to an object and `Replicas` makes an item per object of a type. (#306)
- **`ReplicatedObject.steppedProperties`** lists numbers a receiver never blends, such as HP: each switches with its snapshot at the interpolator's render delay (`StateInterpolator.stepKeys`). (#368)
- **An object that stops dead comes to rest where its owner stopped it**: `ReplicatedObject` sends its state once more 1.5 update periods after the last change, before the reliable settle. (#367)
- **Sender-timed state and an automatic delay.** `StateInterpolator.push(state, sentAt)` places snapshots on the sender's timeline instead of their arrival time; `autoDelay` sizes the render delay from the sender's period and the recent lateness, within `minDelayMs..maxDelayMs`, and `effectiveDelayMs` reports it. (#290–#294)
- **Leaving is noticed.** `leave()` sends a goodbye, a peer silent for `Network.gracePeriod` (5000 ms) is dropped, and a joiner whose host goes away ends with `nodeLeft` for every node and `status` `Disconnected`. `Network.hostLostReason` (`host-left`, `host-timeout`, `connection-lost`) is set before `connected` turns false, and `hostLost(reason, message)` follows. (#299, #376)
- **Signaling survives a drop.** A lost Cloud signaling connection reconnects under the same id instead of ending the session (`signalingLost()`, `acceptingJoins`); native Cloud signaling sends the PeerJS heartbeat every 5 s. (#299, #320)
- **TLS is verified.** Native Cloud signaling checks the server's certificate; `Network.verifySignalingCertificate` (default `true`) is the explicit opt-out. (#320)
- **LAN join secret.** LAN codes are `L<ip>-<port>-<secret>`; the embedded signaling server refuses a wrong or missing secret with "Wrong LAN code". (#290–#294, #321)
- **A session property may hold an object or an array**, nested, and arrives whole on every joiner and on a late joiner. (#375)
- **A link conditioner.** `Network.linkConditions` puts a node behind a simulated bad link on both backends: `loss`, `latencyMs`, `jitterMs`, `bandwidthKbps`, `blackout`, `dropSignaling`. (#301)
- **Browser parity.** The browser's state channel is a second, unordered `RTCDataChannel` without retransmits on the node's connection, like native's; browser `peerStats` carry native's fields, plus `stateOrdered` and `stateMaxRetransmits` on both. (#307, #363)
- **Net gyms** that run loss, latency, a blackout, the host leaving, the handshake, keyed objects at 30 Hz and the session clock natively over Local and Cloud signaling, in the browser, and with a native and a browser node in one network (`run_net_gym_mixed.py`). (#301, #307)

#### 2D world, physics and behaviour

- **Coloured 2D lights.** `LightLayer2d` / `Light2d` draw coloured lights with soft shadows from a grid of occluders in one WebGL-safe overlay; `emissive` draws flames, sparks and eyes above the darkness. (#296)
- **Screen effects.** `ScreenFx2d` adds vignette, grade, flash, pulse and a low-health heartbeat to the world canvas only, the HUD untouched. (#296)
- **Impact feel.** `ClayWorld2dCamera` gets trauma shake and a spring-back `kick()`; `ClayWorld2d.hitStop(ms, scale)` slows physics, and `hitStopMode: "view"` instead holds the picture while physics steps on, exposed as `ClayWorld2d.picture`. (#296, #309)
- **`PhysicsTimer`**, a timer with the interface of a QML `Timer` whose clock is a Box2D `World`, so cooldowns and AI stand still with a paused, single-stepped or hit-stopped world. (#329)
- **A sensor hears a body destroyed inside it**: `PhysicsItem` and `VisualizedPolyBody` send `endContact` to every fixture they touch before the item goes, with the item still readable. (#371)

#### Web Runtime, tools and build

- **A game with its own shaders runs in the dojo, `clayrender` and the Web Runtime**: a sandbox's `*.frag`/`*.vert` are baked into `.qsb` beside them, GLSL 300 es included; a `Window` root is shown and gets keyboard focus without a click; `tools/webdojo/run_in_browser.py` serves a local game and checks it in headless Chromium. (#296)
- **Music plays on the Web Runtime** (`.mp3`, after a user gesture) instead of taking the page down, and the shared sound sink counts as running only once an audio device really opened. (#261, #262)
- **`KeyValueStore` keeps its data across a browser reload**: a WebAssembly app linking `Clayground.Storage` keeps its data directory in IndexedDB; `StorageSync.persist()` writes it back. (#341)
- **`clay_app_package(<app> ...)`** gives an app a `<app>_package` target that writes a package carrying the app, Qt and every Clayground plugin: a macOS `.app` zip, a Windows folder zip, a Linux AppImage. See the Desktop Packages page. (#380)
- **`ExplodedView3D`** in `Clayground.Lab`: any composition of named parts comes apart along its axes, staged and labelled, by id. (#274)
- **Board pieces on the canvas**: `Poly`, `Connector` and `Text` take a `sketch` pen and a draw-on `progress`, `Connector` grows arrow heads, a new `Axes` item draws labelled axes in world units, and `ClayCanvas.fit()` frames a world rectangle. (#272)
- **The inspector's `eval` returns objects** as their properties, and JS arrays as arrays, instead of `null`. (#336)
- **`./verify.sh`** builds and runs only the tests a change can reach; `ctest --preset default` runs 8 tests at a time, and every test carries a component label. (#384)
- **`CHANGELOG.md`**, this file. (#330)

### Changed

- **The wire version is 5.** A node from an earlier build is refused with `incompatible-version`, so every node of a session needs 2026.8. (#323, #302, #304, #306, #307)
- **A native Cloud node rejects a `wss` signaling server whose certificate does not verify**, where it connected before. Set `verifySignalingCertificate: false` for a server with a self-signed certificate. (#320)
- **LAN codes changed format** to `L<ip>-<port>-<secret>`; a code from 2026.7 does not join a 2026.8 host. (#290–#294, #321)
- **An id already registered is refused** with `ID-TAKEN` by the LAN signaling server and clay-dev-server's relay, instead of replacing the first registration. (#321)
- **ICE `Disconnected` is no longer a leave**; only a failed or closed connection and silence past `gracePeriod` are. (#299)
- **`stateReceived(fromId, data, sentAt, key)`** carries two more arguments; `sentAt` is session time. Two-argument handlers keep working. (#295, #302, #304)
- **`MoveTo` re-aims on simulated time** (a `PhysicsTimer`), so a paused world holds its heading and a single-stepped run takes the same path. (#340)
- **A resumed physics world steps by one frame**, not by the whole pause; the `thirdparty/qml-box2d` submodule moves to a per-world step clock. (#338)
- **The presets generate Ninja**, llama.cpp and libdatachannel are fetched once into a cache every checkout shares, and the compiler runs through ccache. A build directory configured with Makefiles has to be configured anew. (#385)
- **`-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is no longer needed** under CMake 4, also for a game adding Clayground with `add_subdirectory`. (#334)
- **CI runs on PRs into `release/**`**, caches its dependencies and runs the desktop tests in shards, with `BUILD_TESTING` on. (#311, #386)

### Fixed

- A libdatachannel callback arriving after a `ClayNetwork` was destroyed called into freed memory. (#357)
- A socket reusing a just-closed socket's file descriptor received that socket's poll events (patched libdatachannel). (#348)
- `LocalSignalingClient` resets its socket callbacks before it closes. (#359)
- A `StateInterpolator` at rest kept its frame loop running and made a new object every frame. (#305)
- The auto delay drifted after an interpolator's clock changed, and doubled after an object's rest. (#363, #366, #374)
- A body moved by setting its position did not begin contact with a sleeping sensor. (#369)
- `ClayWorld2d` logged a `TypeError` on every room change. (#335)
- An app could copy `bin/qml` before every QML plugin, `Clayground.Svg` and Box2D's module were built into it. (#350, #381, #380)
- `clay_sound` did not build with GCC 11. (#382)
- Patch files and lab records broke in a CRLF checkout on Windows. (#383, #330)
- Under Qt 6.10 a hot reload in the dojo showed the previous file instead of the saved one. (#385)
- A note card exactly as tall as the annotation list was scrolled 6 px past its top. (#330)
- `Poly.closed` was always true, so every open poly drew a closing edge. (#272)

[2026.8]: https://github.com/MisterGC/clayground/compare/v2026.7...v2026.8
