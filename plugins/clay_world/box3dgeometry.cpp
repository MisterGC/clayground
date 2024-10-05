#include "box3dgeometry.h"

Box3dGeometry::Box3dGeometry() : m_size(1, 1, 1)
{
    updateData();
}

QVector3D Box3dGeometry::size() const
{
    return m_size;
}

void Box3dGeometry::setSize(const QVector3D &newSize)
{
    if (m_size == newSize)
        return;
    m_size = newSize;
    emit sizeChanged();
    updateData();
}

void Box3dGeometry::updateData()
{
    // Define the 8 vertices of the box
    QVector3D v0(-m_size.x() / 2, -m_size.y() / 2, -m_size.z() / 2); // Bottom-Back-Left
    QVector3D v1(m_size.x() / 2, -m_size.y() / 2, -m_size.z() / 2);  // Bottom-Back-Right
    QVector3D v2(m_size.x() / 2, m_size.y() / 2, -m_size.z() / 2);   // Top-Back-Right
    QVector3D v3(-m_size.x() / 2, m_size.y() / 2, -m_size.z() / 2);  // Top-Back-Left
    QVector3D v4(-m_size.x() / 2, -m_size.y() / 2, m_size.z() / 2);  // Bottom-Front-Left
    QVector3D v5(m_size.x() / 2, -m_size.y() / 2, m_size.z() / 2);   // Bottom-Front-Right
    QVector3D v6(m_size.x() / 2, m_size.y() / 2, m_size.z() / 2);    // Top-Front-Right
    QVector3D v7(-m_size.x() / 2, m_size.y() / 2, m_size.z() / 2);   // Top-Front-Left

    // Define the 6 face normals, ensuring they point outward
    const QVector3D nFront(0.0f, 0.0f, 1.0f);   // Front Face (+Z)
    const QVector3D nBack(0.0f, 0.0f, -1.0f);   // Back Face (-Z)
    const QVector3D nLeft(-1.0f, 0.0f, 0.0f);   // Left Face (-X)
    const QVector3D nRight(1.0f, 0.0f, 0.0f);   // Right Face (+X)
    const QVector3D nTop(0.0f, 1.0f, 0.0f);     // Top Face (+Y)
    const QVector3D nBottom(0.0f, -1.0f, 0.0f); // Bottom Face (-Y)

    // Create a QByteArray to store interleaved vertex and normal data
    QByteArray vertexData;

    // Lambda function to append vertex and normal data to vertexData
    auto appendVertexNormal = [&](const QVector3D& vertex, const QVector3D& normal) {
        vertexData.append(reinterpret_cast<const char*>(&vertex), sizeof(QVector3D));
        vertexData.append(reinterpret_cast<const char*>(&normal), sizeof(QVector3D));
    };

    // Helper macro to define two triangles for each face
#define ADD_FACE(vA, vB, vC, normal) \
    appendVertexNormal(vA, normal); \
        appendVertexNormal(vB, normal); \
        appendVertexNormal(vC, normal);

    // Front Face (+Z)
    ADD_FACE(v4, v5, v6, nFront);
    ADD_FACE(v4, v6, v7, nFront);

    // Back Face (-Z)
    ADD_FACE(v0, v2, v1, nBack);
    ADD_FACE(v0, v3, v2, nBack);

    // Left Face (-X)
    ADD_FACE(v0, v7, v3, nLeft);
    ADD_FACE(v0, v4, v7, nLeft);

    // Right Face (+X)
    ADD_FACE(v5, v1, v2, nRight);
    ADD_FACE(v5, v2, v6, nRight);

    // Top Face (+Y)
    ADD_FACE(v3, v7, v6, nTop);
    ADD_FACE(v3, v6, v2, nTop);

    // Bottom Face (-Y)
    ADD_FACE(v0, v1, v5, nBottom);
    ADD_FACE(v0, v5, v4, nBottom);

    // Undefine the macro to prevent potential conflicts
#undef ADD_FACE

    // Set the vertex data
    setVertexData(vertexData);

    // Set up attribute information for vertices and normals
    setStride(2 * sizeof(QVector3D));  // Position + Normal data
    setBounds(-m_size / 2, m_size / 2);

    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic,
                 0,
                 QQuick3DGeometry::Attribute::F32Type);

    addAttribute(QQuick3DGeometry::Attribute::NormalSemantic,
                 sizeof(QVector3D),
                 QQuick3DGeometry::Attribute::F32Type);

    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);

    update();
}
