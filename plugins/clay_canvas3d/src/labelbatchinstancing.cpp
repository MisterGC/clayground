// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "labelbatchinstancing.h"

#include <QColor>
#include <QVariantMap>
#include <QElapsedTimer>
#include <cstring>
#include <limits>

/*!
    \qmltype LabelBatchInstancing
    \nativetype LabelBatchInstancing
    \inqmlmodule Clayground.Canvas3D
    \brief Per-glyph instance table for the batched LabelBatch3D renderer.

    LabelBatchInstancing shapes each label into a run of glyph quads (single
    line, QFontMetricsF advances) against a shared \l LabelGlyphAtlas and packs
    them into one GPU instance table, one instance per inking glyph. It also
    builds a per-label pill-background table (consumed by LabelPillInstancing).

    The 80-byte instance layout is frozen; see the header for the field map.

    This type is used internally by LabelBatch3D.

    \sa LabelBatch3D, LabelGlyphAtlas, LabelPillInstancing
*/

using Entry = QQuick3DInstancing::InstanceTableEntry;
static constexpr int kEntrySize = sizeof(Entry); // 80 bytes: 5 x vec4

LabelBatchInstancing::LabelBatchInstancing(QQuick3DObject *parent)
    : QQuick3DInstancing(parent)
{
}

void LabelBatchInstancing::setAtlas(LabelGlyphAtlas *atlas)
{
    if (m_atlas == atlas)
        return;
    m_atlas = atlas;
    emit atlasChanged();
    reshape();
}

void LabelBatchInstancing::setPillPadding(qreal p)
{
    if (qFuzzyCompare(m_pillPadding, p))
        return;
    m_pillPadding = p;
    emit pillPaddingChanged();
    reshape();
}

/*!
    \qmlproperty list LabelBatchInstancing::labels
    \brief Declarative list of labels to render.

    Each element is an object
    \c{{ position: Qt.vector3d, text: <string>, color: <color>, size: <real>,
    priority: <int>, opacity: <real> }}. Only \c position and \c text are
    required.
*/
QVariantList LabelBatchInstancing::labels() const
{
    QVariantList out;
    out.reserve(m_labels.size());
    for (const Label &l : m_labels) {
        QVariantMap m;
        m.insert(QStringLiteral("position"), QVariant::fromValue(l.position));
        m.insert(QStringLiteral("text"), l.text);
        m.insert(QStringLiteral("color"), QVariant::fromValue(
            QColor::fromRgbF(l.color.x(), l.color.y(), l.color.z(), l.color.w())));
        m.insert(QStringLiteral("size"), l.size);
        m.insert(QStringLiteral("priority"), l.priority);
        m.insert(QStringLiteral("opacity"), l.opacity);
        out.append(m);
    }
    return out;
}

void LabelBatchInstancing::setLabels(const QVariantList &labels)
{
    m_labels.clear();
    m_labels.reserve(labels.size());
    for (const QVariant &entry : labels) {
        const QVariantMap m = entry.toMap();
        Label l;
        l.position = m.value(QStringLiteral("position")).value<QVector3D>();
        l.text = m.value(QStringLiteral("text")).toString();
        const QColor c = m.value(QStringLiteral("color"), QColor(Qt::white)).value<QColor>();
        l.color = QVector4D(c.redF(), c.greenF(), c.blueF(), c.alphaF());
        l.size = m.value(QStringLiteral("size"), 24.0).toFloat();
        l.opacity = m.value(QStringLiteral("opacity"), 1.0).toFloat();
        l.priority = m.value(QStringLiteral("priority"), 0).toInt();
        m_labels.append(l);
    }
    reshape();
    emit labelsChanged();
}

QVariantList LabelBatchInstancing::priorities() const
{
    QVariantList out;
    out.reserve(m_labels.size());
    for (const Label &l : m_labels)
        out.append(l.priority);
    return out;
}

