#include <limits>
#include "box3dgeometry.h"

/*!
    \qmltype Box3DGeometry
    \nativetype Box3dGeometry
    \inqmlmodule Clayground.Canvas3D
    \brief Custom geometry for 3D boxes with edge rendering support.

    Box3DGeometry provides the geometry data for rendering 3D boxes with
    customizable dimensions, face scaling, and edge rendering. It is typically
    used internally by the Box3D QML component.

    The geometry is centered on the X and Z axes, with the origin at the
    bottom center (Y=0 is the floor).

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    Model {
        geometry: Box3DGeometry {
            size: Qt.vector3d(2, 3, 2)
            showEdges: true
            edgeThickness: 0.05
        }
        materials: DefaultMaterial { diffuseColor: "red" }
    }
    \endqml

    \sa Box3D
*/

/*!
    \qmlproperty vector3d Box3DGeometry::size
    \brief The dimensions of the box as a 3D vector (width, height, depth).

    Defaults to (1, 1, 1).
*/

/*!
    \qmlproperty vector2d Box3DGeometry::faceScale
    \brief Scale factor applied to the selected face.

    When scaledFace is set to a specific face, this vector determines how
    much that face is scaled in its local X and Y dimensions. Useful for
    creating pyramids, trapezoids, and other non-uniform shapes.

    Defaults to (1, 1).
*/

/*!
    \qmlproperty enumeration Box3DGeometry::scaledFace
    \brief Which face of the box should be scaled.

    \value Box3DGeometry.NoFace No face scaling (default)
    \value Box3DGeometry.TopFace Scale the top face
    \value Box3DGeometry.BottomFace Scale the bottom face
    \value Box3DGeometry.FrontFace Scale the front face
    \value Box3DGeometry.BackFace Scale the back face
    \value Box3DGeometry.LeftFace Scale the left face
    \value Box3DGeometry.RightFace Scale the right face
*/

/*!
    \qmlproperty bool Box3DGeometry::showEdges
    \brief Whether to render edge lines on the box.

    When true, dark lines are drawn along the edges of the box for a
    cartoon-style appearance. Defaults to true.
*/

/*!
    \qmlproperty real Box3DGeometry::edgeThickness
    \brief The thickness of edge lines in pixels.

    Screen-space, so an edge keeps its weight as the camera moves - and the
    same width VoxelMap::edgeThickness produces, not just the same unit. A
    line straddles the boundary it marks and each surface draws half of it, so
    a box border and a voxel map's border come out equal at the same setting;
    a voxel map's interior grid lines sit entirely on one face and so draw the
    full width.

    Defaults to 0.03, which is thinner than one pixel - set it to a few pixels
    to see anything.
*/

/*!
    \qmlproperty real Box3DGeometry::edgeColorFactor
    \brief Darkening factor for edge colors.

    A value between 0 and 1 that determines how dark the edges appear
    relative to the base color. Lower values create darker edges.
    Defaults to 0.4.

    Ignored once edgeColor is set.
*/

/*!
    \qmlproperty color Box3DGeometry::edgeColor
    \brief The edge color, as an absolute color rather than a factor.

    Takes precedence over edgeColorFactor as soon as it has a visible alpha,
    which is what "set" means here - a fully transparent edge has no meaning,
    so it serves as the unset sentinel and leaves opaque black reachable.
    Defaults to transparent, so edgeColorFactor keeps deciding.
*/

/*!
    \qmlproperty int Box3DGeometry::edgeMask
    \brief Bitmask controlling which edges are visible.

    Use the EdgeFlags enum values combined with bitwise OR to select
    specific edges. Defaults to AllEdges.

    \value Box3DGeometry.AllEdges Show all edges (0xFF)
    \value Box3DGeometry.TopEdges Show only top face edges
    \value Box3DGeometry.BottomEdges Show only bottom face edges
    \value Box3DGeometry.FrontEdges Show only front face edges
    \value Box3DGeometry.BackEdges Show only back face edges
    \value Box3DGeometry.LeftEdges Show only left face edges
    \value Box3DGeometry.RightEdges Show only right face edges
*/

