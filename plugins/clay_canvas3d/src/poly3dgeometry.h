// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Filled planar polygon geometry (issue #183, phase P2).
//
// The lean layout on purpose: indexed, shared vertices, Position + Normal only
// (24 B/vertex). No barycentric channel, no edge attributes - the wireframe
// phase adds a second layout rather than making this one carry weight it does
// not need yet.

#ifndef POLY3DGEOMETRY_H
#define POLY3DGEOMETRY_H

#include <QQuick3DGeometry>
#include <QVariantList>
#include <QVector>
#include <QVector2D>
#include <QVector3D>

// The result of turning rings of 2D points into a triangle mesh. Kept as a
// plain struct so the builder can be unit tested without a scene graph.
struct Poly3DMesh
{
    QVector<QVector3D> positions;
    QVector<quint32> indices;
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

    Poly3dGeometry();

    QVariantList vertices() const;
    void setVertices(const QVariantList &newVertices);

    QVariantList holes() const;
    void setHoles(const QVariantList &newHoles);

    Plane plane() const;
    void setPlane(Plane newPlane);

signals:
    void verticesChanged();
    void holesChanged();
    void planeChanged();

private:
    void updateData();

    QVariantList m_vertices;
    QVariantList m_holes;
    Plane m_plane = XZ;
};

// Triangulates one outer ring plus any number of inner rings (holes).
//
// rings[0] is the outer ring, rings[1..] are holes. Rings close implicitly: a
// repeated last == first point is dropped. Winding is normalised here (outer
// CCW, holes CW) and the emitted triangles always face the plane's normal, so
// the caller is free to hand over either orientation.
//
// Degenerate input - fewer than three points, all-collinear, zero area,
// non-finite coordinates - yields an empty mesh and one warning under the
// "clay.poly" logging category rather than a broken triangle fan.
Poly3DMesh buildPoly3DMesh(const QVector<QVector<QVector2D>> &rings,
                           Poly3dGeometry::Plane plane);

// Reads the ring shapes QML can hand over: Qt.vector2d(), a {x, y} object (what
// a point that has been through JSON or a spread survives as), Qt.point() and a
// plain [x, y] array. Returns false if an entry is none of those.
bool poly3dRingFromVariant(const QVariantList &points, QVector<QVector2D> *out);

#endif // POLY3DGEOMETRY_H
