// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Bus — where an instrument's voices are mixed before the master sum.
// Each bus is a stereo buffer with a volume of its own, so a game sets
// its sound effects, its music and its voices apart without touching
// a single instrument. The bus is also the place later per-bus effects
// (echo, reverb) attach to.

#pragma once

#include <cstdint>

namespace clay::sound {

enum class Bus : uint8_t { Sfx = 0, Music = 1, Voice = 2 };

inline constexpr int kBusCount = 3;

// Gains of a mono signal in the left and right channel for `pan` in
// -1 (left) .. +1 (right). A balance law: the centre is unity in both
// channels, so mono content renders the same samples in each, and
// panning only attenuates the far side, down to silence at the edge.
inline void panGains(float pan, float& left, float& right)
{
    left  = pan > 0.0f ? 1.0f - pan : 1.0f;
    right = pan < 0.0f ? 1.0f + pan : 1.0f;
}

} // namespace clay::sound
