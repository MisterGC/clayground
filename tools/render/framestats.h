// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QJsonObject>

class RenderHost;

// What a sandbox's frames cost (#571): the frames it really draws over a run
// of 1/60 s slots, the CPU time each slot takes, and the draw calls and
// vertices of what is drawn.
//
// The slots are wall-clock time, the way a window's render loop sees them:
// events and timers arrive as they would in the loader, animations and the
// sim clock advance once per slot as they do on a display's vsync, and a
// frame is drawn only when the scene asked for one. The time spent waiting
// for the next slot is not in any number - it is what the old trace's 16 ms
// padding was.
namespace FrameStats {

// Runs a second of slots nobody counts - the setup's last transitions settle
// in it - then measures 'slotCount' frame slots and returns the summary
// --stats prints:
//   frames     the slots measured
//   rendered   frames the window really drew in them
//   seconds    wall time of the run
//   cpuMs      process CPU time per slot: median, mean, min, max
//   loadAverage the machine's one-minute load average at the end, null on
//              Windows - CPU time moves with it
//   cpuInstructions  instructions the process retired per slot, the same
//              way; null where the platform does not count them (only
//              macOS does). Unlike CPU time it holds under load.
//   renderMs   wall time of drawing one frame, over the drawn frames
//   drawCalls  draw calls per drawn frame, summed over every View3D
//   vertices   vertices per drawn frame, the same way
//   views3d    the View3Ds counted
// renderMs, drawCalls and vertices are null when nothing was drawn, the
// last two also without a View3D. Draw calls and vertices are Quick 3D's
// (View3D.renderStats with extended data); 2D items are not in them, and a
// View3D that did not redraw in a frame counts its last frame.
QJsonObject measure(RenderHost& host, int slotCount);

} // namespace FrameStats
