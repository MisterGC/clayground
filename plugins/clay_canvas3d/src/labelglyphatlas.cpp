// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "labelglyphatlas.h"

#include <QImage>
#include <QPainter>
#include <QSize>
#include <cmath>
#include <cstring>
#include <limits>

/*!
    \qmltype LabelGlyphAtlas
    \nativetype LabelGlyphAtlas
    \inqmlmodule Clayground.Canvas3D
    \brief Incremental single-channel SDF glyph atlas for LabelBatch3D.

    LabelGlyphAtlas rasterizes each needed glyph once (TinySDF: a QPainter
    coverage raster followed by an exact Euclidean distance transform), packs it
    into a growing R8 atlas texture, and keeps per-glyph metrics (UV rect,
    advance, label-local quad). New strings add only their missing glyphs; the
    atlas never rebuilds existing texels. One atlas covers one font config
    (family + weight + base size); LabelBatch3D owns one per instance.

    This type is used internally by LabelBatch3D. The same object is handed to
    both the glyph shaper (\l LabelBatch3D shaping) and the material's Texture,
    so the shaper's UVs always match the committed atlas.

    \sa LabelBatch3D
*/

static constexpr float kLarge = 1.0e20f;

LabelGlyphAtlas::LabelGlyphAtlas(QQuick3DObject *parent)
    : QQuick3DTextureData(parent)
{
    rebuildFont();
    resetAtlas();
    commit();
}

/*!
    \qmlproperty string LabelGlyphAtlas::fontFamily
    \brief Font family baked into the atlas. Changing it clears the atlas.
*/
void LabelGlyphAtlas::setFontFamily(const QString &family)
{
    if (m_family == family)
        return;
    m_family = family;
    rebuildFont();
    resetAtlas();
    commit();
    emit fontChanged();
    emit atlasChanged();
}

/*!
    \qmlproperty int LabelGlyphAtlas::fontWeight
    \brief Font weight (e.g. 400 normal, 700 bold). Changing it clears the atlas.
*/
void LabelGlyphAtlas::setFontWeight(int weight)
{
    if (m_weight == weight)
        return;
    m_weight = weight;
    rebuildFont();
    resetAtlas();
    commit();
    emit fontChanged();
    emit atlasChanged();
}

/*!
    \qmlproperty int LabelGlyphAtlas::baseSize
    \brief Rasterization size in pixels. Higher = crisper when magnified, larger
    atlas. Changing it clears the atlas.
*/
void LabelGlyphAtlas::setBaseSize(int px)
{
    px = qMax(8, px);
    if (m_baseSize == px)
        return;
    m_baseSize = px;
    rebuildFont();
    resetAtlas();
    commit();
    emit fontChanged();
    emit atlasChanged();
}

void LabelGlyphAtlas::rebuildFont()
{
    m_font = QFont();
    if (!m_family.isEmpty())
        m_font.setFamily(m_family);
    m_font.setWeight(QFont::Weight(m_weight));
    m_font.setPixelSize(m_baseSize);
    m_font.setHintingPreference(QFont::PreferNoHinting);
    m_fm = QFontMetricsF(m_font);
    m_ascent = m_fm.ascent();
    m_descent = m_fm.descent();
    m_capHeight = m_fm.capHeight();
    if (!(m_capHeight > 0.0))
        m_capHeight = m_ascent * 0.7;
}

void LabelGlyphAtlas::resetAtlas()
{
    m_atlasW = 512;
    m_atlasH = 256;
    m_pixels = QByteArray(static_cast<qsizetype>(m_atlasW) * m_atlasH, char(0));
    m_penX = 0;
    m_penY = 0;
    m_shelfH = 0;
    m_glyphs.clear();
    m_rects.clear();
    m_dirty = true;
}

// Felzenszwalb 1D squared-distance lower-envelope transform.
static void edt1d(const float *f, float *d, int *v, float *z, int n)
{
    int k = 0;
    v[0] = 0;
    z[0] = -kLarge;
    z[1] = kLarge;
    for (int q = 1; q < n; ++q) {
        float s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2.0f * (q - v[k]));
        while (s <= z[k]) {
            --k;
            s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2.0f * (q - v[k]));
        }
        ++k;
        v[k] = q;
        z[k] = s;
        z[k + 1] = kLarge;
    }
    k = 0;
    for (int q = 0; q < n; ++q) {
        while (z[k + 1] < q)
            ++k;
        const float dx = q - v[k];
        d[q] = dx * dx + f[v[k]];
    }
}

// 2D EDT in place over a w*h grid of squared seed values.
static void edt2d(float *grid, int w, int h)
{
    const int maxdim = qMax(w, h);
    QVector<float> f(maxdim), d(maxdim), z(maxdim + 1);
    QVector<int> v(maxdim);

    // Columns.
    for (int x = 0; x < w; ++x) {
        for (int y = 0; y < h; ++y)
            f[y] = grid[y * w + x];
        edt1d(f.constData(), d.data(), v.data(), z.data(), h);
        for (int y = 0; y < h; ++y)
            grid[y * w + x] = d[y];
    }
    // Rows.
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x)
            f[x] = grid[y * w + x];
        edt1d(f.constData(), d.data(), v.data(), z.data(), w);
        for (int x = 0; x < w; ++x)
            grid[y * w + x] = d[x];
    }
}

void LabelGlyphAtlas::growTo(int minHeight)
{
    int newH = m_atlasH;
    while (newH < minHeight)
        newH *= 2;
    if (newH == m_atlasH)
        return;
    QByteArray grown(static_cast<qsizetype>(m_atlasW) * newH, char(0));
    // Existing rows are top-aligned; copy them verbatim so texel coords stay
    // valid (UVs are renormalized by the new height on the next query).
    std::memcpy(grown.data(), m_pixels.constData(), m_pixels.size());
    m_pixels = grown;
    m_atlasH = newH;
}

