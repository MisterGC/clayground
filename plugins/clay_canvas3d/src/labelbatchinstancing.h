// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef LABELBATCHINSTANCING_H
#define LABELBATCHINSTANCING_H

#include <QQuick3DInstancing>
#include <QVector3D>
#include <QVector4D>
#include <QVariantList>
#include <QByteArray>
#include <QList>
#include <QPointer>

#include "labelglyphatlas.h"

// Per-glyph instance table for LabelBatch3D. Shapes each label (single line,
// QFontMetricsF advances) against a shared LabelGlyphAtlas and emits one
// 80-byte instance per inking glyph. Mirrors LineBatchInstancing's
// dynamic-buffer / markDirty architecture.
//
// FROZEN 80-byte glyph instance contract (read in label_batch.vert via
// INSTANCE_MODEL_MATRIX * basis vectors):
//   translation (M*(0,0,0,1)) = anchor world position (X, Y, Z)
//   col0 (M*(1,0,0,0))        = (offX, offY, size)  label-local base px, y-up
//   col1 (M*(0,1,0,0))        = (u0, v0, u1)        atlas UV (v0 top)
//   col2 (M*(0,0,1,0))        = (v1, glyphW, glyphH)
//   INSTANCE_COLOR            = glyph rgba
//   INSTANCE_DATA             = (flags, opacity, glyphAngle, 0)
// INSTANCE_DATA.z is the per-glyph yaw about the quad normal, in radians (0 =
// no rotation, the straight-baseline default written by every shipped path).
// Only the curved-label mode (setCurvedLabels, used by PathLabel3D glyph
// placement) ever writes a non-zero angle; the straight setLabels path keeps it
// 0, so its output is byte-identical to before the field was claimed.
// The pill table (one instance per label, for LabelPillInstancing) reuses the
// same slots: col0 = (pillCenterX, pillCenterY, size), col2.yz = (pillW, pillH),
// INSTANCE_COLOR = (1, 1, 1, opacity).
class LabelBatchInstancing : public QQuick3DInstancing
{
    Q_OBJECT
    QML_NAMED_ELEMENT(LabelBatchInstancing)

    Q_PROPERTY(LabelGlyphAtlas *atlas READ atlas WRITE setAtlas NOTIFY atlasChanged)
    Q_PROPERTY(QVariantList labels READ labels WRITE setLabels NOTIFY labelsChanged)
    Q_PROPERTY(int count READ count NOTIFY labelsChanged)
    Q_PROPERTY(int glyphCount READ glyphCount NOTIFY labelsChanged)
    Q_PROPERTY(qreal pillPadding READ pillPadding WRITE setPillPadding NOTIFY pillPaddingChanged)
    Q_PROPERTY(QVector3D boundsMin READ boundsMin NOTIFY boundsChanged)
    Q_PROPERTY(QVector3D boundsMax READ boundsMax NOTIFY boundsChanged)
    // Diagnostics.
    Q_PROPERTY(double shapeMsLast READ shapeMsLast NOTIFY labelsChanged)

public:
    explicit LabelBatchInstancing(QQuick3DObject *parent = nullptr);

    LabelGlyphAtlas *atlas() const { return m_atlas; }
    void setAtlas(LabelGlyphAtlas *atlas);

    QVariantList labels() const;
    void setLabels(const QVariantList &labels);

    int count() const { return static_cast<int>(m_labels.size()); }
    int glyphCount() const { return m_glyphCount; }
    qreal pillPadding() const { return m_pillPadding; }
    void setPillPadding(qreal p);
    QVector3D boundsMin() const { return m_boundsMin; }
    QVector3D boundsMax() const { return m_boundsMax; }
    double shapeMsLast() const { return m_shapeMsLast; }

    // Moves labels without re-shaping: packed float32 [x, y, z] per label,
    // starting at label index first. Rewrites the anchor (translation) of every
    // glyph of those labels and their pill instance, then re-uploads once.
    Q_INVOKABLE void updatePositionsBulk(const QByteArray &positions, int first = 0);

