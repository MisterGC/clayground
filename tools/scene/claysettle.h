// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QString>

namespace ClayScene {

class Host;

// "Has the picture stopped moving?" answered by comparing successive frames
// rather than by asking the animation system. Public API only, and it covers
// what animation bookkeeping cannot: physics, shader time and 3D motion all
// show up as changing pixels.
struct SettleRequest
{
    int timeoutMs = 3000;       // upper bound; a scene with continuous motion
                                // never settles and that is a valid answer
    int stableFrames = 3;       // consecutive identical frames required
    int intervalMs = 32;        // roughly two frames at 60 Hz
    int tolerance = 2;          // per-channel difference still counted equal
};

struct SettleResult
{
    bool settled = false;
    int waitedMs = 0;
    int framesCompared = 0;
    double lastDelta = 0.0;     // fraction of pixels still changing
    QString error;
};

// Spins the event loop, sampling the rendered scene until it stops changing.
// Returns settled=false (never an error) when the timeout hits first: an
// animation that keeps running is a fact about the scene, not a failure.
SettleResult settle(const Host& host, const SettleRequest& request = {});

// The other half of "is the scene ready yet": settle answers it in pixels,
// waitFor answers it in the scene's own terms - "root.spawned.length === 12".
// Cheaper than settling, and the only way to wait for something that never
// shows up as motion.
struct WaitRequest
{
    QString expression;
    int timeoutMs = 3000;
    int intervalMs = 32;
};

struct WaitResult
{
    bool satisfied = false;
    int waitedMs = 0;
    int polls = 0;
    QString error;      // a broken expression; NOT "the condition stayed false"
};

// Polls the expression in the root's own context until it is truthy. A
// timeout is reported as satisfied=false with no error, a typo as an error -
// telling those apart is the whole point of having this instead of a sleep.
WaitResult waitFor(Host& host, const WaitRequest& request);

} // namespace ClayScene
