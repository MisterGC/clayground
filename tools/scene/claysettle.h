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

} // namespace ClayScene
