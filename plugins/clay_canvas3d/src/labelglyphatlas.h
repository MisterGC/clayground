// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef LABELGLYPHATLAS_H
#define LABELGLYPHATLAS_H

#include <QQuick3DTextureData>
#include <QFont>
#include <QFontMetricsF>
#include <QHash>
#include <QByteArray>
#include <QVector>

// Incremental single-channel (R8) signed-distance-field glyph atlas for the
// instanced LabelBatch3D renderer. Glyphs are rasterized CPU-side on demand
// (TinySDF: rasterize coverage via QPainter, then a Felzenszwalb exact
// Euclidean distance transform on the inside/outside coverage), packed into a
// growing shelf-packed atlas. New strings only add missing glyphs; existing
// texels are never rebuilt. One atlas per font config (family + weight + base
// size); one atlas per LabelBatch3D instance in v1.
//
// Exposed to QML as LabelGlyphAtlas so the same object can be handed to both a
// Texture (textureData) and the LabelBatchInstancing that shapes labels.
class LabelGlyphAtlas : public QQuick3DTextureData
{
    Q_OBJECT
    QML_NAMED_ELEMENT(LabelGlyphAtlas)

    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY fontChanged)
    Q_PROPERTY(int fontWeight READ fontWeight WRITE setFontWeight NOTIFY fontChanged)
    Q_PROPERTY(int baseSize READ baseSize WRITE setBaseSize NOTIFY fontChanged)
    // Read-only diagnostics for the showcase / tests.
    Q_PROPERTY(int atlasWidth READ atlasWidth NOTIFY atlasChanged)
    Q_PROPERTY(int atlasHeight READ atlasHeight NOTIFY atlasChanged)
    Q_PROPERTY(int glyphCount READ glyphCount NOTIFY atlasChanged)
    // Font metrics in base-size pixels, for callers that map a world text height
    // onto the shader's size parameter (e.g. PathLabel3D glyph placement).
    Q_PROPERTY(qreal capHeightPx READ capHeightPxQml NOTIFY fontChanged)
    Q_PROPERTY(qreal ascentPx READ ascentPxQml NOTIFY fontChanged)
    Q_PROPERTY(qreal descentPx READ descentPxQml NOTIFY fontChanged)

public:
    // Per-glyph metrics in atlas-normalized UV and label-local base pixels.
    // leftRel/offY/w/h are in base-size pixels, label-local, y-up, relative to
    // this glyph's own pen origin (baseline at y = 0). uv rect is normalized to
    // the current atlas dimensions (recomputed on every query so it stays valid
    // across atlas growth).
    struct GlyphInfo {
        float u0 = 0.0f, v0 = 0.0f, u1 = 0.0f, v1 = 0.0f;
        float advance = 0.0f;
        float leftRel = 0.0f;
        float offY = 0.0f;
        float w = 0.0f, h = 0.0f;
        bool blank = true; // space / non-inking glyph: no quad emitted
    };

    explicit LabelGlyphAtlas(QQuick3DObject *parent = nullptr);

    QString fontFamily() const { return m_family; }
    void setFontFamily(const QString &family);
    int fontWeight() const { return m_weight; }
    void setFontWeight(int weight);
    int baseSize() const { return m_baseSize; }
    void setBaseSize(int px);

    int atlasWidth() const { return m_atlasW; }
    int atlasHeight() const { return m_atlasH; }
    int glyphCount() const { return static_cast<int>(m_glyphs.size()); }

    // Ensures every glyph of the string is baked into the atlas (growing it as
    // needed) and commits the texture once. Call before shaping so no growth
    // happens mid-shape (which would invalidate already-written UVs).
    void ensureString(const QString &text);

    // Returns metrics for one code point, baking it first if necessary. UV is
    // computed from the current atlas size, so it is always consistent with the
    // committed texture as long as no baking happens between the call and use.
    const GlyphInfo &glyph(uint ucs4);

    // Font-level metrics for label centering (base-size pixels).
    float capHeight() const { return static_cast<float>(m_capHeight); }
    float ascent() const { return static_cast<float>(m_ascent); }
    float descent() const { return static_cast<float>(m_descent); }
    float baseSizeF() const { return static_cast<float>(m_baseSize); }

    // Same metrics as QML-friendly qreal accessors.
    qreal capHeightPxQml() const { return m_capHeight; }
    qreal ascentPxQml() const { return m_ascent; }
    qreal descentPxQml() const { return m_descent; }

signals:
    void fontChanged();
    void atlasChanged();

private:
    void resetAtlas();
    void rebuildFont();
    // Bakes one glyph into the atlas at the current pen, growing the atlas if
    // it does not fit; fills gi (UV recomputed by the public glyph()).
    void bakeGlyph(uint ucs4, GlyphInfo &gi);
    void growTo(int minHeight);
    void commit();

    QString m_family;
    int m_weight = 700;
    int m_baseSize = 48;
    int m_padding = 6; // SDF radius / spread in base pixels

    QFont m_font;
    QFontMetricsF m_fm{QFont()};
    double m_capHeight = 24.0;
    double m_ascent = 36.0;
    double m_descent = 10.0;

    // R8 atlas buffer, m_atlasW * m_atlasH bytes.
    QByteArray m_pixels;
    int m_atlasW = 512;
    int m_atlasH = 256;
    int m_penX = 0;      // current shelf cursor
    int m_penY = 0;      // top of current shelf
    int m_shelfH = 0;    // height of current shelf

    // Texel rect (px) kept separately so UVs can be recomputed after growth.
    struct Rect { int x, y, w, h; };
    QHash<uint, GlyphInfo> m_glyphs;
    QHash<uint, Rect> m_rects;
    GlyphInfo m_missing; // returned for failures
    bool m_dirty = false;
};

#endif // LABELGLYPHATLAS_H
