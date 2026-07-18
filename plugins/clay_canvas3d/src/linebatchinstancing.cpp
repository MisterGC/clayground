#include "linebatchinstancing.h"
#include <QColor>
#include <QVariantMap>
#include <cstring>
#include <limits>

/*!
    \qmltype LineBatchInstancing
    \nativetype LineBatchInstancing
    \inqmlmodule Clayground.Canvas3D
    \brief Per-line instance table for the batched LineBatch3D renderer.

    LineBatchInstancing turns a set of styled polylines into a single
    GPU instance table, one instance per line segment, over the unit-quad
    base mesh provided by LineBatchGeometry. Each 80-byte instance entry
    encodes an affine transform that maps the base quad's unit-x axis onto
    the segment (no quaternions, 12 floats per segment), plus the per-line
    color and a customData vector carrying width and a reserved styleId.

    The vertex shader reconstructs the segment endpoints as
    \c{P0 = INSTANCE_MODEL_MATRIX * vec4(0,0,0,1)} and
    \c{P1 = INSTANCE_MODEL_MATRIX * vec4(1,0,0,1)} and expands the quad
    into a camera-facing ribbon.

    This type is used internally by LineBatch3D.

    \sa LineBatch3D, LineBatchGeometry
*/

using Entry = QQuick3DInstancing::InstanceTableEntry;
static constexpr int kEntrySize = sizeof(Entry); // 80 bytes: 5 x vec4

LineBatchInstancing::LineBatchInstancing(QQuick3DObject *parent)
    : QQuick3DInstancing(parent)
{
}

/*!
    \qmlproperty list LineBatchInstancing::lines
    \brief Declarative list of styled polylines.

    Each element is an object of the form
    \c{{ points: [Qt.vector3d, ...], color: <color>, width: <real>, styleId: <int> }}.
    A polyline with N points produces N-1 line-segment instances that share
    the line's color, width and styleId.
*/
QVariantList LineBatchInstancing::lines() const
{
    QVariantList result;
    result.reserve(m_lines.size());
    for (const Line &line : m_lines) {
        QVariantMap m;
        QVariantList pts;
        pts.reserve(line.points.size());
        for (const QVector3D &p : line.points)
            pts.append(QVariant::fromValue(p));
        m.insert(QStringLiteral("points"), pts);
        m.insert(QStringLiteral("color"), QVariant::fromValue(
            QColor::fromRgbF(line.color.x(), line.color.y(), line.color.z(), line.color.w())));
        m.insert(QStringLiteral("width"), line.width);
        m.insert(QStringLiteral("styleId"), line.styleId);
        result.append(m);
    }
    return result;
}

void LineBatchInstancing::setLines(const QVariantList &lines)
{
    m_lines.clear();
    m_lines.reserve(lines.size());
    for (const QVariant &entry : lines) {
        const QVariantMap m = entry.toMap();
        Line line;

        const QVariantList pts = m.value(QStringLiteral("points")).toList();
        line.points.reserve(pts.size());
        for (const QVariant &pv : pts)
            line.points.append(pv.value<QVector3D>());

        const QColor c = m.value(QStringLiteral("color"), QColor(Qt::white)).value<QColor>();
        line.color = QVector4D(c.redF(), c.greenF(), c.blueF(), c.alphaF());
        line.width = m.value(QStringLiteral("width"), 1.0).toFloat();
        line.styleId = m.value(QStringLiteral("styleId"), 0).toInt();
        m_lines.append(line);
    }
    rebuild();
    emit linesChanged();
    emit countChanged();
}

/*!
    \qmlproperty int LineBatchInstancing::count
    \readonly
    \brief The number of lines (polylines) currently in the batch.
*/
int LineBatchInstancing::count() const
{
    return static_cast<int>(m_lines.size());
}

QVector3D LineBatchInstancing::boundsMin() const
{
    return m_boundsMin;
}

QVector3D LineBatchInstancing::boundsMax() const
{
    return m_boundsMax;
}