void LabelBatchInstancing::reshape()
{
    if (!m_atlas) {
        m_glyphData.clear();
        m_pillData.clear();
        m_glyphCount = 0;
        m_dirty = true;
        markDirty();
        emit pillDataChanged();
        return;
    }

    QElapsedTimer timer;
    timer.start();

    // Pass 1: bake every glyph so the atlas cannot grow during instance build
    // (growth renormalizes UVs of glyphs baked earlier in the same pass).
    for (const Label &l : m_labels)
        m_atlas->ensureString(l.text);

    const float base = m_atlas->baseSizeF();
    const float vShift = -0.5f * m_atlas->capHeight();
    const float pad = static_cast<float>(m_pillPadding);

    // Count inking glyphs.
    int total = 0;
    for (const Label &l : m_labels) {
        const QVector<uint> ucs = l.text.toUcs4();
        for (uint ch : ucs)
            if (!m_atlas->glyph(ch).blank)
                ++total;
    }
    m_glyphCount = total;
    m_glyphData.resize(static_cast<qsizetype>(total) * kEntrySize);
    m_pillData.resize(static_cast<qsizetype>(m_labels.size()) * kEntrySize);

    float maxF = std::numeric_limits<float>::max();
    QVector3D bmin(maxF, maxF, maxF), bmax(-maxF, -maxF, -maxF);
    float maxWorldExtent = 0.0f;

    char *gdst = m_glyphData.data();
    char *pdst = m_pillData.data();
    int gi = 0;
    for (int li = 0; li < m_labels.size(); ++li) {
        Label &l = m_labels[li];
        const QVector<uint> ucs = l.text.toUcs4();

        float totalAdvance = 0.0f;
        for (uint ch : ucs)
            totalAdvance += m_atlas->glyph(ch).advance;

        l.glyphStart = gi;
        float penX = -0.5f * totalAdvance;
        float lminX = 1e9f, lmaxX = -1e9f, lminY = 1e9f, lmaxY = -1e9f;

        for (uint ch : ucs) {
            const LabelGlyphAtlas::GlyphInfo &info = m_atlas->glyph(ch);
            if (!info.blank) {
                const float offX = penX + info.leftRel;
                const float offY = info.offY + vShift;

                Entry e;
                // col0 = (offX, offY, size); col1 = (u0,v0,u1); col2 = (v1,w,h)
                e.row0 = QVector4D(offX, info.u0, info.v1, l.position.x());
                e.row1 = QVector4D(offY, info.v0, info.w, l.position.y());
                e.row2 = QVector4D(l.size, info.u1, info.h, l.position.z());
                e.color = l.color;
                e.instanceData = QVector4D(0.0f, l.opacity, 0.0f, 0.0f);
                std::memcpy(gdst + static_cast<qsizetype>(gi) * kEntrySize, &e, kEntrySize);
                ++gi;

                lminX = qMin(lminX, offX);
                lmaxX = qMax(lmaxX, offX + info.w);
                lminY = qMin(lminY, offY);
                lmaxY = qMax(lmaxY, offY + info.h);
            }
            penX += info.advance;
        }
        l.glyphCount = gi - l.glyphStart;

        // Pill box: union of glyph quads plus padding (fallback to a metrics
        // box for a label whose glyphs were all blank).
        if (lmaxX < lminX) {
            lminX = -0.5f * totalAdvance;
            lmaxX = 0.5f * totalAdvance;
            lminY = vShift - m_atlas->descent();
            lmaxY = vShift + m_atlas->ascent();
        }
        const float pcx = 0.5f * (lminX + lmaxX);
        const float pcy = 0.5f * (lminY + lmaxY);
        const float pw = (lmaxX - lminX) + 2.0f * pad;
        const float ph = (lmaxY - lminY) + 2.0f * pad;
        Entry pe;
        pe.row0 = QVector4D(pcx, 0.0f, 0.0f, l.position.x());
        pe.row1 = QVector4D(pcy, 0.0f, pw, l.position.y());
        pe.row2 = QVector4D(l.size, 0.0f, ph, l.position.z());
        pe.color = QVector4D(1.0f, 1.0f, 1.0f, l.opacity);
        pe.instanceData = QVector4D(pw, ph, 0.0f, 0.0f);
        std::memcpy(pdst + static_cast<qsizetype>(li) * kEntrySize, &pe, kEntrySize);

        // Bounds: anchor AABB; margin below accounts for the quad spread.
        bmin.setX(qMin(bmin.x(), l.position.x()));
        bmin.setY(qMin(bmin.y(), l.position.y()));
        bmin.setZ(qMin(bmin.z(), l.position.z()));
        bmax.setX(qMax(bmax.x(), l.position.x()));
        bmax.setY(qMax(bmax.y(), l.position.y()));
        bmax.setZ(qMax(bmax.z(), l.position.z()));
        const float worldExtent = qMax(pw, ph) * l.size / qMax(base, 1.0f);
        maxWorldExtent = qMax(maxWorldExtent, worldExtent);
    }

    if (m_labels.isEmpty()) {
        bmin = QVector3D(0, 0, 0);
        bmax = QVector3D(0, 0, 0);
    } else {
        const QVector3D margin(maxWorldExtent, maxWorldExtent, maxWorldExtent);
        bmin -= margin;
        bmax += margin;
    }
    m_boundsMin = bmin;
    m_boundsMax = bmax;

    m_shapeMsLast = timer.nsecsElapsed() / 1.0e6;
    m_dirty = true;
    markDirty();
    emit boundsChanged();
    emit pillDataChanged();
}

