#include "box3dgeometry.h"

Box3dGeometry::Box3dGeometry() : m_size(1, 1, 1), m_faceScale(1, 1), m_scaledFace(NoFace),
    m_showEdges(true), m_edgeThickness(0.03f), m_edgeFalloff(0.8f),
    m_edgeDarkness(0.6f), m_cornerDarkness(0.4f), m_viewDistanceFactor(0.01f)
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
    // Vertices for standard cube - correct orientation:
    //    v3----v2
    //   /|     /|
    //  v7----v6 |
    //  | v0---|-v1
    //  |/     |/
    //  v4----v5
    v0 = QVector3D(-halfX, 0, -halfZ);       // Left bottom back
    v1 = QVector3D(halfX, 0, -halfZ);        // Right bottom back
    v2 = QVector3D(halfX, height, -halfZ);   // Right top back
    v3 = QVector3D(-halfX, height, -halfZ);  // Left top back
    v4 = QVector3D(-halfX, 0, halfZ);        // Left bottom front
    v5 = QVector3D(halfX, 0, halfZ);         // Right bottom front
    v6 = QVector3D(halfX, height, halfZ);    // Right top front
    v7 = QVector3D(-halfX, height, halfZ);   // Left top front

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

    // Define UV coordinates for edge detection
    // Each face will have its own UV coordinate system (0,0) to (1,1)
    // Bottom-left, bottom-right, top-right, top-left for each face
    const QVector2D uvBL(0.0f, 0.0f);
    const QVector2D uvBR(1.0f, 0.0f);
    const QVector2D uvTR(1.0f, 1.0f);
    const QVector2D uvTL(0.0f, 1.0f);

    // Create a QByteArray to store interleaved vertex, normal, and UV data
    QByteArray vertexData;

    // Lambda function to append vertex, normal, and UV data to vertexData
    auto appendVertexData = [&](const QVector3D& vertex, const QVector3D& normal, const QVector2D& uv) {
        vertexData.append(reinterpret_cast<const char*>(&vertex), sizeof(QVector3D));
        vertexData.append(reinterpret_cast<const char*>(&normal), sizeof(QVector3D));
        vertexData.append(reinterpret_cast<const char*>(&uv), sizeof(QVector2D));
    };

    // Define triangles directly with explicit winding using counter-clockwise order when viewed from outside
    // Front face
    appendVertexData(v4, nFront, uvBL);
    appendVertexData(v5, nFront, uvBR);
    appendVertexData(v6, nFront, uvTR);

    appendVertexData(v4, nFront, uvBL);
    appendVertexData(v6, nFront, uvTR);
    appendVertexData(v7, nFront, uvTL);

    // Back face
    appendVertexData(v1, nBack, uvBR);
    appendVertexData(v0, nBack, uvBL);
    appendVertexData(v3, nBack, uvTL);

    appendVertexData(v1, nBack, uvBR);
    appendVertexData(v3, nBack, uvTL);
    appendVertexData(v2, nBack, uvTR);

    // Left face
    appendVertexData(v0, nLeft, uvBR);
    appendVertexData(v4, nLeft, uvBL);
    appendVertexData(v7, nLeft, uvTL);

    appendVertexData(v0, nLeft, uvBR);
    appendVertexData(v7, nLeft, uvTL);
    appendVertexData(v3, nLeft, uvTR);

    // Right face
    appendVertexData(v5, nRight, uvBL);
    appendVertexData(v1, nRight, uvBR);
    appendVertexData(v2, nRight, uvTR);

    appendVertexData(v5, nRight, uvBL);
    appendVertexData(v2, nRight, uvTR);
    appendVertexData(v6, nRight, uvTL);

    // Top face
    appendVertexData(v3, nTop, uvBL);
    appendVertexData(v7, nTop, uvTL);
    appendVertexData(v6, nTop, uvTR);

    appendVertexData(v3, nTop, uvBL);
    appendVertexData(v6, nTop, uvTR);
    appendVertexData(v2, nTop, uvBR);

    // Bottom face
    appendVertexData(v4, nBottom, uvTL);
    appendVertexData(v0, nBottom, uvBL);
    appendVertexData(v1, nBottom, uvBR);

    appendVertexData(v4, nBottom, uvTL);
    appendVertexData(v1, nBottom, uvBR);
    appendVertexData(v5, nBottom, uvTR);

    // Set the vertex data
    setVertexData(vertexData);

    // Set up attribute information for vertices, normals, and UV coordinates
    setStride(sizeof(QVector3D) + sizeof(QVector3D) + sizeof(QVector2D));  // Position + Normal + UV data

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

    // Add position attribute (offset 0)
    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic,
                 0,
                 QQuick3DGeometry::Attribute::F32Type);

    // Add normal attribute (offset sizeof(QVector3D))
    addAttribute(QQuick3DGeometry::Attribute::NormalSemantic,
                 sizeof(QVector3D),
                 QQuick3DGeometry::Attribute::F32Type);

    // Add texture coordinates (UV) attribute for edge detection
    addAttribute(QQuick3DGeometry::Attribute::TexCoordSemantic,
                 sizeof(QVector3D) + sizeof(QVector3D),
                 QQuick3DGeometry::Attribute::F32Type);

    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);

    update();
}

// Edge rendering property implementations
bool Box3dGeometry::showEdges() const
{
    return m_showEdges;
}

void Box3dGeometry::setShowEdges(bool show)
{
    if (m_showEdges == show)
        return;
    m_showEdges = show;
    emit showEdgesChanged();
    update();
}

float Box3dGeometry::edgeThickness() const
{
    return m_edgeThickness;
}

void Box3dGeometry::setEdgeThickness(float thickness)
{
    if (qFuzzyCompare(m_edgeThickness, thickness))
        return;
    m_edgeThickness = thickness;
    emit edgeThicknessChanged();
    update();
}

float Box3dGeometry::edgeFalloff() const
{
    return m_edgeFalloff;
}

void Box3dGeometry::setEdgeFalloff(float falloff)
{
    if (qFuzzyCompare(m_edgeFalloff, falloff))
        return;
    m_edgeFalloff = falloff;
    emit edgeFalloffChanged();
    update();
}

float Box3dGeometry::edgeDarkness() const
{
    return m_edgeDarkness;
}

void Box3dGeometry::setEdgeDarkness(float darkness)
{
    if (qFuzzyCompare(m_edgeDarkness, darkness))
        return;
    m_edgeDarkness = darkness;
    emit edgeDarknessChanged();
    update();
}

float Box3dGeometry::cornerDarkness() const
{
    return m_cornerDarkness;
}

void Box3dGeometry::setCornerDarkness(float darkness)
{
    if (qFuzzyCompare(m_cornerDarkness, darkness))
        return;
    m_cornerDarkness = darkness;
    emit cornerDarknessChanged();
    update();
}

float Box3dGeometry::viewDistanceFactor() const
{
    return m_viewDistanceFactor;
}

void Box3dGeometry::setViewDistanceFactor(float factor)
{
    if (qFuzzyCompare(m_viewDistanceFactor, factor))
        return;
    m_viewDistanceFactor = factor;
    emit viewDistanceFactorChanged();
    update();
}