    // Read-only priority list for the future declutter manager.
    Q_INVOKABLE QVariantList priorities() const;

    // Per-codepoint advance widths of text in world units at the given render
    // size (advanceBasePx * size / baseSize). Bakes missing glyphs first. Used by
    // PathLabel3D glyph placement to lay each glyph along a curve; the returned
    // list has one entry per Unicode code point of text (spaces included).
    Q_INVOKABLE QVariantList glyphAdvances(const QString &text, qreal size) const;

    // Curved-label entry mode (per-glyph text-on-curve, maplibre's model). Each
    // element is
    //   { text, color, size, opacity,
    //     positions: [Qt.vector3d per code point],
    //     angles:    [real radians per code point] }
    // The CPU does NOT lay glyphs on a straight baseline here: every inking glyph
    // is emitted at its own world anchor (positions[i]) rotated by angles[i]
    // (INSTANCE_DATA.z). positions/angles are indexed per code point aligned with
    // text.toUcs4(); blank glyphs (spaces) consume an index but emit no quad.
    // Setting curved labels switches the table into curved mode; setLabels
    // switches it back. No pill table is produced in curved mode.
    Q_INVOKABLE void setCurvedLabels(const QVariantList &labels);

    // Inspection hook (issue #165): the labels as the renderer resolved them,
    // so "did that label render, at what size, where?" is answerable without
    // reading pixels. Pull-only - it reports state this class already keeps
    // and never maintains anything for the inspector's sake.
    Q_INVOKABLE QVariantMap clayInspect() const;

    // Pill instance buffer accessors (consumed by LabelPillInstancing).
    const QByteArray &pillData() const { return m_pillData; }
    int pillCount() const { return static_cast<int>(m_labels.size()); }

signals:
    void atlasChanged();
    void labelsChanged();
    void pillPaddingChanged();
    void boundsChanged();
    void pillDataChanged();

protected:
    QByteArray getInstanceBuffer(int *instanceCount) override;

private:
    struct Label {
        QVector3D position;
        QVector4D color{1, 1, 1, 1};
        float size = 24.0f;
        float opacity = 1.0f;
        int priority = 0;
        QString text;
        int glyphStart = 0;
        int glyphCount = 0;
    };

    struct CurvedLabel {
        QString text;
        QVector4D color{1, 1, 1, 1};
        float size = 24.0f;
        float opacity = 1.0f;
        QVector<QVector3D> positions; // per code point
        QVector<float> angles;        // per code point (radians)
    };

    void reshape();
    void reshapeCurved();
    void writeAnchor(char *entry, const QVector3D &p) const;

    QPointer<LabelGlyphAtlas> m_atlas;
    QList<Label> m_labels;
    QList<CurvedLabel> m_curvedLabels;
    bool m_curvedMode = false;
    QByteArray m_glyphData; // glyphCount * 80 bytes
    QByteArray m_pillData;  // labelCount * 80 bytes
    int m_glyphCount = 0;
    qreal m_pillPadding = 8.0;
    QVector3D m_boundsMin;
    QVector3D m_boundsMax;
    double m_shapeMsLast = 0.0;
    bool m_dirty = false;
};

// Companion instancing that renders the per-label pill backgrounds from the
// LabelBatchInstancing's pill buffer (deck.gl's two-draw model). Holds no data
// of its own; it just forwards the source's pill table and re-uploads whenever
// the source reshapes.
class LabelPillInstancing : public QQuick3DInstancing
{
    Q_OBJECT
    QML_NAMED_ELEMENT(LabelPillInstancing)

    Q_PROPERTY(LabelBatchInstancing *source READ source WRITE setSource NOTIFY sourceChanged)

public:
    explicit LabelPillInstancing(QQuick3DObject *parent = nullptr);

    LabelBatchInstancing *source() const { return m_source; }
    void setSource(LabelBatchInstancing *source);

signals:
    void sourceChanged();

protected:
    QByteArray getInstanceBuffer(int *instanceCount) override;

private:
    QPointer<LabelBatchInstancing> m_source;
};

#endif // LABELBATCHINSTANCING_H