/*!
    \qmlmethod void LineBatchInstancing::setBulk(ByteArray positions, ByteArray startIndices, ByteArray colors, ByteArray widths, ByteArray styleIds)
    \brief Fast path for building the batch from packed binary buffers.

    \list
    \li \a positions - float32 xyz triples for every point of every line,
        concatenated.
    \li \a startIndices - uint32 offsets into the point array, one per line
        plus a trailing sentinel (length N+1, deck.gl convention); line i
        uses points \c{[startIndices[i], startIndices[i+1])}.
    \li \a colors - rgba8 (4 bytes) per line.
    \li \a widths - float32 per line.
    \li \a styleIds - optional uint16 style index per line, selecting a row of
        LineBatch3D::styles (dash pattern, cap, opacity). When omitted or empty
        every line uses styleId 0 (solid), so the four-argument call behaves
        exactly as before.
    \endlist
*/
void LineBatchInstancing::setBulk(const QByteArray &positions,
                                  const QByteArray &startIndices,
                                  const QByteArray &colors,
                                  const QByteArray &widths,
                                  const QByteArray &styleIds)
{
    m_lines.clear();

    const int numStarts = static_cast<int>(startIndices.size() / sizeof(quint32));
    if (numStarts < 2) {
        rebuild();
        emit linesChanged();
        emit countChanged();
        return;
    }

    const int numLines = numStarts - 1;
    const auto *starts = reinterpret_cast<const quint32 *>(startIndices.constData());
    const auto *pos = reinterpret_cast<const float *>(positions.constData());
    const int numPoints = static_cast<int>(positions.size() / (3 * sizeof(float)));
    const auto *col = reinterpret_cast<const quint8 *>(colors.constData());
    const int numColors = static_cast<int>(colors.size() / 4);
    const auto *wid = reinterpret_cast<const float *>(widths.constData());
    const int numWidths = static_cast<int>(widths.size() / sizeof(float));
    const auto *sid = reinterpret_cast<const quint16 *>(styleIds.constData());
    const int numStyleIds = static_cast<int>(styleIds.size() / sizeof(quint16));

    m_lines.reserve(numLines);
    for (int i = 0; i < numLines; ++i) {
        Line line;
        const quint32 begin = starts[i];
        const quint32 end = starts[i + 1];
        line.points.reserve(static_cast<int>(end - begin));
        for (quint32 p = begin; p < end && static_cast<int>(p) < numPoints; ++p) {
            line.points.append(QVector3D(pos[p * 3 + 0], pos[p * 3 + 1], pos[p * 3 + 2]));
        }

        if (i < numColors) {
            line.color = QVector4D(col[i * 4 + 0] / 255.0f,
                                   col[i * 4 + 1] / 255.0f,
                                   col[i * 4 + 2] / 255.0f,
                                   col[i * 4 + 3] / 255.0f);
        } else {
            line.color = QVector4D(1.0f, 1.0f, 1.0f, 1.0f);
        }
        line.width = (i < numWidths) ? wid[i] : 1.0f;
        line.styleId = (i < numStyleIds) ? static_cast<int>(sid[i]) : 0;
        m_lines.append(line);
    }

    rebuild();
    emit linesChanged();
    emit countChanged();
}

/*!
    \qmlmethod void LineBatchInstancing::updateLinePoints(int lineIndex, list points)
    \brief Patches only the given line's instance-table region and re-uploads.

    Rewrites line \a lineIndex from \a points. When the new point count keeps
    the same number of segments, only that line's entries are rewritten in
    place (no rebuild of other lines). If the segment count changes, the whole
    table is rebuilt.
*/
void LineBatchInstancing::updateLinePoints(int lineIndex, const QVariantList &points)
{
    if (lineIndex < 0 || lineIndex >= m_lines.size())
        return;

    Line &line = m_lines[lineIndex];
    QList<QVector3D> newPoints;
    newPoints.reserve(points.size());
    for (const QVariant &pv : points)
        newPoints.append(pv.value<QVector3D>());

    const int newSegments = newPoints.size() > 1 ? newPoints.size() - 1 : 0;
    line.points = newPoints;

    if (newSegments != line.instanceCount) {
        // Segment count changed: full rebuild (offsets of later lines shift).
        rebuild();
        return;
    }

    // In-place patch of just this line's region.
    if (line.instanceCount > 0 && !m_data.isEmpty()) {
        char *dst = m_data.data() + static_cast<qsizetype>(line.instanceStart) * kEntrySize;
        writeLineEntries(dst, line);
    }
    updateBounds();
    markDirty();
}

void LineBatchInstancing::writeLineEntries(char *dst, const Line &line) const
{
    const int segments = line.points.size() > 1 ? line.points.size() - 1 : 0;
    // Accumulated path distance at each segment start, packed into
    // INSTANCE_DATA.z so the fragment shader can flow a dash pattern
    // continuously across the segments of one polyline.
    float pathDist = 0.0f;
    for (int s = 0; s < segments; ++s) {
        const QVector3D &p0 = line.points[s];
        const QVector3D &p1 = line.points[s + 1];

        // Cap flags packed into INSTANCE_DATA.w (bit0 = draw start cap,
        // bit1 = draw end cap). Only the polyline's first segment draws a
        // start cap (its free start end); every segment draws an end cap.
        // The end cap doubles as the round joint filler for the next segment,
        // so interior joints stay round and gap-free with a single cap instead
        // of the two overlapping caps the old scheme drew. A single-segment
        // line (segments == 1, s == 0) therefore gets both caps (flags == 3).
        const int capFlags = (s == 0 ? 1 : 0) | 2;

        // Affine transform mapping base-space (0,0,0)->P0 and (1,0,0)->P1.
        // Columns 1 and 2 are zero; translation is P0. Stored row-major as
        // three vec4 rows (row.xyz = matrix row, row.w = translation).
        Entry e;
        e.row0 = QVector4D(p1.x() - p0.x(), 0.0f, 0.0f, p0.x());
        e.row1 = QVector4D(p1.y() - p0.y(), 0.0f, 0.0f, p0.y());
        e.row2 = QVector4D(p1.z() - p0.z(), 0.0f, 0.0f, p0.z());
        e.color = line.color;
        e.instanceData = QVector4D(line.width, static_cast<float>(line.styleId),
                                   pathDist, static_cast<float>(capFlags));

        std::memcpy(dst + static_cast<qsizetype>(s) * kEntrySize, &e, kEntrySize);
        pathDist += (p1 - p0).length();
    }
}