/*!
    \qmlproperty enumeration Box3DGeometry::edgeMode
    \brief Which lines showEdges draws.

    \value Box3DGeometry.FaceBorders The twelve borders of the six faces - a
           box drawn as a box. The default, and what edgeMask selects from.
    \value Box3DGeometry.Triangles The box's actual triangulation, so every
           face also shows the diagonal that splits it into two triangles.
           For showing how the mesh is built rather than what it depicts.

    edgeMask applies to FaceBorders only. In Triangles mode every triangle
    edge is drawn and the mask is ignored, because a triangulation with parts
    of it missing is not a triangulation.

    Switching modes costs a uniform write, not a rebuild: the barycentric
    coordinates Triangles needs sit in the vertex buffer either way.
*/

Box3dGeometry::Box3dGeometry() : m_size(1, 1, 1), m_faceScale(1, 1), m_scaledFace(NoFace),
    m_showEdges(true), m_edgeThickness(0.03f), m_edgeColorFactor(0.4f), m_edgeMask(AllEdges)
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

float Box3dGeometry::bevel() const
{
    return m_bevel;
}

void Box3dGeometry::setBevel(float newBevel)
{
    const float v = qBound(0.0f, newBevel, 0.5f);
    if (qFuzzyCompare(m_bevel, v))
        return;
    m_bevel = v;
    emit bevelChanged();
    updateData();
}

