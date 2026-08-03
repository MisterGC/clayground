// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "poly3dgeometry.h"

#include <mapbox/earcut.hpp>

#include <QLoggingCategory>
#include <QPointF>

#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

Q_LOGGING_CATEGORY(lcPoly, "clay.poly")

/*!
    \qmltype Poly3DGeometry
    \nativetype Poly3dGeometry
    \inqmlmodule Clayground.Canvas3D
    \brief Custom geometry for filled planar polygons.

    Poly3DGeometry triangulates one outer ring of 2D points plus any number of
    inner rings (holes) into a filled, planar mesh. It is typically used
    through the Poly3D component rather than directly.

    The mesh is indexed and carries positions and one shared face normal - the
    smallest layout that draws a filled area.

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    Model {
        geometry: Poly3DGeometry {
            vertices: [Qt.vector2d(0, 0), Qt.vector2d(100, 0), Qt.vector2d(50, 80)]
        }
        materials: DefaultMaterial { diffuseColor: "#0f9d9a" }
    }
    \endqml

    \sa Poly3D
*/

/*!
    \qmlproperty list<vector2d> Poly3DGeometry::vertices
    \brief The outer ring of the polygon.

    A list of 2D points in the polygon's plane. The ring closes implicitly, so
    a repeated last point is dropped. Winding does not matter - it is
    normalised while building.
*/

/*!
    \qmlproperty list<list<vector2d>> Poly3DGeometry::holes
    \brief Inner rings cut out of the polygon.

    Each entry is a ring in the same format as \l vertices. Rings that lie
    outside the outer ring or overlap each other are not repaired.
*/

/*!
    \qmlproperty enumeration Poly3DGeometry::plane
    \brief Which world plane the 2D points map to.

    \value Poly3DGeometry.XZ (u, v) becomes (u, 0, v), normal +Y (default)
    \value Poly3DGeometry.XY (u, v) becomes (u, v, 0), normal +Z
    \value Poly3DGeometry.YZ (u, v) becomes (0, u, v), normal +X
*/

