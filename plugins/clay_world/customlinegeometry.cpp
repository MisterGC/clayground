#include "customlinegeometry.h"

CustomLineGeometry::CustomLineGeometry()
{
}

QVector<QVector3D> CustomLineGeometry::vertices() const
{
    return m_vertices;
}

void CustomLineGeometry::setVertices(const QVector<QVector3D> &newVertices)
{
    if (m_vertices == newVertices)
        return;
    m_vertices = newVertices;
    emit verticesChanged();
    updateData();
}

void CustomLineGeometry::updateData()
{
    QByteArray vertexBuffer;
    QByteArray indexBuffer;
    int vertexCount = 0;

    // Iterate over vertices and create the line geometry
    for (int i = 0; i < m_vertices.size() - 1; ++i) {
        QVector3D start = m_vertices[i];
        QVector3D end = m_vertices[i + 1];

        // Define the 4 corners of the line segment
        for (int j = 0; j < 4; ++j) {
            QVector3D pos = (j < 2) ? start : end;
            float side = (j % 2 == 0) ? -1.0f : 1.0f;
            side = side * (j<2 ? 1.0 : -1.0);  // Use -1.0 for the first two vertices and 1.0 for the last two vertices

            // Determine the other end of the line segment
            QVector3D otherEnd = (j < 2) ? end : start;  // Use `end` if `pos` is `start`, and `start` if `pos` is `end`

            // Add position
            vertexBuffer.append(reinterpret_cast<const char*>(&pos), sizeof(QVector3D));

            // Add side information and the correct other end position in the color buffer
            QVector4D colorInfo(side, otherEnd.x(), otherEnd.y(), otherEnd.z());
            vertexBuffer.append(reinterpret_cast<const char*>(&colorInfo), sizeof(QVector4D));
        }

        // Define indices for the two triangles forming the line segment
        static const int indices[] = {
            0, 1, 2,
            1, 3, 2
        };

        // Add indices to the buffer
        for (int idx : indices) {
            int globalIdx = vertexCount + idx;
            indexBuffer.append(reinterpret_cast<const char*>(&globalIdx), sizeof(uint32_t));
        }

        vertexCount += 4;
    }

    // Set the vertex and index data
    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);

    // Set up attribute information for vertices
    QVector3D extents = calculateExtents();
    setBounds(extents, -extents);  // Set bounding volume

    // Stride is now 7 floats: 3 for position, 4 for color info
    setStride(7 * sizeof(float));

    // Add position attribute
    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic,
                 0,
                 QQuick3DGeometry::Attribute::F32Type);

    // Add color attribute (contains side and other end position)
    addAttribute(QQuick3DGeometry::Attribute::ColorSemantic,
                 3 * sizeof(float),
                 QQuick3DGeometry::Attribute::F32Type);

    // Add index attribute
    addAttribute(QQuick3DGeometry::Attribute::IndexSemantic,
                 0,
                 QQuick3DGeometry::Attribute::U32Type);

    // Set primitive type to triangles
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);

    // Update the geometry
    update();
}

// Add this new method to calculate extents
QVector3D CustomLineGeometry::calculateExtents() const
{
    if (m_vertices.isEmpty())
        return QVector3D();

    QVector3D min = m_vertices.first();
    QVector3D max = m_vertices.first();

    for (const QVector3D& v : m_vertices) {
        min.setX(qMin(min.x(), v.x()));
        min.setY(qMin(min.y(), v.y()));
        min.setZ(qMin(min.z(), v.z()));
        max.setX(qMax(max.x(), v.x()));
        max.setY(qMax(max.y(), v.y()));
        max.setZ(qMax(max.z(), v.z()));
    }

    return (max - min) * 0.5f;
}
