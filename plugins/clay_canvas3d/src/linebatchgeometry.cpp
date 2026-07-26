#include "linebatchgeometry.h"

/*!
    \qmltype LineBatchGeometry
    \nativetype LineBatchGeometry
    \inqmlmodule Clayground.Canvas3D
    \brief Base quad geometry for the instanced LineBatch3D renderer.

    LineBatchGeometry provides the static per-instance base mesh used by
    LineBatch3D: a single unit quad whose vertices carry a segment
    parameter \c t (0 at the start, 1 at the end of a segment) and a
    \c side factor (-1 or +1) in the x/y channels of the position
    attribute. The vertex shader expands this quad into a camera-facing
    ribbon per line segment.

    The quad itself never changes, but its bounds are updated to cover the
    whole batch extent (via \l boundsMin / \l boundsMax) so that frustum
    culling and picking use the real world-space extent of the instanced
    lines rather than the tiny unit quad.

    This type is used internally by LineBatch3D and normally does not need
    to be instantiated directly.

    \sa LineBatch3D, LineBatchInstancing
*/
LineBatchGeometry::LineBatchGeometry()
    : m_boundsMin(0.0f, -1.0f, 0.0f)
    , m_boundsMax(1.0f, 1.0f, 0.0f)
{
    rebuild();
}

/*!
    \qmlproperty vector3d LineBatchGeometry::boundsMin
    \brief Minimum corner of the axis-aligned bounding box covering all lines.

    Set this to the minimum of all line endpoints so that instanced frustum
    culling keeps the batch visible.
*/
QVector3D LineBatchGeometry::boundsMin() const
{
    return m_boundsMin;
}

void LineBatchGeometry::setBoundsMin(const QVector3D &v)
{
    if (m_boundsMin == v)
        return;
    m_boundsMin = v;
    emit boundsMinChanged();
    setBounds(m_boundsMin, m_boundsMax);
    update();
}

/*!
    \qmlproperty vector3d LineBatchGeometry::boundsMax
    \brief Maximum corner of the axis-aligned bounding box covering all lines.

    Set this to the maximum of all line endpoints so that instanced frustum
    culling keeps the batch visible.
*/
QVector3D LineBatchGeometry::boundsMax() const
{
    return m_boundsMax;
}

void LineBatchGeometry::setBoundsMax(const QVector3D &v)
{
    if (m_boundsMax == v)
        return;
    m_boundsMax = v;
    emit boundsMaxChanged();
    setBounds(m_boundsMin, m_boundsMax);
    update();
}

void LineBatchGeometry::rebuild()
{
    // Unit quad: x carries the segment parameter t (0 = start, 1 = end),
    // y carries the side factor (-1 or +1). z is unused (kept at 0).
    //   v0 (t=0, side=-1)   v2 (t=1, side=-1)
    //   v1 (t=0, side=+1)   v3 (t=1, side=+1)
    static const float verts[] = {
        0.0f, -1.0f, 0.0f,
        0.0f,  1.0f, 0.0f,
        1.0f, -1.0f, 0.0f,
        1.0f,  1.0f, 0.0f
    };

    static const uint32_t indices[] = {
        0, 2, 1,
        1, 2, 3
    };

    QByteArray vertexBuffer(reinterpret_cast<const char *>(verts), sizeof(verts));
    QByteArray indexBuffer(reinterpret_cast<const char *>(indices), sizeof(indices));

    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);
    setStride(3 * sizeof(float));

    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic,
                 0,
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::IndexSemantic,
                 0,
                 QQuick3DGeometry::Attribute::U32Type);

    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
    setBounds(m_boundsMin, m_boundsMax);
    update();
}