namespace {

// earcut's default accessor goes through std::get, which std::array serves.
using EarcutPoint = std::array<double, 2>;

constexpr int kFloatsPerVertex = 6;  // position (3) + normal (3)

bool isUsable(const QVector2D &p)
{
    return std::isfinite(p.x()) && std::isfinite(p.y());
}

// Twice the signed area of the ring; positive is counter-clockwise in the
// (u, v) frame. The factor of two is irrelevant - only sign and magnitude
// against an epsilon are ever asked for.
double doubleSignedArea(const QVector<QVector2D> &ring)
{
    double area = 0.0;
    for (int i = 0, j = ring.size() - 1; i < ring.size(); j = i++)
        area += double(ring[j].x()) * double(ring[i].y())
              - double(ring[i].x()) * double(ring[j].y());
    return area;
}

// qFuzzyCompare() is no help near the origin, so compare against an epsilon
// that rides on the points' own magnitude.
bool samePoint(const QVector2D &a, const QVector2D &b)
{
    const float scale = qMax(1.0f, qMax(qAbs(a.x()), qAbs(a.y())));
    return (a - b).lengthSquared() <= 1e-12f * scale * scale;
}

// A ring closes implicitly, so a repeated last == first point is data the
// mesh must not carry: it would make one zero-area ear and one wasted vertex.
QVector<QVector2D> dropClosingPoint(const QVector<QVector2D> &ring)
{
    if (ring.size() >= 2 && samePoint(ring.first(), ring.last()))
        return ring.mid(0, ring.size() - 1);
    return ring;
}

QVector3D toWorld(const QVector2D &p, Poly3dGeometry::Plane plane)
{
    switch (plane) {
    case Poly3dGeometry::XY: return QVector3D(p.x(), p.y(), 0.0f);
    case Poly3dGeometry::YZ: return QVector3D(0.0f, p.x(), p.y());
    case Poly3dGeometry::XZ: break;
    }
    return QVector3D(p.x(), 0.0f, p.y());
}

QVector3D planeNormal(Poly3dGeometry::Plane plane)
{
    switch (plane) {
    case Poly3dGeometry::XY: return QVector3D(0.0f, 0.0f, 1.0f);
    case Poly3dGeometry::YZ: return QVector3D(1.0f, 0.0f, 0.0f);
    case Poly3dGeometry::XZ: break;
    }
    return QVector3D(0.0f, 1.0f, 0.0f);
}

// Which sign the 2D cross product of a triangle must have for its geometric
// normal to point along the plane's normal. XZ is the odd one out: mapping
// (u, v) to (x, z) is left-handed against +Y, so a ring that is
// counter-clockwise on paper faces downwards unless the triangle is flipped.
double wantedCrossSign(Poly3dGeometry::Plane plane)
{
    return plane == Poly3dGeometry::XZ ? -1.0 : 1.0;
}

double cross2d(const QVector2D &a, const QVector2D &b, const QVector2D &c)
{
    return (double(b.x()) - a.x()) * (double(c.y()) - a.y())
         - (double(b.y()) - a.y()) * (double(c.x()) - a.x());
}

bool pointFromVariant(const QVariant &value, QVector2D *out)
{
    switch (value.metaType().id()) {
    case QMetaType::QVector2D:
        *out = value.value<QVector2D>();
        return true;
    case QMetaType::QVector3D: {
        const QVector3D v = value.value<QVector3D>();
        *out = QVector2D(v.x(), v.y());
        return true;
    }
    case QMetaType::QPointF: {
        const QPointF p = value.toPointF();
        *out = QVector2D(float(p.x()), float(p.y()));
        return true;
    }
    case QMetaType::QPoint: {
        const QPoint p = value.toPoint();
        *out = QVector2D(float(p.x()), float(p.y()));
        return true;
    }
    default:
        break;
    }

    // A point that has been through JS - spread into a new object, or deep
    // copied through JSON - arrives as a plain {x, y} map rather than a
    // QVector2D. Reading it for what it is beats hoping for a conversion
    // (the lesson of #178 in voxelmapdata.cpp).
    if (value.canConvert<QVariantMap>()) {
        const QVariantMap map = value.toMap();
        if (map.contains("x") && map.contains("y")) {
            bool okX = false, okY = false;
            const double x = map.value("x").toDouble(&okX);
            const double y = map.value("y").toDouble(&okY);
            if (okX && okY) {
                *out = QVector2D(float(x), float(y));
                return true;
            }
        }
    }

    if (value.canConvert<QVariantList>()) {
        const QVariantList list = value.toList();
        if (list.size() == 2) {
            bool okX = false, okY = false;
            const double x = list.at(0).toDouble(&okX);
            const double y = list.at(1).toDouble(&okY);
            if (okX && okY) {
                *out = QVector2D(float(x), float(y));
                return true;
            }
        }
    }

    return false;
}

} // namespace

bool poly3dRingFromVariant(const QVariantList &points, QVector<QVector2D> *out)
{
    out->clear();
    out->reserve(points.size());
    for (const QVariant &entry : points) {
        QVector2D point;
        if (!pointFromVariant(entry, &point)) {
            qCWarning(lcPoly) << "poly3d: unusable vertex" << entry
                              << "- expected Qt.vector2d(x, y), {x, y} or [x, y]";
            out->clear();
            return false;
        }
        out->append(point);
    }
    return true;
}

