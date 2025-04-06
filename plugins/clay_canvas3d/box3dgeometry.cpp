#include "box3dgeometry.h"

Box3dGeometry::Box3dGeometry() : m_size(1, 1, 1), m_faceScale(1, 1), m_scaledFace(NoFace)
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

QVector2D Box3dGeometry::faceScale() const
{
    return m_faceScale;
}

void Box3dGeometry::setFaceScale(const QVector2D &newFaceScale)
{
    if (m_faceScale == newFaceScale)
        return;
    m_faceScale = newFaceScale;
    emit faceScaleChanged();
    updateData();
}

Box3dGeometry::ScaledFace Box3dGeometry::scaledFace() const
{
    return m_scaledFace;
}

void Box3dGeometry::setScaledFace(ScaledFace newScaledFace)
{
    if (m_scaledFace == newScaledFace)
        return;
    m_scaledFace = newScaledFace;
    emit scaledFaceChanged();
    updateData();
}

void Box3dGeometry::updateData()
{
    // Define the 8 vertices of the box
    QVector3D v0, v1, v2, v3, v4, v5, v6, v7;

    // Define base vertex positions
    float halfX = m_size.x() / 2;
    float height = m_size.y();
    float halfZ = m_size.z() / 2;

    // Apply scaling to specific face if specified
    float scaledHalfX = halfX;
    float scaledHalfZ = halfZ;
    if (m_scaledFace != NoFace) {
        scaledHalfX = halfX * m_faceScale.x();
        scaledHalfZ = halfZ * m_faceScale.y();
    }

    // Default vertex positions (unmodified)
    v0 = QVector3D(-halfX, 0, -halfZ);
    v1 = QVector3D(halfX, 0, -halfZ);
    v2 = QVector3D(halfX, height, -halfZ);
    v3 = QVector3D(-halfX, height, -halfZ);
    v4 = QVector3D(-halfX, 0, halfZ);
    v5 = QVector3D(halfX, 0, halfZ);
    v6 = QVector3D(halfX, height, halfZ);
    v7 = QVector3D(-halfX, height, halfZ);

    // Apply face scaling if needed
    switch (m_scaledFace) {
    case TopFace:
        // Scale top face (v3, v2, v6, v7)
        v3 = QVector3D(-scaledHalfX, height, -scaledHalfZ);
        v2 = QVector3D(scaledHalfX, height, -scaledHalfZ);
        v6 = QVector3D(scaledHalfX, height, scaledHalfZ);
        v7 = QVector3D(-scaledHalfX, height, scaledHalfZ);
        break;
    case BottomFace:
        // Scale bottom face (v0, v1, v5, v4)
        v0 = QVector3D(-scaledHalfX, 0, -scaledHalfZ);
        v1 = QVector3D(scaledHalfX, 0, -scaledHalfZ);
        v5 = QVector3D(scaledHalfX, 0, scaledHalfZ);
        v4 = QVector3D(-scaledHalfX, 0, scaledHalfZ);
        break;
    case FrontFace:
        // Scale front face (v4, v5, v6, v7)
        v4 = QVector3D(-scaledHalfX, 0, halfZ);
        v5 = QVector3D(scaledHalfX, 0, halfZ);
        v6 = QVector3D(scaledHalfX, height, halfZ);
        v7 = QVector3D(-scaledHalfX, height, halfZ);
        break;
    case BackFace:
        // Scale back face (v0, v1, v2, v3)
        v0 = QVector3D(-scaledHalfX, 0, -halfZ);
        v1 = QVector3D(scaledHalfX, 0, -halfZ);
        v2 = QVector3D(scaledHalfX, height, -halfZ);
        v3 = QVector3D(-scaledHalfX, height, -halfZ);
        break;
    case LeftFace:
        // Scale left face (v0, v3, v7, v4)
        v0 = QVector3D(-halfX, 0, -scaledHalfZ);
        v3 = QVector3D(-halfX, height, -scaledHalfZ);
        v7 = QVector3D(-halfX, height, scaledHalfZ);
        v4 = QVector3D(-halfX, 0, scaledHalfZ);
        break;
    case RightFace:
        // Scale right face (v1, v2, v6, v5)
        v1 = QVector3D(halfX, 0, -scaledHalfZ);
        v2 = QVector3D(halfX, height, -scaledHalfZ);
        v6 = QVector3D(halfX, height, scaledHalfZ);
        v5 = QVector3D(halfX, 0, scaledHalfZ);
        break;
    default:
        break;
    }

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

    // Update the bounds to account for the scaled face
    QVector3D maxBounds(halfX, height, halfZ);

    // Adjust bounds based on which face is scaled (if any)
    if (m_scaledFace != NoFace) {
        switch (m_scaledFace) {
        case TopFace:
        case BottomFace:
            maxBounds.setX(qMax(halfX, scaledHalfX));
            maxBounds.setZ(qMax(halfZ, scaledHalfZ));
            break;
        case FrontFace:
        case BackFace:
            maxBounds.setX(qMax(halfX, scaledHalfX));
            break;
        case LeftFace:
        case RightFace:
            maxBounds.setZ(qMax(halfZ, scaledHalfZ));
            break;
        default:
            break;
        }
    }

    setBounds(-maxBounds, maxBounds);

    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic,
                 0,
                 QQuick3DGeometry::Attribute::F32Type);

    addAttribute(QQuick3DGeometry::Attribute::NormalSemantic,
                 sizeof(QVector3D),
                 QQuick3DGeometry::Attribute::F32Type);

    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);

    update();
}
