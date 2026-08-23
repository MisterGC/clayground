// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Spectral lip-sync: mono samples in, a mouth-shape timeline out.
//
// WHY THIS IS SEPARATE AND PURE
//
// The envelope analyser inside Speech reads loudness and zero crossings.
// Loudness is a decent guess at how far a jaw has dropped and nothing at all
// about its shape, so "oo", "ee" and "ah" all came out as the same slot at
// three sizes. What separates them is where the first two formants sit, and
// that needs a spectrum.
//
// This file has no QObject, no engine, no media and no clock, for the same
// reason a lab kit's model code does not: it is the part with the arguable
// numbers in it, and arguable numbers are worth testing. Feed it synthesised
// input and it must classify - a low-F1/high-F2 pair is "ee" whatever else
// is true.
//
// WHAT IT ASSUMES
//
// One close-miked speaker on a reasonably dry recording. Against a music bed
// the formant bands read the instruments, and against heavy reverb the gaps
// that mark a closure fill in. Both are why every frame carries a confidence
// and why a frame that cannot be read falls back to the envelope rather than
// to a guess - see confidence in Frame.

#ifndef CLAY_CHARACTER3D_VISEMEANALYSIS_H
#define CLAY_CHARACTER3D_VISEMEANALYSIS_H

#include "visemetimeline.h"

#include <QVector>

namespace ClayViseme {

// Frame-level features, exposed so the tests can assert on what was measured
// rather than only on what it was turned into. A wrong shape and a wrong
// measurement need different fixes, and one is much easier to find with the
// other in hand.
struct Frame
{
    qint64 ms = 0;
    float  level = 0.f;      // 0..1, loudness against the file's own peak
    float  openness = 0.f;   // 0..1, F1 low -> high: a proxy for jaw drop
    float  frontness = 0.f;  // 0..1, F2 back -> front: round at 0, spread at 1
    float  fricness = 0.f;   // 0..1, share of energy above 3.8 kHz
    float  confidence = 0.f; // 0..1, how much the three above may be believed
};

// Everything the analyser is allowed to assume, named once. Defaults are the
// ones the tests pin; a caller changing them is on its own.
struct Config
{
    int analysisRate = 16000; // decimated to this; 8 kHz of band is all speech needs
    int fftSize      = 512;   // 32 ms at the analysis rate
    int hopMs        = 16;    // one frame per tick of the 60 Hz mouth ticker
    // A frame quieter than this share of the file's peak is silence, not a
    // shape. The same gate the envelope analyser has always used.
    float silenceGate = 0.06f;
    // Below this the band ratios are being computed from noise. Such a frame
    // keeps its level and gives up its shape.
    float confidenceFloor = 0.18f;
};

// The measured frames, before they become a timeline. Public for the tests.
QVector<Frame> analyse(const QVector<float> &mono, int sampleRate,
                       const Config &cfg = Config());

// Frames -> timeline. Pure, and separate from analyse() so a mapping change
// can be tested without re-deriving a spectrum.
VisemeTimeline timelineFromFrames(const QVector<Frame> &frames);

// The whole pipeline. Returns an empty timeline for input it cannot use, so
// the caller falls back rather than plays silence at a moving mouth.
VisemeTimeline timelineForSamples(const QVector<float> &mono, int sampleRate,
                                  const Config &cfg = Config());

// Forced alignment: the shapes of a script, on the clock of a recording.
//
// Recognition is the hard half of lip-sync and a transcript makes it
// unnecessary. The sequence of mouth shapes is then ground truth - the text
// says there is an /m/ there, so the mouth closes, with no acoustic inference
// to get it wrong - and the only thing left to take from the audio is WHEN.
// That is a monotonic alignment between two sequences, which is dynamic
// programming and nothing cleverer.
//
// `text` is a timeline built from the script (its ms are an estimate and are
// thrown away); `frames` are the measured audio. Identity comes from the
// text, timing and emphasis from the frames. Word marks are carried across,
// so a recorded line gets the word callbacks only spoken text used to have.
//
// Returns an empty timeline when the two do not plausibly describe the same
// utterance - a transcript belonging to another take is worse than no
// transcript at all, so the caller falls back instead.
VisemeTimeline align(const VisemeTimeline &text, const QVector<Frame> &frames,
                     const Config &cfg = Config());

} // namespace ClayViseme

#endif // CLAY_CHARACTER3D_VISEMEANALYSIS_H