Poly3DMesh buildPoly3DMesh(const QVector<QVector<QVector2D>> &rings,
                           Poly3dGeometry::Plane plane)
{
    Poly3DMesh mesh;
    mesh.normal = planeNormal(plane);

    if (rings.isEmpty()) {
        qCWarning(lcPoly) << "poly3d: no outer ring - nothing drawn";
        return mesh;
    }

    QVector<QVector2D> outer = dropClosingPoint(rings.first());
    if (outer.size() < 3) {
        qCWarning(lcPoly) << "poly3d: outer ring has" << outer.size()
                          << "points, at least 3 are needed - nothing drawn";
        return mesh;
    }
    for (const QVector2D &p : outer) {
        if (!isUsable(p)) {
            qCWarning(lcPoly) << "poly3d: outer ring has a non-finite point" << p
                              << "- nothing drawn";
            return mesh;
        }
    }

    // Zero area covers both "all points collinear" and "every point the same".
    // The epsilon rides on the ring's own extent so a polygon measured in
    // millimetres is judged as leniently as one measured in metres.
    float minU = outer.first().x(), maxU = minU;
    float minV = outer.first().y(), maxV = minV;
    for (const QVector2D &p : outer) {
        minU = qMin(minU, p.x()); maxU = qMax(maxU, p.x());
        minV = qMin(minV, p.y()); maxV = qMax(maxV, p.y());
    }
    const double extent = qMax(double(maxU) - minU, double(maxV) - minV);
    const double areaEps = 1e-9 * qMax(1.0, extent * extent);

    double outerArea = doubleSignedArea(outer);
    if (qAbs(outerArea) <= areaEps) {
        qCWarning(lcPoly) << "poly3d: outer ring encloses no area (collinear or"
                          << "zero size) - nothing drawn";
        return mesh;
    }

    // Winding is normalised here rather than demanded of the caller: outer
    // counter-clockwise, holes clockwise, which is the orientation earcut's
    // hole bridging assumes.
    if (outerArea < 0.0) {
        std::reverse(outer.begin(), outer.end());
        outerArea = -outerArea;
    }

    QVector<QVector<QVector2D>> cleaned;
    cleaned.append(outer);

    for (int i = 1; i < rings.size(); ++i) {
        QVector<QVector2D> hole = dropClosingPoint(rings.at(i));
        if (hole.size() < 3) {
            qCWarning(lcPoly) << "poly3d: hole" << (i - 1) << "has" << hole.size()
                              << "points, at least 3 are needed - hole ignored";
            continue;
        }
        bool usable = true;
        for (const QVector2D &p : hole)
            usable = usable && isUsable(p);
        if (!usable) {
            qCWarning(lcPoly) << "poly3d: hole" << (i - 1)
                              << "has a non-finite point - hole ignored";
            continue;
        }
        const double holeArea = doubleSignedArea(hole);
        if (qAbs(holeArea) <= areaEps) {
            qCWarning(lcPoly) << "poly3d: hole" << (i - 1)
                              << "encloses no area - hole ignored";
            continue;
        }
        if (holeArea > 0.0)
            std::reverse(hole.begin(), hole.end());
        cleaned.append(hole);
    }

    // Triangulation runs on the calling thread on purpose: ring sizes here are
    // tens to low hundreds of points, far below where handing the work to
    // another thread would pay for its own bookkeeping.
    std::vector<std::vector<EarcutPoint>> polygon;
    polygon.reserve(size_t(cleaned.size()));
    for (const QVector<QVector2D> &ring : cleaned) {
        std::vector<EarcutPoint> converted;
        converted.reserve(size_t(ring.size()));
        for (const QVector2D &p : ring)
            converted.push_back({double(p.x()), double(p.y())});
        polygon.push_back(std::move(converted));
    }

    const std::vector<uint32_t> triangles = mapbox::earcut<uint32_t>(polygon);
    if (triangles.empty()) {
        qCWarning(lcPoly) << "poly3d: triangulation produced no triangles"
                          << "- self-intersecting ring? - nothing drawn";
        return mesh;
    }

    // Flat point list in earcut's index space: outer ring first, then holes.
    QVector<QVector2D> flat;
    for (const QVector<QVector2D> &ring : cleaned)
        flat.append(ring);

    mesh.positions.reserve(flat.size());
    for (const QVector2D &p : flat)
        mesh.positions.append(toWorld(p, plane));

    // Face the plane's normal whatever earcut's own convention happens to be:
    // a triangle whose 2D cross product has the wrong sign is emitted the
    // other way round. Cheaper and more durable than trusting a library's
    // output winding.
    const double wanted = wantedCrossSign(plane);
    mesh.indices.reserve(int(triangles.size()));
    for (size_t i = 0; i + 2 < triangles.size(); i += 3) {
        const uint32_t a = triangles[i], b = triangles[i + 1], c = triangles[i + 2];
        const double sign = cross2d(flat.at(int(a)), flat.at(int(b)), flat.at(int(c)));
        mesh.indices.append(a);
        if (sign * wanted >= 0.0) {
            mesh.indices.append(b);
            mesh.indices.append(c);
        } else {
            mesh.indices.append(c);
            mesh.indices.append(b);
        }
    }

    // Real bounds: a wrong box lets the shadow frustum slice through the
    // polygon, which reads as the geometry being broken.
    QVector3D minBounds = mesh.positions.first();
    QVector3D maxBounds = minBounds;
    for (const QVector3D &p : mesh.positions) {
        minBounds.setX(qMin(minBounds.x(), p.x()));
        minBounds.setY(qMin(minBounds.y(), p.y()));
        minBounds.setZ(qMin(minBounds.z(), p.z()));
        maxBounds.setX(qMax(maxBounds.x(), p.x()));
        maxBounds.setY(qMax(maxBounds.y(), p.y()));
        maxBounds.setZ(qMax(maxBounds.z(), p.z()));
    }
    mesh.minBounds = minBounds;
    mesh.maxBounds = maxBounds;

    return mesh;
}

