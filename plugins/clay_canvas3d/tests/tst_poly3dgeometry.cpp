// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// What buildPoly3DMesh() makes of a ring of points (issue #183).
//
// The mesh builder is the part of Poly3D that can be wrong quietly: a polygon
// with the wrong winding is invisible from the side it is meant to be seen
// from, a hole that was not cut looks like a solid area nobody notices is
// wrong, and degenerate input must come back as "nothing drawn" rather than as
// a crash or a fan of garbage triangles. All of that is checked here, without
// a scene graph - the geometry class only copies these numbers into buffers.

#include <QtTest>
#include <QVector2D>
#include <QVector3D>

#include "poly3dgeometry.h"

#include <cmath>

namespace {

QVector<QVector2D> ring(std::initializer_list<QPair<float, float>> points)
{
    QVector<QVector2D> result;
    for (const auto &p : points)
        result.append(QVector2D(p.first, p.second));
    return result;
}

QVector3D triangleNormal(const Poly3DMesh &mesh, int triangle)
{
    const QVector3D a = mesh.positions.at(int(mesh.indices.at(triangle * 3)));
    const QVector3D b = mesh.positions.at(int(mesh.indices.at(triangle * 3 + 1)));
    const QVector3D c = mesh.positions.at(int(mesh.indices.at(triangle * 3 + 2)));
    return QVector3D::crossProduct(b - a, c - a).normalized();
}

double triangleAreaSum(const Poly3DMesh &mesh)
{
    double sum = 0.0;
    for (int t = 0; t * 3 < mesh.indices.size(); ++t) {
        const QVector3D a = mesh.positions.at(int(mesh.indices.at(t * 3)));
        const QVector3D b = mesh.positions.at(int(mesh.indices.at(t * 3 + 1)));
        const QVector3D c = mesh.positions.at(int(mesh.indices.at(t * 3 + 2)));
        sum += 0.5 * double(QVector3D::crossProduct(b - a, c - a).length());
    }
    return sum;
}

// Every triangle faces the plane's normal, which is the whole point of
// normalising winding in C++ instead of demanding it of the caller.
bool allTrianglesFaceTheNormal(const Poly3DMesh &mesh)
{
    for (int t = 0; t * 3 < mesh.indices.size(); ++t) {
        if (QVector3D::dotProduct(triangleNormal(mesh, t), mesh.normal) < 0.99f)
            return false;
    }
    return true;
}

const QVector<QVector2D> square = ring({{0, 0}, {100, 0}, {100, 100}, {0, 100}});

// An L: concave, so a fan from any single vertex would leave the notch filled.
const QVector<QVector2D> lShape = ring({{0, 0}, {100, 0}, {100, 40},
                                        {40, 40}, {40, 100}, {0, 100}});

// Whether two flat indices are neighbours on the same input ring, worked out
// from the ring sizes alone. Deliberately not the builder's own routine: an
// independent answer is the only kind worth checking against.
bool expectRingEdge(const QVector<int> &ringSizes, int i, int j)
{
    int start = 0;
    for (int size : ringSizes) {
        if (i >= start && j >= start && i < start + size && j < start + size) {
            const int diff = qAbs(i - j);
            return diff == 1 || diff == size - 1;
        }
        start += size;
    }
    return false;
}

// Reads back what a triangle's three edge codes say: the per-triangle
// suppression vector, and whether the codes are the barycentric basis under it.
bool readEdgeCodes(const Poly3DMesh &mesh, int triangle, QVector3D *suppressOut)
{
    const QVector3D c0 = mesh.edgeCodes.at(triangle * 3);
    const QVector3D c1 = mesh.edgeCodes.at(triangle * 3 + 1);
    const QVector3D c2 = mesh.edgeCodes.at(triangle * 3 + 2);

    const QVector3D suppress = c0 - QVector3D(1, 0, 0);
    if (c1 - QVector3D(0, 1, 0) != suppress || c2 - QVector3D(0, 0, 1) != suppress)
        return false;
    for (int axis = 0; axis < 3; ++axis) {
        const float value = suppress[axis];
        if (value != 0.0f && value != kPoly3DEdgeSuppressOffset
            && value != 2.0f * kPoly3DEdgeSuppressOffset)
            return false;
    }
    *suppressOut = suppress;
    return true;
}

// The kind of the edge opposite corner `axis` of a triangle, read back out of
// the lift the barycentric component carries.
Poly3DEdgeKind edgeKind(const Poly3DMesh &mesh, int triangle, int axis)
{
    const QVector3D suppress = mesh.edgeCodes.at(triangle * 3) - QVector3D(1, 0, 0);
    return Poly3DEdgeKind(qRound(suppress[axis] / kPoly3DEdgeSuppressOffset));
}

int countEdgeKind(const Poly3DMesh &mesh, Poly3DEdgeKind kind)
{
    int count = 0;
    for (int t = 0; t * 3 < mesh.indices.size(); ++t) {
        for (int axis = 0; axis < 3; ++axis)
            if (edgeKind(mesh, t, axis) == kind)
                ++count;
    }
    return count;
}

// The winding of a triangle judged against the normals its own vertices carry -
// which is the only question that matters once every surface has its own.
bool everyTriangleFacesItsOwnNormal(const Poly3DMesh &mesh)
{
    for (int t = 0; t * 3 < mesh.indices.size(); ++t) {
        const QVector3D geometric = triangleNormal(mesh, t);
        for (int corner = 0; corner < 3; ++corner) {
            const QVector3D stored =
                mesh.normals.at(int(mesh.indices.at(t * 3 + corner)));
            if (QVector3D::dotProduct(geometric, stored) < 0.99f)
                return false;
        }
    }
    return true;
}

bool sameMesh(const Poly3DMesh &a, const Poly3DMesh &b)
{
    return a.positions == b.positions && a.normals == b.normals
           && a.indices == b.indices && a.edgeCodes == b.edgeCodes
           && a.normal == b.normal && a.minBounds == b.minBounds
           && a.maxBounds == b.maxBounds;
}

QVariantList asVariantRing(const QVector<QVector2D> &points)
{
    QVariantList list;
    for (const QVector2D &p : points)
        list.append(QVariant::fromValue(p));
    return list;
}

} // namespace