void Box3dGeometry::updateData()
{
    // addAttribute() appends, so a rebuild without this stacks a second copy
    // of every attribute on top of the first and eventually runs the geometry
    // out of attribute slots. Everything clear() drops - vertex data, stride,
    // bounds, primitive type - is set again below.
    clear();

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

    // Create a QByteArray to store interleaved vertex, normal, UV and
    // barycentric data
    QByteArray vertexData;

    // The barycentric coordinate rides along unconditionally. It is what
    // edgeMode: Triangles derives its lines from, and since the box is
    // already 36 unshared vertices with no index buffer it costs 432 bytes
    // and no second code path. See box3d.frag for what the shader does with
    // it - and note that it travels as TANGENT, which is a data channel here
    // and not a tangent: nothing on this material may enable normal mapping.
    const QVector3D bary[3] = { QVector3D(1, 0, 0),
                                QVector3D(0, 1, 0),
                                QVector3D(0, 0, 1) };
    int corner = 0;

    // Lambda function to append vertex, normal, UV and barycentric data.
    // Vertices are emitted strictly three at a time, one triangle after the
    // other, so the corner index alone identifies which coordinate is due.
    auto appendVertexData = [&](const QVector3D& vertex, const QVector3D& normal, const QVector2D& uv) {
        vertexData.append(reinterpret_cast<const char*>(&vertex), sizeof(QVector3D));
        vertexData.append(reinterpret_cast<const char*>(&normal), sizeof(QVector3D));
        vertexData.append(reinterpret_cast<const char*>(&uv), sizeof(QVector2D));
        const QVector3D b = bary[corner];
        vertexData.append(reinterpret_cast<const char*>(&b), sizeof(QVector3D));
        corner = (corner + 1) % 3;
    };

    // --- the rounded version --------------------------------------------------
    //
    // A chamfer on every edge and corner, which is as much rounding as a box
    // can have without stopping being one. Sonic and everyone descended from
    // him are round because the FORMS are round, and a bevel is the cheapest
    // move in that direction: the silhouette stops being a set of right angles
    // and every edge picks up a highlight that says "this is a solid, and it
    // turns here".
    //
    // It costs 44 triangles instead of 12 and NOT ONE extra draw call, which
    // is the only budget that turned out to matter - measured at 17.8 us per
    // draw call and next to nothing per vertex. Rounding a character is
    // affordable; having more characters is not.
    //
    // The outline survives it for free, and the reason is worth writing down
    // because it is the whole feasibility of this feature. box3d.frag draws
    // its default edges from the per-face UVs, not from triangle boundaries:
    // a fragment is on an edge when its UV is near 0 or 1. Chamfer strips are
    // given a CONSTANT UV, so fwidth() of it is zero, the distance to any
    // border comes out enormous, and the shader draws nothing on them. The six
    // real faces keep their 0..1 UVs and go on being outlined exactly where
    // they were. Nothing in the shader had to change.
    //
    // edgeMode: Triangles is the exception - it derives lines from the
    // triangulation itself and will happily draw every chamfer seam. The two
    // are not meant to be combined.
    if (m_bevel > 0.0f) {
        const QVector3D V[8] = { v0, v1, v2, v3, v4, v5, v6, v7 };

        // Faces as ordered corner indices, wound the same way the flat path
        // winds them, with the UVs that path gives each corner.
        const int F[6][4] = {
            { 4, 5, 6, 7 },  // front
            { 1, 0, 3, 2 },  // back
            { 0, 4, 7, 3 },  // left
            { 5, 1, 2, 6 },  // right
            { 3, 7, 6, 2 },  // top
            { 4, 0, 1, 5 }   // bottom
        };
        const QVector3D N[6] = { nFront, nBack, nLeft, nRight, nTop, nBottom };
        const QVector2D UV[6][4] = {
            { uvBL, uvBR, uvTR, uvTL },
            { uvBR, uvBL, uvTL, uvTR },
            { uvBR, uvBL, uvTL, uvTR },
            { uvBL, uvBR, uvTR, uvTL },
            { uvBL, uvTL, uvTR, uvBR },
            { uvTL, uvBL, uvBR, uvTR }
        };

        // How wide the chamfer is, in world units. Taken from the shortest
        // edge on the box rather than from any one dimension: a thin slab of a
        // hand and a long limb are both boxes, and a bevel that is a fraction
        // of the LONG side eats a thin one whole. Capped below half of that
        // shortest edge, or opposite corners of a face cross through each
        // other and the box turns inside out.
        float shortest = std::numeric_limits<float>::max();
        for (int f = 0; f < 6; ++f)
            for (int p = 0; p < 4; ++p)
                shortest = qMin(shortest,
                                (V[F[f][(p + 1) % 4]] - V[F[f][p]]).length());
        const float b = qMin(m_bevel * shortest, 0.45f * shortest);

        // Each face pulled in from its own corners, along its own two edges.
        // Along the edges rather than toward the centre, because a tapered
        // face is not a rectangle and shrinking one toward its middle moves
        // its corners by different amounts.
        QVector3D inset[6][4];
        for (int f = 0; f < 6; ++f) {
            for (int p = 0; p < 4; ++p) {
                const QVector3D &c = V[F[f][p]];
                const QVector3D toNext = V[F[f][(p + 1) % 4]] - c;
                const QVector3D toPrev = V[F[f][(p + 3) % 4]] - c;
                inset[f][p] = c + toNext.normalized() * b + toPrev.normalized() * b;
            }
        }

        // Wound outward by testing, not by bookkeeping. Twelve chamfers and
        // eight corners is a lot of winding to get right by hand and every
        // one that is wrong is an invisible hole; comparing the triangle's own
        // normal against the direction it should face is one line and cannot
        // be got wrong.
        auto tri = [&](const QVector3D &a, const QVector3D &c,
                       const QVector3D &d, const QVector3D &shadeNormal,
                       const QVector3D &outward) {
            QVector3D geo = QVector3D::crossProduct(c - a, d - a);
            const bool flip = QVector3D::dotProduct(geo, outward) < 0.0f;
            const QVector2D flat(0.5f, 0.5f);
            appendVertexData(a, shadeNormal, flat);
            appendVertexData(flip ? d : c, shadeNormal, flat);
            appendVertexData(flip ? c : d, shadeNormal, flat);
        };

        // The six faces, inset. These keep their real UVs and their real
        // normals, so they keep their outline and their flat shading.
        for (int f = 0; f < 6; ++f) {
            appendVertexData(inset[f][0], N[f], UV[f][0]);
            appendVertexData(inset[f][1], N[f], UV[f][1]);
            appendVertexData(inset[f][2], N[f], UV[f][2]);

            appendVertexData(inset[f][0], N[f], UV[f][0]);
            appendVertexData(inset[f][2], N[f], UV[f][2]);
            appendVertexData(inset[f][3], N[f], UV[f][3]);
        }

        // The twelve chamfers. Every box edge is shared by exactly two faces,
        // so walking all 24 face-edges and pairing them up finds each once.
        for (int f = 0; f < 6; ++f) {
            for (int p = 0; p < 4; ++p) {
                const int ia = F[f][p], ib = F[f][(p + 1) % 4];
                for (int g = f + 1; g < 6; ++g) {
                    for (int q = 0; q < 4; ++q) {
                        const int ja = F[g][q], jb = F[g][(q + 1) % 4];
                        if (!((ia == jb && ib == ja) || (ia == ja && ib == jb)))
                            continue;
                        // The chamfer's normal is the two faces averaged,
                        // which is what makes it read as a turn rather than as
                        // a third facet.
                        const QVector3D nn = (N[f] + N[g]).normalized();
                        const QVector3D A0 = inset[f][p];
                        const QVector3D A1 = inset[f][(p + 1) % 4];
                        const QVector3D B0 = (ia == ja) ? inset[g][q]
                                                        : inset[g][(q + 1) % 4];
                        const QVector3D B1 = (ia == ja) ? inset[g][(q + 1) % 4]
                                                        : inset[g][q];
                        tri(A0, A1, B1, nn, nn);
                        tri(A0, B1, B0, nn, nn);
                    }
                }
            }
        }

        // The eight corners. Three faces meet at each, each having pulled back
        // from it, leaving a triangular hole to fill.
        for (int k = 0; k < 8; ++k) {
            QVector3D pts[3];
            QVector3D nsum;
            int found = 0;
            for (int f = 0; f < 6 && found < 3; ++f) {
                for (int p = 0; p < 4; ++p) {
                    if (F[f][p] != k)
                        continue;
                    pts[found++] = inset[f][p];
                    nsum += N[f];
                    break;
                }
            }
            if (found == 3) {
                const QVector3D nn = nsum.normalized();
                tri(pts[0], pts[1], pts[2], nn, nn);
            }
        }
    } else {
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
    }

    // Set the vertex data
    setVertexData(vertexData);

    // Set up attribute information for vertices, normals, UV coordinates and
    // barycentrics
    setStride(sizeof(QVector3D) + sizeof(QVector3D) + sizeof(QVector2D) + sizeof(QVector3D));

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

    // Barycentric coordinates, carried on the tangent slot - unused for
    // tangents across the whole plugin, and a vec3, which is exactly the
    // shape of the data. Reaches the shader as TANGENT.
    addAttribute(QQuick3DGeometry::Attribute::TangentSemantic,
                 sizeof(QVector3D) + sizeof(QVector3D) + sizeof(QVector2D),
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

float Box3dGeometry::edgeColorFactor() const
{
    return m_edgeColorFactor;
}

void Box3dGeometry::setEdgeColorFactor(float factor)
{
    if (qFuzzyCompare(m_edgeColorFactor, factor))
        return;
    m_edgeColorFactor = factor;
    emit edgeColorFactorChanged();
    update();
}

QColor Box3dGeometry::edgeColor() const
{
    return m_edgeColor;
}

void Box3dGeometry::setEdgeColor(const QColor &color)
{
    if (m_edgeColor == color)
        return;
    m_edgeColor = color;
    emit edgeColorChanged();
    update();
}

int Box3dGeometry::edgeMask() const
{
    return m_edgeMask;
}

void Box3dGeometry::setEdgeMask(int mask)
{
    if (m_edgeMask == mask)
        return;
    m_edgeMask = mask;
    emit edgeMaskChanged();
    update();
}

Box3dGeometry::EdgeMode Box3dGeometry::edgeMode() const
{
    return m_edgeMode;
}

void Box3dGeometry::setEdgeMode(EdgeMode mode)
{
    if (m_edgeMode == mode)
        return;
    m_edgeMode = mode;
    emit edgeModeChanged();
    // No rebuild: both modes read the same vertex buffer.
    update();
}
