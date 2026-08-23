// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The mouth-shape timeline both analysers produce.
//
// Its own header because there are now two producers - the letter walk in
// Speech and the spectral analyser in visemeanalysis - and neither should
// have to include the other. Speech is a QObject dragging Qt Multimedia
// behind it; the analyser is pure and is unit-tested without either.

#ifndef CLAY_CHARACTER3D_VISEMETIMELINE_H
#define CLAY_CHARACTER3D_VISEMETIMELINE_H

#include <QPair>
#include <QVector>

// One step on the mouth-shape timeline; values are targets in [0,1].
struct VisemeKey
{
    qint64 ms = 0;
    float  open = 0.f;
    float  wide = 0.f;
    float  round = 0.f;
};

// Timeline plus the mapping from character offsets in the source text to
// timeline positions (used to re-sync on TTS word callbacks). Audio-derived
// timelines leave wordMarks empty - nothing in them knows about words.
struct VisemeTimeline
{
    QVector<VisemeKey> keys;
    QVector<QPair<qsizetype, qint64>> wordMarks; // (char offset, ms)
    qint64 durationMs = 0;
};

#endif // CLAY_CHARACTER3D_VISEMETIMELINE_H
