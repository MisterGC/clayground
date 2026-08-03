// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Filled planar polygon geometry (issue #183, phases P2 and P3).
//
// Two vertex layouts, and which one is used is not part of the API:
//
//   lean (default)  indexed, shared vertices, Position + Normal - 24 B/vertex
//   wireframe       unshared, no index buffer, Position + Normal + the
//                   barycentric channel - 36 B/vertex
//
// Asking for edges once upgrades the buffer, and it never downgrades again: a
// polygon whose showEdges is bound to a hover state pays one rebuild in its
// lifetime and a uniform write per toggle after that. Memory is the worst case,
// not a frame hitch.
//
// The barycentric channel rides TangentSemantic as a plain data channel - we do
// no normal mapping, so nothing collides. Do not enable normal mapping on a
// material that uses this geometry.

#ifndef POLY3DGEOMETRY_H
#define POLY3DGEOMETRY_H

#include <QColor>
#include <QQuick3DGeometry>
#include <QVariantList>
#include <QVector>
#include <QVector2D>
#include <QVector3D>

// How far a barycentric component is lifted per step of the edge kind below.
// Any value well above the [0, 1] range a barycentric coordinate lives in would
// do; the shader reads the multiple back with step()s at 0.5 and 1.5 of it and
// subtracts it again. poly3d.frag repeats the number - keep the two in step.
constexpr float kPoly3DEdgeSuppressOffset = 10.0f;

// What sits on the other side of a triangle edge, which is what decides how the
// edge is drawn. The lift a barycentric component carries is the enum value
// times kPoly3DEdgeSuppressOffset.
//
// The distinction that matters is "is anything else drawing this line too":
// a rim with nothing on the other side has to be laid down at full width to
// read as edgeThickness pixels, while a line two surfaces share is drawn at
// half width from each side. Extruding moves edges between the two - a flat
// polygon's rim becomes the seam between a cap and a wall - which is why the
// kind is a property of the emitted triangle rather than of the input ring.
enum class Poly3DEdgeKind {
    Rim = 0,       // nothing on the other side: full width, drawn in both modes
    Diagonal = 1,  // interior triangulation edge: half width, Triangles mode only
    Seam = 2       // shared with another surface of the same object: half width,
                   // but a face border, so drawn in both modes
};

// The result of turning rings of 2D points into a triangle mesh. Kept as a
// plain struct so the builder can be unit tested without a scene graph.
struct Poly3DMesh
{
    QVector<QVector3D> positions;
    // One per position. Not one shared face normal any more: an extruded
    // polygon's side walls each face their own way, and averaging across the
    // ring would turn a hexagonal column into something that shades like a
    // cylinder. Flat polygons put the same plane normal in every entry.
    QVector<QVector3D> normals;
    QVector<quint32> indices;
    // One entry per index, so three per triangle: the corner's barycentric
    // coordinate plus the Poly3DEdgeKind lift of the edge opposite that corner.
    // Only the wireframe layout writes these, but they are always computed -
    // they cost one pass over the triangles and keep the builder's output
    // independent of the layout.
    QVector<QVector3D> edgeCodes;
    // The plane normal - which is also the direction an extrusion grows in, and
    // the way the top cap faces.
    QVector3D normal;
    QVector3D minBounds;
    QVector3D maxBounds;

    bool isEmpty() const { return indices.isEmpty(); }
};

class Poly3dGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Poly3DGeometry)

    Q_PROPERTY(QVariantList vertices READ vertices WRITE setVertices NOTIFY verticesChanged)
    Q_PROPERTY(QVariantList holes READ holes WRITE setHoles NOTIFY holesChanged)
    Q_PROPERTY(Plane plane READ plane WRITE setPlane NOTIFY planeChanged)
    Q_PROPERTY(float extrude READ extrude WRITE setExtrude NOTIFY extrudeChanged)
    Q_PROPERTY(bool showEdges READ showEdges WRITE setShowEdges NOTIFY showEdgesChanged)
    Q_PROPERTY(EdgeMode edgeMode READ edgeMode WRITE setEdgeMode NOTIFY edgeModeChanged)
    Q_PROPERTY(float edgeThickness READ edgeThickness WRITE setEdgeThickness NOTIFY edgeThicknessChanged)
    Q_PROPERTY(float edgeColorFactor READ edgeColorFactor WRITE setEdgeColorFactor NOTIFY edgeColorFactorChanged)
    Q_PROPERTY(QColor edgeColor READ edgeColor WRITE setEdgeColor NOTIFY edgeColorChanged)
    Q_PROPERTY(bool hasEdgeAttributes READ hasEdgeAttributes NOTIFY hasEdgeAttributesChanged)