class TstPoly3DGeometry : public QObject
{
    Q_OBJECT

private slots:

    void convexRingSharesItsVertices()
    {
        const Poly3DMesh mesh = buildPoly3DMesh({square}, Poly3dGeometry::XZ);

        // Indexed and shared: four corners, two triangles, no duplicates.
        QCOMPARE(mesh.positions.size(), 4);
        QCOMPARE(mesh.indices.size(), 6);
        QCOMPARE(mesh.normal, QVector3D(0, 1, 0));
        QVERIFY(allTrianglesFaceTheNormal(mesh));
        QVERIFY(qAbs(triangleAreaSum(mesh) - 100.0 * 100.0) < 1e-3);
    }

    // The ring closes implicitly, so a repeated last point is not a vertex.
    void closingPointIsDropped()
    {
        QVector<QVector2D> closed = square;
        closed.append(square.first());

        const Poly3DMesh mesh = buildPoly3DMesh({closed}, Poly3dGeometry::XZ);

        QCOMPARE(mesh.positions.size(), 4);
        QCOMPARE(mesh.indices.size(), 6);
    }

    // THE TRIANGULATOR. A fan would cover the notch of the L; earcut must not.
    void concaveRingKeepsItsNotchEmpty()
    {
        const Poly3DMesh mesh = buildPoly3DMesh({lShape}, Poly3dGeometry::XZ);

        QCOMPARE(mesh.positions.size(), 6);
        QCOMPARE(mesh.indices.size(), 12);  // n - 2 triangles
        QVERIFY(allTrianglesFaceTheNormal(mesh));

        // 100x100 minus the 60x60 corner that is not part of the L.
        const double expected = 100.0 * 100.0 - 60.0 * 60.0;
        QVERIFY2(qAbs(triangleAreaSum(mesh) - expected) < 1e-3,
                 qPrintable(QString("covered area %1, expected %2 - the notch "
                                    "got filled").arg(triangleAreaSum(mesh)).arg(expected)));
    }

    void holeIsCutOutOfTheFill()
    {
        const QVector<QVector2D> hole = ring({{25, 25}, {75, 25}, {75, 75}, {25, 75}});

        const Poly3DMesh mesh = buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ);

        QCOMPARE(mesh.positions.size(), 8);  // outer ring plus the hole ring
        QVERIFY(mesh.indices.size() % 3 == 0);
        QVERIFY(allTrianglesFaceTheNormal(mesh));

