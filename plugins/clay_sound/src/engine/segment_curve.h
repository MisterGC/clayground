// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The shape of one envelope segment (#447): how far a segment has moved
// from its start value toward its target at progress p (0..1 of its
// time), for a curve from 0 (linear) to 1 (exponential).
//
// Exponential is the way a struck object rings out: the distance left
// to the target falls by 60 dB over the segment, a straight line in dB,
// so a segment's time is its RT60. A decay to 0 is thus a straight line
// in dB down to -60 dB, where the segment ends; the step from there to
// the target is below hearing. An attack rises fast and settles into
// the peak, a pitch sweep moves fast and settles into its end, as an
// analog envelope does. Curves between 0 and 1 mix the two shapes.

#pragma once

#include <algorithm>
#include <cmath>

namespace clay::sound {

inline double segmentShape(double p, double curve)
{
    // Linear returns p itself, so a patch at the default renders the
    // samples it did before the curve existed.
    if (curve <= 0.0) return p;
    const double c = std::min(curve, 1.0);
    // 10^(-3p): -60 dB at the segment's end.
    const double exponential = 1.0 - std::pow(10.0, -3.0 * p);
    return (1.0 - c) * p + c * exponential;
}

} // namespace clay::sound
