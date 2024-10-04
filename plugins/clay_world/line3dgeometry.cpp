#include "line3dgeometry.h"
#include <QVector3D>
#include <QQuaternion>

Line3dGeometry::Line3dGeometry()
    : m_color(Qt::white), m_width(1.0f)
{
}

QVector<QVector3D> Line3dGeometry::vertices() const
{
    return m_vertices;
}

void Line3dGeometry::setVertices(const QVector<QVector3D>& vertices)
{
    if (m_vertices != vertices) {
        m_vertices = vertices;
        emit verticesChanged();
        updateGeometry();
    }
}

QColor Line3dGeometry::color() const
{
    return m_color;
}

void Line3dGeometry::setColor(const QColor& color)
{
    if (m_color != color) {
        m_color = color;
        emit colorChanged();
        updateGeometry();
    }
}

float Line3dGeometry::width() const
{
    return m_width;
}

void Line3dGeometry::setWidth(float width)
{
    if (!qFuzzyCompare(m_width, width)) {
        m_width = width;
        emit widthChanged();
        updateGeometry();
    }
}

QVector3D Line3dGeometry::calculateExtents() const
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

    // Add a small padding for the line width
    QVector3D padding(m_width, m_width, m_width);
    min -= padding * 0.5f;
    max += padding * 0.5f;

    return (max - min) * 0.5f;
}

void Line3dGeometry::updateGeometry()
{
    clear();
    if (m_vertices.size() < 2) return;
    QByteArray vertexBuffer;
    QByteArray indexBuffer;
    int vertexCount = 0;

    // Iterate over vertices and create the box-shaped line geometry
    for (int i = 0; i < m_vertices.size() - 1; ++i) {
        QVector3D start = m_vertices[i];
        QVector3D end = m_vertices[i + 1];
        QVector3D direction = (end - start).normalized();
        QVector3D up = QVector3D(0, 1, 0);
        QVector3D right = QVector3D::crossProduct(direction, up).normalized();
        if (right.isNull()) {
            right = QVector3D::crossProduct(direction, QVector3D(1, 0, 0)).normalized();
        }
        up = QVector3D::crossProduct(right, direction).normalized();

        float halfWidth = m_width * 0.5f;

        // Define the 8 corners of the box
        QVector3D corners[8] = {
            start + (up + right) * halfWidth,
            start + (up - right) * halfWidth,
            start + (-up - right) * halfWidth,
            start + (-up + right) * halfWidth,
            end + (up + right) * halfWidth,
            end + (up - right) * halfWidth,
            end + (-up - right) * halfWidth,
            end + (-up + right) * halfWidth
        };

        // Add vertices to the buffer
        for (int j = 0; j < 8; ++j) {
            vertexBuffer.append(reinterpret_cast<const char*>(&corners[j]), sizeof(QVector3D));
        }

        // Define indices for the box faces
        static const int indices[] = {
            0, 1, 2, 0, 2, 3, // Start face
            4, 5, 6, 4, 6, 7, // End face
            0, 4, 1, 1, 4, 5, // Top face
            2, 6, 3, 3, 6, 7, // Bottom face
            0, 3, 4, 3, 4, 7, // Right face
            1, 5, 2, 2, 5, 6  // Left face
        };

        // Add indices to the buffer
        for (int idx : indices) {
            int globalIdx = vertexCount + idx;
            indexBuffer.append(reinterpret_cast<const char*>(&globalIdx), sizeof(uint32_t));
        }

        vertexCount += 8;
    }

    // Set the vertex and index data
    setVertexData(vertexBuffer);
    setIndexData(indexBuffer);

    // Set up attribute information for vertices
    QVector3D extents = calculateExtents();
    setBounds(extents, -extents);  // Set bounding volume

    // Stride is the size of each vertex, here 3 floats for position (x, y, z)
    setStride(3 * sizeof(float));

    // Add position attribute
    using Attr = QQuick3DGeometry::Attribute;
    addAttribute(Attr::PositionSemantic, 0, Attr::F32Type);

    // Add index attribute
    addAttribute(Attr::IndexSemantic, 0, Attr::U32Type);

    // Set primitive type to triangles
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);

    // Update the geometry
    update();
}