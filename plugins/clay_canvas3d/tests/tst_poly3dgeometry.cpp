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
        if (value != 0.0f && value != kPoly3DEdgeSuppressOffset)
            return false;
    }
    *suppressOut = suppress;
    return true;
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
};

QTEST_MAIN(TstPoly3DGeometry)
#include "tst_poly3dgeometry.moc"