void LabelGlyphAtlas::bakeGlyph(uint ucs4, GlyphInfo &gi)
{
    const QString s = QString::fromUcs4(reinterpret_cast<const char32_t *>(&ucs4), 1);
    const qreal advance = m_fm.horizontalAdvance(s);
    gi = GlyphInfo();
    gi.advance = static_cast<float>(advance);

    QRectF br = m_fm.boundingRect(s);
    const int inkW = static_cast<int>(std::ceil(br.width()));
    const int inkH = static_cast<int>(std::ceil(br.height()));
    if (inkW <= 0 || inkH <= 0) {
        // Non-inking glyph (space): record advance, emit no quad.
        gi.blank = true;
        m_glyphs.insert(ucs4, gi);
        m_rects.insert(ucs4, Rect{0, 0, 0, 0});
        return;
    }

    const int cellW = inkW + 2 * m_padding;
    const int cellH = inkH + 2 * m_padding;

    // Rasterize coverage: white glyph on transparent, ink box inset by padding.
    QImage img(cellW, cellH, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    {
        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setRenderHint(QPainter::TextAntialiasing, true);
        p.setFont(m_font);
        p.setPen(Qt::white);
        // drawText places the baseline origin; shift ink-left to padding and
        // ink-top (br.y() is negative above baseline) to padding.
        p.drawText(QPointF(m_padding - br.x(), m_padding - br.y()), s);
    }

    const int n = cellW * cellH;
    QVector<float> outer(n), inner(n);
    for (int i = 0; i < n; ++i) {
        const int y = i / cellW;
        const int x = i % cellW;
        const QRgb px = img.pixel(x, y);
        // Premultiplied white glyph: coverage is the alpha channel.
        const float cov = qAlpha(px) / 255.0f;
        if (cov >= 0.999f) {
            outer[i] = 0.0f;
            inner[i] = kLarge;
        } else if (cov <= 0.001f) {
            outer[i] = kLarge;
            inner[i] = 0.0f;
        } else {
            const float o = std::max(0.0f, 0.5f - cov);
            const float in = std::max(0.0f, cov - 0.5f);
            outer[i] = o * o;
            inner[i] = in * in;
        }
    }
    edt2d(outer.data(), cellW, cellH);
    edt2d(inner.data(), cellW, cellH);

    // Shelf-pack: new shelf if the cell overruns the row; grow height if needed.
    if (m_penX + cellW > m_atlasW) {
        m_penX = 0;
        m_penY += m_shelfH;
        m_shelfH = 0;
    }
    if (m_penY + cellH > m_atlasH)
        growTo(m_penY + cellH);

    const int tx = m_penX;
    const int ty = m_penY;
    const float radius = static_cast<float>(m_padding);
    for (int y = 0; y < cellH; ++y) {
        char *dstRow = m_pixels.data() + static_cast<qsizetype>(ty + y) * m_atlasW + tx;
        for (int x = 0; x < cellW; ++x) {
            const int i = y * cellW + x;
            const float d = std::sqrt(outer[i]) - std::sqrt(inner[i]); // >0 outside
            float val = 0.5f - d / (2.0f * radius);
            val = std::clamp(val, 0.0f, 1.0f);
            dstRow[x] = static_cast<char>(static_cast<unsigned char>(val * 255.0f + 0.5f));
        }
    }

    m_penX += cellW;
    m_shelfH = qMax(m_shelfH, cellH);

    // Label-local quad (base pixels, y-up), relative to this glyph's pen origin.
    gi.blank = false;
    gi.leftRel = static_cast<float>(br.x()) - m_padding;
    gi.offY = m_padding - static_cast<float>(br.y()) - cellH;
    gi.w = cellW;
    gi.h = cellH;
    m_glyphs.insert(ucs4, gi);
    m_rects.insert(ucs4, Rect{tx, ty, cellW, cellH});
    m_dirty = true;
}

void LabelGlyphAtlas::ensureString(const QString &text)
{
    bool grew = false;
    const QVector<uint> ucs = text.toUcs4();
    for (uint c : ucs) {
        if (!m_glyphs.contains(c)) {
            GlyphInfo gi;
            bakeGlyph(c, gi);
            grew = true;
        }
    }
    if (grew) {
        commit();
        emit atlasChanged();
    }
}

const LabelGlyphAtlas::GlyphInfo &LabelGlyphAtlas::glyph(uint ucs4)
{
    auto it = m_glyphs.find(ucs4);
    if (it == m_glyphs.end()) {
        GlyphInfo gi;
        bakeGlyph(ucs4, gi);
        commit();
        emit atlasChanged();
        it = m_glyphs.find(ucs4);
        if (it == m_glyphs.end())
            return m_missing;
    }
    // Recompute UV from the current atlas size so it survives growth.
    GlyphInfo &gi = it.value();
    const Rect r = m_rects.value(ucs4);
    if (!gi.blank && r.w > 0) {
        gi.u0 = static_cast<float>(r.x) / m_atlasW;
        gi.v0 = static_cast<float>(r.y) / m_atlasH;                 // top
        gi.u1 = static_cast<float>(r.x + r.w) / m_atlasW;
        gi.v1 = static_cast<float>(r.y + r.h) / m_atlasH;           // bottom
    }
    return gi;
}

void LabelGlyphAtlas::commit()
{
    setSize(QSize(m_atlasW, m_atlasH));
    setFormat(QQuick3DTextureData::R8);
    setHasTransparency(true);
    setTextureData(m_pixels);
    m_dirty = false;
}
