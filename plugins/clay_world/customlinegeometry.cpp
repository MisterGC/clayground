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
    QByteArray vertexData;
    QByteArray indexData;
    int vertexCount = 0;

    // Generate geometry for each line segment
    for (int i = 0; i < m_vertices.size() - 1; ++i) {
        QVector3D start = m_vertices[i];
        QVector3D end = m_vertices[i + 1];

        // Generate 4 vertices for each line segment (forming a quad)
        QVector3D vertices[4] = {
            start,
            start,
            end,
            end
        };

        // Add vertices to the buffer
        for (int j = 0; j < 4; ++j) {
            vertexData.append(reinterpret_cast<const char*>(&vertices[j]), sizeof(QVector3D));
        }

        // Define indices for two triangles forming the quad
        int indices[6] = {
            vertexCount, vertexCount + 1, vertexCount + 2,
            vertexCount + 1, vertexCount + 3, vertexCount + 2
        };

        // Add indices to the buffer
        for (int idx : indices) {
            indexData.append(reinterpret_cast<const char*>(&idx), sizeof(int));
        }

        vertexCount += 4;
    }

    setVertexData(vertexData);
    setIndexData(indexData);
    setStride(sizeof(QVector3D));
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);

    // Set up attribute information for vertices
    QVector3D extents = calculateExtents();
    setBounds(extents, -extents);  // Set bounding volume

    // Add position attribute
    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic,
                 0,
                 QQuick3DGeometry::Attribute::F32Type);

    // Add index attribute
    addAttribute(QQuick3DGeometry::Attribute::IndexSemantic,
                 0,
                 QQuick3DGeometry::Attribute::U32Type);

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