void LabelBatchInstancing::writeAnchor(char *entry, const QVector3D &p) const
{
    // Anchor is the translation column: row0.w, row1.w, row2.w (floats 3,7,11).
    auto *f = reinterpret_cast<float *>(entry);
    f[3] = p.x();
    f[7] = p.y();
    f[11] = p.z();
}

/*!
    \qmlmethod void LabelBatchInstancing::updatePositionsBulk(ByteArray positions, int first)
    \brief Moves labels without re-shaping.

    \a positions is packed float32 \c{[x, y, z]} per label, applied to labels
    starting at index \a first. Rewrites the anchor of every glyph of those
    labels and their pill instance, then triggers a single upload.
*/
void LabelBatchInstancing::updatePositionsBulk(const QByteArray &positions, int first)
{
    if (first < 0 || m_glyphData.isEmpty())
        return;
    const int stride = 3;
    const auto *src = reinterpret_cast<const float *>(positions.constData());
    const int available = static_cast<int>(positions.size() / (stride * sizeof(float)));
    const int last = qMin(first + available, static_cast<int>(m_labels.size()));

    char *gbase = m_glyphData.data();
    char *pbase = m_pillData.data();
    for (int li = first; li < last; ++li) {
        const float *p = src + static_cast<qsizetype>(li - first) * stride;
        const QVector3D pos(p[0], p[1], p[2]);
        Label &l = m_labels[li];
        l.position = pos;
        for (int g = 0; g < l.glyphCount; ++g)
            writeAnchor(gbase + static_cast<qsizetype>(l.glyphStart + g) * kEntrySize, pos);
        writeAnchor(pbase + static_cast<qsizetype>(li) * kEntrySize, pos);
    }
    m_dirty = true;
    markDirty();
    emit pillDataChanged();
}

QByteArray LabelBatchInstancing::getInstanceBuffer(int *instanceCount)
{
    m_dirty = false;
    if (instanceCount)
        *instanceCount = m_glyphCount;
    return m_glyphData;
}

// ---------------------------------------------------------------------------

/*!
    \qmltype LabelPillInstancing
    \nativetype LabelPillInstancing
    \inqmlmodule Clayground.Canvas3D
    \brief Per-label pill-background instance table for LabelBatch3D.

    LabelPillInstancing forwards the pill table built by a \l source
    LabelBatchInstancing, one instance per label, re-uploading whenever the
    source reshapes. Used internally by LabelBatch3D for the pill draw.

    \sa LabelBatch3D, LabelBatchInstancing
*/
LabelPillInstancing::LabelPillInstancing(QQuick3DObject *parent)
    : QQuick3DInstancing(parent)
{
}

void LabelPillInstancing::setSource(LabelBatchInstancing *source)
{
    if (m_source == source)
        return;
    if (m_source)
        disconnect(m_source, nullptr, this, nullptr);
    m_source = source;
    if (m_source) {
        connect(m_source, &LabelBatchInstancing::pillDataChanged,
                this, [this]() { markDirty(); });
    }
    emit sourceChanged();
    markDirty();
}

QByteArray LabelPillInstancing::getInstanceBuffer(int *instanceCount)
{
    if (!m_source) {
        if (instanceCount)
            *instanceCount = 0;
        return QByteArray();
    }
    if (instanceCount)
        *instanceCount = m_source->pillCount();
    return m_source->pillData();
}
