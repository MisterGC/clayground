#include "customlinegeometry.h"

CustomLineGeometry::CustomLineGeometry()
{
}

QVector<QVector<QVector3D>> CustomLineGeometry::lines() const
{
    return m_lines;
}

void CustomLineGeometry::setLines(const QVector<QVector<QVector3D>> &newLines)
{
    if (m_lines == newLines)
        return;
    m_lines = newLines;
    emit linesChanged();
    updateData();
}

void CustomLineGeometry::updateData()
{
    QByteArray vertexBuffer;
    QByteArray indexBuffer;
    int vertexCount = 0;

    // Iterate over each line
    for (const auto& line : m_lines) {
        // Iterate over vertices of each line and create the line geometry
        for (int i = 0; i < line.size() - 1; ++i) {
            QVector3D start = line[i];
            QVector3D end = line[i + 1];

            // Define the 4 corners of the line segment
            for (int j = 0; j < 4; ++j) {
                QVector3D pos = (j < 2) ? start : end;
                float side = (j % 2 == 0) ? -1.0f : 1.0f;
                side = side * (j<2 ? 1.0 : -1.0);

                QVector3D otherEnd = (j < 2) ? end : start;

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
    }

    // Set the vertex and index data
    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);

    // Set up attribute information for vertices
    QVector3D extents = calculateExtents();
    setBounds(extents, -extents);

    setStride(7 * sizeof(float));

    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic,
                 0,
                 QQuick3DGeometry::Attribute::F32Type);

    addAttribute(QQuick3DGeometry::Attribute::ColorSemantic,
                 3 * sizeof(float),
                 QQuick3DGeometry::Attribute::F32Type);

    addAttribute(QQuick3DGeometry::Attribute::IndexSemantic,
                 0,
                 QQuick3DGeometry::Attribute::U32Type);

    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);

    update();
}

QVector3D CustomLineGeometry::calculateExtents() const
{
    if (m_lines.isEmpty() || m_lines[0].isEmpty())
        return QVector3D();

    QVector3D min = m_lines[0][0];
    QVector3D max = m_lines[0][0];

    for (const auto& line : m_lines) {
        for (const QVector3D& v : line) {
            min.setX(qMin(min.x(), v.x()));
            min.setY(qMin(min.y(), v.y()));
            min.setZ(qMin(min.z(), v.z()));
            max.setX(qMax(max.x(), v.x()));
            max.setY(qMax(max.y(), v.y()));
            max.setZ(qMax(max.z(), v.z()));
        }
    }

    return (max - min) * 0.5f;
}