        const double expected = 100.0 * 100.0 - 50.0 * 50.0;
        QVERIFY2(qAbs(triangleAreaSum(mesh) - expected) < 1e-3,
                 qPrintable(QString("covered area %1, expected %2 - the hole "
                                    "was not cut").arg(triangleAreaSum(mesh)).arg(expected)));
    }

    // Winding is normalised here, not demanded of the caller: both spellings
    // of the same square must come out facing the same way.
    void windingIsNormalised_data()
    {
        QTest::addColumn<bool>("reversed");
        QTest::newRow("counter-clockwise input") << false;
        QTest::newRow("clockwise input") << true;
    }

    void windingIsNormalised()
    {
        QFETCH(bool, reversed);

        QVector<QVector2D> outer = lShape;
        if (reversed)
            std::reverse(outer.begin(), outer.end());

        const Poly3DMesh mesh = buildPoly3DMesh({outer}, Poly3dGeometry::XZ);

        QCOMPARE(mesh.indices.size(), 12);
        QVERIFY2(allTrianglesFaceTheNormal(mesh),
                 "a triangle faces away from the plane normal - the polygon "
                 "would be invisible from the side it is meant to be seen from");
    }

    // A hole handed over with the same winding as the outer ring is still a
    // hole, not a second island.
    void holeWindingIsNormalisedToo()
    {
        QVector<QVector2D> hole = ring({{25, 25}, {75, 25}, {75, 75}, {25, 75}});
        std::reverse(hole.begin(), hole.end());

        const Poly3DMesh mesh = buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ);

        QVERIFY(allTrianglesFaceTheNormal(mesh));
        QVERIFY(qAbs(triangleAreaSum(mesh) - (100.0 * 100.0 - 50.0 * 50.0)) < 1e-3);
    }

    // plane is pure vertex mapping: same ring, same triangles, permuted axes.
    void planeMapsTheComponents_data()
    {
        QTest::addColumn<int>("plane");
        QTest::addColumn<QVector3D>("firstPosition");
        QTest::addColumn<QVector3D>("normal");

        QTest::newRow("XZ") << int(Poly3dGeometry::XZ)
                            << QVector3D(100, 0, 0) << QVector3D(0, 1, 0);
        QTest::newRow("XY") << int(Poly3dGeometry::XY)
                            << QVector3D(100, 0, 0) << QVector3D(0, 0, 1);
        QTest::newRow("YZ") << int(Poly3dGeometry::YZ)
                            << QVector3D(0, 100, 0) << QVector3D(1, 0, 0);
    }

    void planeMapsTheComponents()
    {
        QFETCH(int, plane);
        QFETCH(QVector3D, firstPosition);
        QFETCH(QVector3D, normal);

        const Poly3DMesh mesh =
            buildPoly3DMesh({square}, Poly3dGeometry::Plane(plane));

        QCOMPARE(mesh.positions.size(), 4);
        QCOMPARE(mesh.normal, normal);
        // (100, 0) is the second point of the ring; it lands on the first
        // mapped axis whatever the plane is.
        QCOMPARE(mesh.positions.at(1), firstPosition);
        QVERIFY2(allTrianglesFaceTheNormal(mesh),
                 "the XZ mapping is left-handed against +Y - a plane whose "
                 "triangles are not flipped for it faces the wrong way");
    }

    void boundsSpanTheRing()
    {
        const Poly3DMesh mesh = buildPoly3DMesh({square}, Poly3dGeometry::XZ);

        QCOMPARE(mesh.minBounds, QVector3D(0, 0, 0));
        QCOMPARE(mesh.maxBounds, QVector3D(100, 0, 100));
    }

    // Degenerate input is content, not a crash: empty mesh, one warning.
    void degenerateInputDrawsNothing_data()
    {
        QTest::addColumn<QVector<QVector2D>>("outer");

        QTest::newRow("empty") << QVector<QVector2D>();
        QTest::newRow("one point") << ring({{0, 0}});
        QTest::newRow("two points") << ring({{0, 0}, {10, 10}});
        QTest::newRow("closed triangle of two distinct points")
            << ring({{0, 0}, {10, 10}, {0, 0}});
        QTest::newRow("all collinear") << ring({{0, 0}, {10, 0}, {20, 0}, {30, 0}});
        QTest::newRow("all the same point")
            << ring({{5, 5}, {5, 5}, {5, 5}, {5, 5}});
        QTest::newRow("not a number")
            << ring({{0, 0}, {100, 0}, {qQNaN(), 100}});
        QTest::newRow("infinite")
            << ring({{0, 0}, {100, 0}, {qInf(), 100}});
    }

    void degenerateInputDrawsNothing()
    {
        QFETCH(QVector<QVector2D>, outer);

        QTest::ignoreMessage(QtWarningMsg, QRegularExpression("poly3d:"));
        const Poly3DMesh mesh = buildPoly3DMesh({outer}, Poly3dGeometry::XZ);

        QVERIFY(mesh.isEmpty());
        QVERIFY(mesh.positions.isEmpty());
        QCOMPARE(mesh.minBounds, QVector3D());
        QCOMPARE(mesh.maxBounds, QVector3D());
    }

    // A bad hole must not take the polygon down with it.
    void aDegenerateHoleIsIgnoredNotFatal()
    {
        const QVector<QVector2D> flatHole = ring({{10, 10}, {20, 10}, {30, 10}});

        QTest::ignoreMessage(QtWarningMsg, QRegularExpression("poly3d: hole 0"));
        const Poly3DMesh mesh = buildPoly3DMesh({square, flatHole}, Poly3dGeometry::XZ);

        QCOMPARE(mesh.positions.size(), 4);
        QVERIFY(qAbs(triangleAreaSum(mesh) - 100.0 * 100.0) < 1e-3);
    }

    // The point spellings QML actually hands over - a vector2d, and the plain
    // {x, y} object a point survives as once it has been through JS or JSON.
    void ringReaderTakesEveryPointSpelling()
    {
        QVariantMap asObject;
        asObject["x"] = 100.0;
        asObject["y"] = 0.0;

        const QVariantList points = {
            QVariant::fromValue(QVector2D(0, 0)),
            asObject,
            QVariant(QPointF(100, 100)),
            QVariant(QVariantList{0.0, 100.0})
        };

        QVector<QVector2D> parsed;
        QVERIFY(poly3dRingFromVariant(points, &parsed));
        QCOMPARE(parsed, square);
    }

    void ringReaderRejectsNonsense()
    {
        QTest::ignoreMessage(QtWarningMsg, QRegularExpression("unusable vertex"));

        QVector<QVector2D> parsed;
        QVERIFY(!poly3dRingFromVariant({QStringLiteral("over there")}, &parsed));
        QVERIFY(parsed.isEmpty());
    }

    // ===== The wireframe channel (issue #183, P3) =====
    //
    // What the shader reads is decided here, in the one place that still knows
    // which points came from which ring. Once the triangles are on their own,
    // a diagonal and a polygon edge are indistinguishable.

    void everyCornerCarriesItsBarycentricCoordinate()
    {
        const Poly3DMesh mesh = buildPoly3DMesh({lShape}, Poly3dGeometry::XZ);

        QCOMPARE(mesh.edgeCodes.size(), mesh.indices.size());
        for (int t = 0; t * 3 < mesh.indices.size(); ++t) {
            QVector3D suppress;
            QVERIFY2(readEdgeCodes(mesh, t, &suppress),
                     qPrintable(QStringLiteral("triangle %1 does not carry the barycentric basis "
                                               "under one shared per-triangle lift").arg(t)));
        }
    }

    // A square is two triangles across one diagonal, which is the smallest case
    // where "ring edge" and "edge the triangulator invented" both occur.
    void theDiagonalOfASquareIsTheOnlyInteriorEdge()
    {
        const Poly3DMesh mesh = buildPoly3DMesh({square}, Poly3dGeometry::XZ);
        QCOMPARE(mesh.indices.size(), 6);

        int interiorEdges = 0;
        for (int t = 0; t < 2; ++t) {
            QVector3D suppress;
            QVERIFY(readEdgeCodes(mesh, t, &suppress));
            for (int axis = 0; axis < 3; ++axis)
                if (suppress[axis] != 0.0f)
                    ++interiorEdges;
        }

        // One per triangle: they share the diagonal, so each hides it once.
        QCOMPARE(interiorEdges, 2);
    }

    void ringEdgesAndDiagonalsAreToldApart()
    {
        const Poly3DMesh mesh = buildPoly3DMesh({lShape}, Poly3dGeometry::XZ);
        const QVector<int> ringSizes = {int(lShape.size())};

        for (int t = 0; t * 3 < mesh.indices.size(); ++t) {
            QVector3D suppress;
            QVERIFY(readEdgeCodes(mesh, t, &suppress));

            const int i0 = int(mesh.indices.at(t * 3));
            const int i1 = int(mesh.indices.at(t * 3 + 1));
            const int i2 = int(mesh.indices.at(t * 3 + 2));

            // Component n falls to zero along the edge opposite corner n, so
            // that is the edge whose nature component n has to reflect.
            const bool edges[3] = {expectRingEdge(ringSizes, i1, i2),
                                   expectRingEdge(ringSizes, i2, i0),
                                   expectRingEdge(ringSizes, i0, i1)};
            for (int axis = 0; axis < 3; ++axis) {
                const bool suppressed = suppress[axis] != 0.0f;
                QVERIFY2(suppressed != edges[axis],
                         qPrintable(QStringLiteral("triangle %1, component %2: the edge is %3 but "
                                                   "the code says %4")
                                        .arg(t).arg(axis)
                                        .arg(edges[axis] ? "on the ring" : "a diagonal")
                                        .arg(suppressed ? "diagonal" : "on the ring")));
            }
        }
    }

    // A hole's rim is as much a polygon edge as the outer ring is, including the
    // bridge earcut runs between the two - which must not be mistaken for one.
    void holeRimsCountAsRingEdges()
    {
        const QVector<QVector2D> hole = ring({{60, 60}, {80, 60}, {80, 80}, {60, 80}});
        const Poly3DMesh mesh = buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ);
        const QVector<int> ringSizes = {int(square.size()), int(hole.size())};

        int holeRimEdges = 0;
        for (int t = 0; t * 3 < mesh.indices.size(); ++t) {
            QVector3D suppress;
            QVERIFY(readEdgeCodes(mesh, t, &suppress));

            const int corner[3] = {int(mesh.indices.at(t * 3)), int(mesh.indices.at(t * 3 + 1)),
                                   int(mesh.indices.at(t * 3 + 2))};
            for (int axis = 0; axis < 3; ++axis) {
                const int a = corner[(axis + 1) % 3];
                const int b = corner[(axis + 2) % 3];
                const bool isRing = expectRingEdge(ringSizes, a, b);
                QVERIFY(isRing == (suppress[axis] == 0.0f));
                if (isRing && a >= square.size() && b >= square.size())
                    ++holeRimEdges;
            }
        }

        // All four sides of the hole, each drawn from the one triangle that
        // borders it.
        QCOMPARE(holeRimEdges, 4);
    }

    // ===== The two layouts (D2) =====

    void theBufferUpgradesForEdgesAndNeverGoesBack()
    {
        Poly3dGeometry geometry;
        QVariantList points;
        for (const QVector2D &p : square)
            points.append(QVariant::fromValue(p));
        geometry.setVertices(points);

        // Lean by default: indexed, shared, position + normal.
        QVERIFY(!geometry.hasEdgeAttributes());
        QCOMPARE(geometry.stride(), 6 * int(sizeof(float)));
        QCOMPARE(geometry.vertexData().size(), 4 * 6 * int(sizeof(float)));
        QCOMPARE(geometry.indexData().size(), 6 * int(sizeof(quint32)));

        geometry.setShowEdges(true);

        // Wireframe: unshared, no index buffer, one vertex per corner.
        QVERIFY(geometry.hasEdgeAttributes());
        QCOMPARE(geometry.stride(), 9 * int(sizeof(float)));
        QCOMPARE(geometry.vertexData().size(), 6 * 9 * int(sizeof(float)));
        QVERIFY(geometry.indexData().isEmpty());

        // Switching edges back off must not rebuild: that is what makes
        // binding showEdges to a hover state affordable.
        geometry.setShowEdges(false);
        QVERIFY(geometry.hasEdgeAttributes());
        QCOMPARE(geometry.stride(), 9 * int(sizeof(float)));
        QCOMPARE(geometry.vertexData().size(), 6 * 9 * int(sizeof(float)));
    }

    // The silent-nothing case: asking for triangulation lines while nothing ever
    // built the channel to draw them from must say so, rather than look like a
    // mistake in the ring.
    void trianglesWithoutTheChannelWarn()
    {
        Poly3dGeometry geometry;
        QTest::ignoreMessage(QtWarningMsg,
                             QRegularExpression("edgeMode Triangles was asked for"));
        geometry.setEdgeMode(Poly3dGeometry::Triangles);
        QCoreApplication::processEvents();
    }

    // ... and it must not fire on the ordinary spelling, whichever order the two
    // properties happen to be written in. QML applies them in file order, so the
    // check has to wait for the turn of the event loop to be over.
    void trianglesWithTheChannelStayQuiet()
    {
        Poly3dGeometry geometry;
        geometry.setEdgeMode(Poly3dGeometry::Triangles);
        geometry.setShowEdges(true);
        QCoreApplication::processEvents();
        QVERIFY(geometry.hasEdgeAttributes());
    }

    // ===== extrude (issue #183, P4) =====

    // The whole point of the phase: extrude 0 has to be the flat area it always
    // was, not "the prism code with a height of nothing".
    void extrudeZeroIsExactlyTheFlatMesh_data()
    {
        QTest::addColumn<float>("extrude");
        QTest::newRow("explicit zero") << 0.0f;
        // A negative height has no meaning, and inventing one - a prism growing
        // the other way - would be a second thing to explain. It reads as flat.
        QTest::newRow("negative") << -40.0f;
    }

    void extrudeZeroIsExactlyTheFlatMesh()
    {
        QFETCH(float, extrude);

        const QVector<QVector2D> hole = ring({{25, 25}, {75, 25}, {75, 75}, {25, 75}});
        const Poly3DMesh flat = buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ);
        const Poly3DMesh same = buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ, extrude);

        QVERIFY2(sameMesh(flat, same),
                 "extrude 0 changed the mesh - the flat polygon is meant to come "
                 "out of the builder untouched, down to the vertex order");
    }

    // ... and the buffers it uploads have to be untouched too, including after a
    // round trip through a real extrusion.
    void extrudeRoundTripRestoresTheFlatBuffers()
    {
        Poly3dGeometry geometry;
        geometry.setVertices(asVariantRing(square));
        geometry.setShowEdges(true);

        const QByteArray vertexData = geometry.vertexData();
        const QByteArray indexData = geometry.indexData();
        QVERIFY(!vertexData.isEmpty());

        geometry.setExtrude(40.0f);
        QVERIFY(geometry.vertexData() != vertexData);

        geometry.setExtrude(0.0f);
        QCOMPARE(geometry.vertexData(), vertexData);
        QCOMPARE(geometry.indexData(), indexData);
    }

    // A square prism: two caps of two triangles each, four walls of two.
    void extrudeAddsWallsAndACap()
    {
        const Poly3DMesh mesh = buildPoly3DMesh({square}, Poly3dGeometry::XZ, 30.0f);

        // Nothing is shared between the surfaces: base and top face opposite
        // ways, and two walls meeting at a corner face different ways again.
        QCOMPARE(mesh.positions.size(), 2 * 4 + 4 * 4);
        QCOMPARE(mesh.normals.size(), mesh.positions.size());
        QCOMPARE(mesh.indices.size(), (2 * 2 + 4 * 2) * 3);
        QCOMPARE(mesh.edgeCodes.size(), mesh.indices.size());
        QVERIFY2(everyTriangleFacesItsOwnNormal(mesh),
                 "a triangle is wound against the normal its vertices carry - it "
                 "would be lit from the wrong side, or culled away");

        // Base down, top up, and the walls neither.
        int down = 0, up = 0, sideways = 0;
        for (const QVector3D &n : mesh.normals) {
            const float alongPlane = QVector3D::dotProduct(n, mesh.normal);
            if (alongPlane > 0.99f) ++up;
            else if (alongPlane < -0.99f) ++down;
            else if (qAbs(alongPlane) < 0.01f) ++sideways;
        }
        QCOMPARE(down, 4);
        QCOMPARE(up, 4);
        QCOMPARE(sideways, 16);

        // The solid is closed: 2 x 100x100 of cap plus 4 x 100x30 of wall.
        const double expected = 2.0 * 100.0 * 100.0 + 4.0 * 100.0 * 30.0;
        QVERIFY2(qAbs(triangleAreaSum(mesh) - expected) < 1e-3,
                 qPrintable(QString("surface area %1, expected %2")
                                .arg(triangleAreaSum(mesh)).arg(expected)));
    }

    // Toon shading reads a surface by its facets, so a wall must not borrow its
    // neighbour's normal - a hexagonal column has to stay six flat faces.
    void wallsAreFacetedNotSmoothed()
    {
        QVector<QVector2D> hexagon;
        for (int i = 0; i < 6; ++i) {
            const double a = i * M_PI / 3.0;
            hexagon.append(QVector2D(float(80.0 * std::cos(a)), float(80.0 * std::sin(a))));
        }

        const Poly3DMesh mesh = buildPoly3DMesh({hexagon}, Poly3dGeometry::XZ, 50.0f);

        // Every wall quad's four vertices share one normal, and no two walls
        // share theirs: six walls, six distinct sideways normals.
        QVector<QVector3D> wallNormals;
        for (int i = 2 * 6; i < mesh.normals.size(); i += 4) {
            const QVector3D n = mesh.normals.at(i);
            for (int k = 1; k < 4; ++k)
                QCOMPARE(mesh.normals.at(i + k), n);
            for (const QVector3D &seen : wallNormals) {
                QVERIFY2(QVector3D::dotProduct(seen, n) < 0.99f,
                         "two walls of the hexagon carry the same normal - the ring "
                         "has been smoothed, and the column will shade like a cylinder");
            }
            wallNormals.append(n);
        }
        QCOMPARE(wallNormals.size(), 6);
    }

    // Outer walls face away from the solid; a hole's walls face into the hole.
    void wallsFaceOutwardAndHoleWallsFaceIn()
    {
        const QVector<QVector2D> hole = ring({{40, 40}, {60, 40}, {60, 60}, {40, 60}});
        const Poly3DMesh mesh = buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ, 20.0f);

        // Both rings are centred on the same point here, which is what lets one
        // comparison serve for "away from it" and "towards it".
        const QVector3D centre(50, 0, 50);

        const int capVertices = 2 * (square.size() + hole.size());
        int outerWalls = 0, holeWalls = 0;
        for (int i = capVertices; i < mesh.positions.size(); i += 4) {
            // The quad's own midpoint, at the base height so the comparison is
            // in the plane rather than up the wall.
            QVector3D mid = mesh.positions.at(i) + mesh.positions.at(i + 1);
            mid *= 0.5f;
            const QVector3D n = mesh.normals.at(i);

            const bool onHole = i >= capVertices + 4 * square.size();
            if (onHole) {
                // Facing the hole's centre means facing inwards.
                QVERIFY2(QVector3D::dotProduct(n, centre - mid) > 0.0f,
                         "a hole's wall faces away from the hole - the courtyard "
                         "would be inside out");
                ++holeWalls;
            } else {
                QVERIFY2(QVector3D::dotProduct(n, mid - centre) > 0.0f,
                         "an outer wall faces into the solid");
                ++outerWalls;
            }
        }
        QCOMPARE(outerWalls, 4);
        QCOMPARE(holeWalls, 4);
    }

    // A hole is extruded too: the ring becomes a building with a courtyard, not
    // a solid block with a lid.
    void holesGetWallsOfTheirOwn()
    {
        const QVector<QVector2D> hole = ring({{25, 25}, {75, 25}, {75, 75}, {25, 75}});

        const Poly3DMesh flat = buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ);
        const Poly3DMesh mesh = buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ, 10.0f);

        const int capTriangles = flat.indices.size() / 3;
        QCOMPARE(mesh.indices.size(), (2 * capTriangles + 8 * 2) * 3);
        QCOMPARE(mesh.positions.size(), 2 * 8 + 4 * 8);

        // Cap area is unchanged - the hole is still a hole - and the walls add
        // the outer skirt plus the courtyard's.
        const double caps = 2.0 * (100.0 * 100.0 - 50.0 * 50.0);
        const double walls = (4.0 * 100.0 + 4.0 * 50.0) * 10.0;
        QVERIFY2(qAbs(triangleAreaSum(mesh) - (caps + walls)) < 1e-3,
                 qPrintable(QString("surface area %1, expected %2 - the hole's walls "
                                    "are missing or the cap was filled in")
                                .arg(triangleAreaSum(mesh)).arg(caps + walls)));
    }

    void boundsIncludeTheExtrudedHeight()
    {
        const Poly3DMesh mesh = buildPoly3DMesh({square}, Poly3dGeometry::XZ, 45.0f);

        QCOMPARE(mesh.minBounds, QVector3D(0, 0, 0));
        QVERIFY2(mesh.maxBounds == QVector3D(100, 45, 100),
                 "the bounding box stops at the base plane - the shadow-map fit "
                 "would then slice through the solid");
    }

    void boundsFollowThePlane_data()
    {
        QTest::addColumn<int>("plane");
        QTest::addColumn<QVector3D>("maxBounds");

        QTest::newRow("XZ") << int(Poly3dGeometry::XZ) << QVector3D(100, 45, 100);
        QTest::newRow("XY") << int(Poly3dGeometry::XY) << QVector3D(100, 100, 45);
        QTest::newRow("YZ") << int(Poly3dGeometry::YZ) << QVector3D(45, 100, 100);
    }

    void boundsFollowThePlane()
    {
        QFETCH(int, plane);
        QFETCH(QVector3D, maxBounds);

        const Poly3DMesh mesh =
            buildPoly3DMesh({square}, Poly3dGeometry::Plane(plane), 45.0f);

        QCOMPARE(mesh.maxBounds, maxBounds);
        QVERIFY2(everyTriangleFacesItsOwnNormal(mesh),
                 "the wall winding does not follow the plane's handedness");
    }

    // The edge flags are what makes an extruded polygon's border read at the
    // same weight as a Box3D's: a line two surfaces share is drawn at half
    // width from each side, and only a rim with nothing on the other side is
    // laid down whole.
    void extrudingTurnsRimsIntoSeams()
    {
        const Poly3DMesh flat = buildPoly3DMesh({square}, Poly3dGeometry::XZ);
        const Poly3DMesh prism = buildPoly3DMesh({square}, Poly3dGeometry::XZ, 30.0f);

        // Flat: the four sides of the square are rims, the shared diagonal is
        // counted once from each triangle.
        QCOMPARE(countEdgeKind(flat, Poly3DEdgeKind::Rim), 4);
        QCOMPARE(countEdgeKind(flat, Poly3DEdgeKind::Diagonal), 2);
        QCOMPARE(countEdgeKind(flat, Poly3DEdgeKind::Seam), 0);

        // Extruded: nothing is a rim any more. Every cap edge that was one is
        // now the seam with a wall, and the walls bring their own.
        QVERIFY2(countEdgeKind(prism, Poly3DEdgeKind::Rim) == 0,
                 "an extruded polygon still marks an edge as a rim - that edge "
                 "would be drawn at full width from one side and half from the "
                 "other, and come out heavier than the same edge on a Box3D");

        // Per triangle: the two caps contribute 4 seams (the square's sides,
        // once each) and 2 diagonals; each of the four wall quads contributes 4
        // seams and 2 diagonals.
        QCOMPARE(countEdgeKind(prism, Poly3DEdgeKind::Seam), 2 * 4 + 4 * 4);
        QCOMPARE(countEdgeKind(prism, Poly3DEdgeKind::Diagonal), 2 * 2 + 4 * 2);
    }

    // Each wall quad is one seam per side and one diagonal across it.
    void everyWallQuadIsFourSeamsAndOneDiagonal()
    {
        const Poly3DMesh mesh = buildPoly3DMesh({lShape}, Poly3dGeometry::XZ, 25.0f);

        const int capTriangles = 2 * (lShape.size() - 2);
        int quad = 0;
        for (int t = capTriangles; t * 3 < mesh.indices.size(); t += 2, ++quad) {
            int seams = 0, diagonals = 0;
            for (int half = 0; half < 2; ++half) {
                for (int axis = 0; axis < 3; ++axis) {
                    switch (edgeKind(mesh, t + half, axis)) {
                    case Poly3DEdgeKind::Seam: ++seams; break;
                    case Poly3DEdgeKind::Diagonal: ++diagonals; break;
                    case Poly3DEdgeKind::Rim: QFAIL("a wall carries a rim edge"); break;
                    }
                }
            }
            QVERIFY2(seams == 4 && diagonals == 2,
                     qPrintable(QStringLiteral("wall quad %1 has %2 seams and %3 "
                                               "diagonals, expected 4 and 2")
                                    .arg(quad).arg(seams).arg(diagonals)));
        }
        QCOMPARE(quad, int(lShape.size()));
    }

    // Both layouts have to survive the extrusion, and the upgrade-never-
    // downgrade rule still holds across it.
    void bothLayoutsCarryThePrism()
    {
        Poly3dGeometry geometry;
        geometry.setVertices(asVariantRing(square));
        geometry.setExtrude(20.0f);

        // Lean: indexed, one vertex per position.
        QVERIFY(!geometry.hasEdgeAttributes());
        QCOMPARE(geometry.stride(), 6 * int(sizeof(float)));
        QCOMPARE(geometry.vertexData().size(), 24 * 6 * int(sizeof(float)));
        QCOMPARE(geometry.indexData().size(), 36 * int(sizeof(quint32)));

        geometry.setShowEdges(true);

        // Wireframe: unshared, one vertex per corner of every triangle.
        QVERIFY(geometry.hasEdgeAttributes());
        QCOMPARE(geometry.stride(), 9 * int(sizeof(float)));
        QCOMPARE(geometry.vertexData().size(), 36 * 9 * int(sizeof(float)));
        QVERIFY(geometry.indexData().isEmpty());

        geometry.setShowEdges(false);
        QCOMPARE(geometry.stride(), 9 * int(sizeof(float)));
        QCOMPARE(geometry.vertexData().size(), 36 * 9 * int(sizeof(float)));
    }

    // A repeated point in the middle of a ring is not an area error, so it does
    // not stop the polygon - but the wall it would raise has no width and no
    // direction to face, so it is left out rather than emitted as NaN.
    void aZeroLengthRingEdgeRaisesNoWall()
    {
        const QVector<QVector2D> doubled = ring({{0, 0}, {100, 0}, {100, 0},
                                                 {100, 100}, {0, 100}});

        const Poly3DMesh mesh = buildPoly3DMesh({doubled}, Poly3dGeometry::XZ, 10.0f);

        for (const QVector3D &n : mesh.normals) {
            QVERIFY2(std::isfinite(n.x()) && std::isfinite(n.y()) && std::isfinite(n.z()),
                     "a zero-length ring edge produced a normal that is not a number");
        }
        // Five points, four of them raising a wall.
        QCOMPARE(mesh.positions.size(), 2 * 5 + 4 * 4);
    }

    // ===== surfaceOffset =====

    // The promise the default rests on: asking for no lift is not a translation
    // by zero, it is no translation, and the mesh comes out as it did before the
    // property existed.
    void surfaceOffsetZeroIsExactlyTheUnliftedMesh_data()
    {
        QTest::addColumn<float>("extrude");
        QTest::newRow("flat") << 0.0f;
        QTest::newRow("prism") << 30.0f;
    }

    void surfaceOffsetZeroIsExactlyTheUnliftedMesh()
    {
        QFETCH(float, extrude);

        const QVector<QVector2D> hole = ring({{25, 25}, {75, 25}, {75, 75}, {25, 75}});
        const Poly3DMesh plain = buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ, extrude);
        const Poly3DMesh same =
            buildPoly3DMesh({square, hole}, Poly3dGeometry::XZ, extrude, 0.0f);

        QVERIFY2(sameMesh(plain, same),
                 "surfaceOffset 0 changed the mesh - it is meant to be no "
                 "translation at all, down to the vertex order");
    }

    // Every plane lifts along its own normal, and only along that one.
    void surfaceOffsetSlidesAlongThePlaneNormal_data()
    {
        QTest::addColumn<int>("plane");
        QTest::newRow("XZ") << int(Poly3dGeometry::XZ);
        QTest::newRow("XY") << int(Poly3dGeometry::XY);
        QTest::newRow("YZ") << int(Poly3dGeometry::YZ);
    }

    void surfaceOffsetSlidesAlongThePlaneNormal()
    {
        QFETCH(int, plane);
        const float offset = 0.5f;

        const Poly3DMesh flat = buildPoly3DMesh({square}, Poly3dGeometry::Plane(plane));
        const Poly3DMesh lifted =
            buildPoly3DMesh({square}, Poly3dGeometry::Plane(plane), 0.0f, offset);

        QCOMPARE(lifted.positions.size(), flat.positions.size());
        const QVector3D expected = flat.normal * offset;
        for (int i = 0; i < flat.positions.size(); ++i)
            QCOMPARE(lifted.positions.at(i) - flat.positions.at(i), expected);

        // A translation is not a rotation: the shading has to be untouched, and
        // so does everything the edge shader reads.
        QCOMPARE(lifted.normals, flat.normals);
        QCOMPARE(lifted.indices, flat.indices);
        QCOMPARE(lifted.edgeCodes, flat.edgeCodes);
        QCOMPARE(lifted.normal, flat.normal);

        // Bounds move with the mesh, or the shadow frustum cuts through it.
        QCOMPARE(lifted.minBounds - flat.minBounds, expected);
        QCOMPARE(lifted.maxBounds - flat.maxBounds, expected);
    }

    // A negative offset is meaningful - it puts the polygon under whatever it
    // shares the plane with - unlike a negative extrude, which reads as flat.
    void surfaceOffsetTakesNegativeValues()
    {
        const Poly3DMesh flat = buildPoly3DMesh({square}, Poly3dGeometry::XZ);
        const Poly3DMesh sunk = buildPoly3DMesh({square}, Poly3dGeometry::XZ, 0.0f, -2.0f);

        for (int i = 0; i < flat.positions.size(); ++i)
            QCOMPARE(sunk.positions.at(i).y(), flat.positions.at(i).y() - 2.0f);
    }

    // The point of applying the lift last: extrude keeps measuring from the
    // ring's own plane, so a lifted prism is displaced, never resized.
    void surfaceOffsetLeavesTheExtrusionHeightAlone()
    {
        const float extrude = 45.0f;
        const float offset = 7.0f;

        const Poly3DMesh prism = buildPoly3DMesh({square}, Poly3dGeometry::XZ, extrude);
        const Poly3DMesh lifted =
            buildPoly3DMesh({square}, Poly3dGeometry::XZ, extrude, offset);

        // Same height, just higher up.
        QCOMPARE(lifted.maxBounds.y() - lifted.minBounds.y(),
                 prism.maxBounds.y() - prism.minBounds.y());
        QCOMPARE(lifted.minBounds.y(), prism.minBounds.y() + offset);
        QCOMPARE(lifted.maxBounds.y(), prism.maxBounds.y() + offset);

        // The base ring sits at the offset, not at the origin plane, and the cap
        // a full extrude above it - the whole solid moved as one.
        QCOMPARE(lifted.minBounds.y(), offset);
        QCOMPARE(lifted.maxBounds.y(), offset + extrude);

        // ... and the walls did not shear: every vertex moved by the same lift.
        QCOMPARE(lifted.positions.size(), prism.positions.size());
        for (int i = 0; i < prism.positions.size(); ++i)
            QCOMPARE(lifted.positions.at(i) - prism.positions.at(i),
                     QVector3D(0.0f, offset, 0.0f));
    }

    // Through the geometry class: the uploaded buffers follow the property, and
    // a round trip back to 0 restores them byte for byte.
    void surfaceOffsetRoundTripRestoresTheUnliftedBuffers()
    {
        Poly3dGeometry geometry;
        geometry.setVertices(asVariantRing(square));
        geometry.setShowEdges(true);

        const QByteArray vertexData = geometry.vertexData();
        QVERIFY(!vertexData.isEmpty());
        const QVector3D minBounds = geometry.boundsMin();

        geometry.setSurfaceOffset(0.5f);
        QVERIFY(geometry.vertexData() != vertexData);
        QCOMPARE(geometry.boundsMin().y(), minBounds.y() + 0.5f);

        geometry.setSurfaceOffset(0.0f);
        QCOMPARE(geometry.vertexData(), vertexData);
        QCOMPARE(geometry.boundsMin(), minBounds);
    }
};

QTEST_MAIN(TstPoly3DGeometry)
#include "tst_poly3dgeometry.moc"