public:
    // Which two world components a 2D vertex maps to, and which axis the face
    // normal follows. Pure vertex mapping - anything not axis-aligned is the
    // node's own rotation. Poly3D.qml declares the same values, which is what
    // the documented "plane: Poly3D.XZ" spelling resolves to.
    enum Plane {
        XZ = 0,  // (u, v) -> (u, 0, v), normal +Y  (ground)
        XY = 1,  // (u, v) -> (u, v, 0), normal +Z  (wall)
        YZ = 2   // (u, v) -> (0, u, v), normal +X  (wall)
    };
    Q_ENUM(Plane)

    // Which lines the wireframe draws. Poly3D.qml declares the same values.
    enum EdgeMode {
        FaceBorders = 0,  // the polygon outline only, interior diagonals hidden
        Triangles = 1     // every edge of the triangulation
    };
    Q_ENUM(EdgeMode)

    Poly3dGeometry();

    QVariantList vertices() const;
    void setVertices(const QVariantList &newVertices);

    QVariantList holes() const;
    void setHoles(const QVariantList &newHoles);

    Plane plane() const;
    void setPlane(Plane newPlane);

    float extrude() const;
    void setExtrude(float newExtrude);

    bool showEdges() const;
    void setShowEdges(bool newShowEdges);

    EdgeMode edgeMode() const;
    void setEdgeMode(EdgeMode newEdgeMode);

    float edgeThickness() const;
    void setEdgeThickness(float newEdgeThickness);

    float edgeColorFactor() const;
    void setEdgeColorFactor(float newEdgeColorFactor);

    QColor edgeColor() const;
    void setEdgeColor(const QColor &newEdgeColor);

    // Whether the uploaded buffer carries the barycentric channel. False until
    // edges are asked for the first time, true from then on.
    bool hasEdgeAttributes() const;

signals:
    void verticesChanged();
    void holesChanged();
    void planeChanged();
    void extrudeChanged();
    void showEdgesChanged();
    void edgeModeChanged();
    void edgeThicknessChanged();
    void edgeColorFactorChanged();
    void edgeColorChanged();
    void hasEdgeAttributesChanged();

private:
    void updateData();
    // Says out loud what a silently edgeless polygon would otherwise hide: the
    // shader was asked for triangulation lines but the buffer has no channel to
    // read them from.
    void checkEdgeContract() const;
    // Deferred, because QML applies property values in the order they are
    // written: "edgeMode: Triangles" ahead of "showEdges: true" would otherwise
    // draw a warning telling the reader to do what the next line already does.
    // One check per event loop turn, after the dust has settled.
    void scheduleEdgeContractCheck();

    QVariantList m_vertices;
    QVariantList m_holes;
    Plane m_plane = XZ;
    float m_extrude = 0.0f;
    bool m_showEdges = false;
    EdgeMode m_edgeMode = FaceBorders;
    float m_edgeThickness = 1.0f;
    float m_edgeColorFactor = 0.4f;
    QColor m_edgeColor = QColor(0, 0, 0, 0);
    bool m_hasEdgeAttributes = false;
    bool m_edgeCheckPending = false;
};

// Triangulates one outer ring plus any number of inner rings (holes).
//
// rings[0] is the outer ring, rings[1..] are holes. Rings close implicitly: a
// repeated last == first point is dropped. Winding is normalised here (outer
// CCW, holes CW) and the emitted triangles always face the plane's normal, so
// the caller is free to hand over either orientation.
//
// extrude turns the same ring into a prism: the ring stays at the local origin
// plane as the base, side walls rise along the plane normal and a cap closes
// the top - the direction and origin Box3D uses. Holes get walls too, so a ring
// with a courtyard extrudes into a building with a courtyard. At extrude 0 -
// the default - nothing of that is emitted and the mesh is the flat area it
// always was, down to the byte.
//
// Degenerate input - fewer than three points, all-collinear, zero area,
// non-finite coordinates - yields an empty mesh and one warning under the
// "clay.poly" logging category rather than a broken triangle fan.
Poly3DMesh buildPoly3DMesh(const QVector<QVector<QVector2D>> &rings,
                           Poly3dGeometry::Plane plane,
                           float extrude = 0.0f);

// Reads the ring shapes QML can hand over: Qt.vector2d(), a {x, y} object (what
// a point that has been through JSON or a spread survives as), Qt.point() and a
// plain [x, y] array. Returns false if an entry is none of those.
bool poly3dRingFromVariant(const QVariantList &points, QVector<QVector2D> *out);

#endif // POLY3DGEOMETRY_H