Poly3dGeometry::Poly3dGeometry()
{
    updateData();
}

QVariantList Poly3dGeometry::vertices() const
{
    return m_vertices;
}

void Poly3dGeometry::setVertices(const QVariantList &newVertices)
{
    if (m_vertices == newVertices)
        return;
    m_vertices = newVertices;
    emit verticesChanged();
    updateData();
}

QVariantList Poly3dGeometry::holes() const
{
    return m_holes;
}

void Poly3dGeometry::setHoles(const QVariantList &newHoles)
{
    if (m_holes == newHoles)
        return;
    m_holes = newHoles;
    emit holesChanged();
    updateData();
}

Poly3dGeometry::Plane Poly3dGeometry::plane() const
{
    return m_plane;
}

void Poly3dGeometry::setPlane(Plane newPlane)
{
    if (m_plane == newPlane)
        return;
    m_plane = newPlane;
    emit planeChanged();
    updateData();
}

void Poly3dGeometry::updateData()
{
    // clear() first - addAttribute() appends, so rebuilding without it would
    // stack a second set of attributes on every property change.
    clear();
    setStride(kFloatsPerVertex * int(sizeof(float)));
    setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);
    addAttribute(QQuick3DGeometry::Attribute::PositionSemantic, 0,
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::NormalSemantic, 3 * int(sizeof(float)),
                 QQuick3DGeometry::Attribute::F32Type);
    addAttribute(QQuick3DGeometry::Attribute::IndexSemantic, 0,
                 QQuick3DGeometry::Attribute::U32Type);

    // An unset polygon is not a mistake - it draws nothing and says nothing.
    if (m_vertices.isEmpty()) {
        setVertexData(QByteArray());
        setIndexData(QByteArray());
        setBounds(QVector3D(), QVector3D());
        update();
        return;
    }

    QVector<QVector<QVector2D>> rings;
    QVector<QVector2D> outer;
    if (poly3dRingFromVariant(m_vertices, &outer))
        rings.append(outer);

    for (const QVariant &entry : m_holes) {
        QVector<QVector2D> hole;
        if (poly3dRingFromVariant(entry.toList(), &hole))
            rings.append(hole);
    }

    const Poly3DMesh mesh = rings.isEmpty() ? Poly3DMesh()
                                            : buildPoly3DMesh(rings, m_plane);

    QByteArray vertexData;
    vertexData.resize(mesh.positions.size() * kFloatsPerVertex * int(sizeof(float)));
    float *cursor = reinterpret_cast<float *>(vertexData.data());
    for (const QVector3D &p : mesh.positions) {
        *cursor++ = p.x();
        *cursor++ = p.y();
        *cursor++ = p.z();
        *cursor++ = mesh.normal.x();
        *cursor++ = mesh.normal.y();
        *cursor++ = mesh.normal.z();
    }
    setVertexData(vertexData);

    setIndexData(QByteArray(reinterpret_cast<const char *>(mesh.indices.constData()),
                            mesh.indices.size() * int(sizeof(quint32))));
    setBounds(mesh.minBounds, mesh.maxBounds);

    update();
}