/*!
    \qmlmethod void LineBatchInstancing::updateEndpointsBulk(ByteArray positions)
    \brief Rewrites the endpoints of every single-segment line in one pass.

    \a positions is a packed float32 buffer with 6 floats per line
    (\c{p0.xyz, p1.xyz}) in line order. This is the fast per-frame path used by
    ConnectorLayer3D: it patches only the affected instance entries in place,
    recomputes the batch bounds once and triggers a single instance-table
    upload. Lines that do not have exactly one segment are skipped.
*/
void LineBatchInstancing::updateEndpointsBulk(const QByteArray &positions)
{
    if (m_data.isEmpty() || m_lines.isEmpty())
        return;

    const int floatsPerLine = 6;
    const auto *pos = reinterpret_cast<const float *>(positions.constData());
    const int available = static_cast<int>(positions.size() / (floatsPerLine * sizeof(float)));
    const int n = qMin(available, static_cast<int>(m_lines.size()));

    char *base = m_data.data();
    for (int i = 0; i < n; ++i) {
        Line &line = m_lines[i];
        if (line.instanceCount != 1 || line.points.size() != 2)
            continue;

        const float *src = pos + static_cast<qsizetype>(i) * floatsPerLine;
        line.points[0] = QVector3D(src[0], src[1], src[2]);
        line.points[1] = QVector3D(src[3], src[4], src[5]);
        writeLineEntries(base + static_cast<qsizetype>(line.instanceStart) * kEntrySize, line);
    }

    updateBounds();
    markDirty();
}

void LineBatchInstancing::rebuild()
{
    // Assign instance ranges and total segment count.
    m_instanceCount = 0;
    for (Line &line : m_lines) {
        line.instanceStart = m_instanceCount;
        line.instanceCount = line.points.size() > 1 ? line.points.size() - 1 : 0;
        m_instanceCount += line.instanceCount;
    }

    m_data.resize(static_cast<qsizetype>(m_instanceCount) * kEntrySize);
    char *base = m_data.data();
    for (const Line &line : m_lines) {
        if (line.instanceCount > 0)
            writeLineEntries(base + static_cast<qsizetype>(line.instanceStart) * kEntrySize, line);
    }

    updateBounds();
    m_dirty = false;
    markDirty();
}

void LineBatchInstancing::updateBounds()
{
    if (m_lines.isEmpty()) {
        m_boundsMin = QVector3D(0.0f, 0.0f, 0.0f);
        m_boundsMax = QVector3D(0.0f, 0.0f, 0.0f);
        emit boundsChanged();
        return;
    }

    float maxF = std::numeric_limits<float>::max();
    QVector3D mn(maxF, maxF, maxF);
    QVector3D mx(-maxF, -maxF, -maxF);
    float maxWidth = 0.0f;

    for (const Line &line : m_lines) {
        maxWidth = qMax(maxWidth, line.width);
        for (const QVector3D &p : line.points) {
            mn.setX(qMin(mn.x(), p.x()));
            mn.setY(qMin(mn.y(), p.y()));
            mn.setZ(qMin(mn.z(), p.z()));
            mx.setX(qMax(mx.x(), p.x()));
            mx.setY(qMax(mx.y(), p.y()));
            mx.setZ(qMax(mx.z(), p.z()));
        }
    }

    // Expand by a margin so ribbon/cap expansion never falls outside the
    // culling bounds. Width is a loose upper bound for the world-space growth.
    const QVector3D margin(maxWidth, maxWidth, maxWidth);
    m_boundsMin = mn - margin;
    m_boundsMax = mx + margin;
    emit boundsChanged();
}

QByteArray LineBatchInstancing::getInstanceBuffer(int *instanceCount)
{
    if (m_dirty)
        rebuild();
    if (instanceCount)
        *instanceCount = m_instanceCount;
    return m_data;
}
