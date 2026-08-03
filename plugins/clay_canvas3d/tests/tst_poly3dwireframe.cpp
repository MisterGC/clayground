// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The early-warning system for the Poly3D wireframe attribute contract
// (issue #183, decision D3).
//
// Poly3DGeometry smuggles barycentric coordinates through TangentSemantic,
// which Qt is under no obligation to leave alone: it would be within its rights
// to normalise, orthogonalise or regenerate a tangent, and if a future Qt starts
// doing so the triangulation lines simply stop appearing. Nothing in a build log
// would say why.
//
// So this test renders a two-triangle square straight down the camera and looks
// at three pixels:
//
//   edgeMode: Triangles     the centre sits on the shared diagonal   -> dark
//                           a quarter of the way into a triangle     -> light
//   edgeMode: FaceBorders   the diagonal is suppressed, so the centre-> light
//                           the rim is still a ring edge             -> dark
//
// Every assertion is relative to the polygon's own lit fill, measured in the
// same frame, so tonemapping and light intensity cannot move the goalposts. A
// render that came out blank fails the "the polygon is actually there" guard
// before any of the edge assertions get a chance to pass for the wrong reason.

#include "poly3dgeometry.h"

#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QQuickItem>
#include <QQuickView>
#include <QTemporaryDir>
#include <QtQml/qqml.h>
#include <QTest>

namespace {

constexpr int kViewSize = 240;

// Magenta on purpose. The polygon is found by looking for pixels that are not
// the background, so the background must be a colour neither the white fill nor
// the black edges can be mistaken for - otherwise a polygon drawn entirely in
// edge colour would read as "nothing rendered" and blame the graphics device
// for what is really a broken attribute.
constexpr QRgb kBackground = qRgb(255, 0, 255);

// Relative luminance, 0..1. Only ever compared against the polygon's own fill,
// never against an absolute expectation.
double luminance(QRgb pixel)
{
    return (0.2126 * qRed(pixel) + 0.7152 * qGreen(pixel) + 0.0722 * qBlue(pixel)) / 255.0;
}

bool isBackground(QRgb pixel)
{
    return qAbs(qRed(pixel) - qRed(kBackground)) + qAbs(qGreen(pixel) - qGreen(kBackground))
               + qAbs(qBlue(pixel) - qBlue(kBackground))
           < 60;
}

QString shaderUrl(const char *fileName)
{
    return QUrl::fromLocalFile(QStringLiteral(POLY3D_SHADER_DIR "/") + QLatin1String(fileName))
        .toString();
}

// A square, four points, which earcut turns into exactly two triangles sharing
// one diagonal. The smallest shape in which "is the diagonal drawn?" is a
// question with a visible answer.
//
// With extrude above zero the same square becomes a prism, and the question
// changes: seen from straight above, its rim is no longer a rim but the seam
// where the top cap meets a wall. Both are lines the object's face borders
// include, and only the triangulation diagonal is not - which is the whole of
// what the second lift level encodes.
QString sceneSource(const QString &edgeMode, double extrude = 0.0)
{
    return QStringLiteral(R"(
import QtQuick
import QtQuick3D
import ClayCanvas3DTest

Item {
    View3D {
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: "#ff00ff"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.NoAA
            tonemapMode: SceneEnvironment.TonemapModeNone
        }

        // Straight down, orthographic: the square keeps its shape and the
        // sampled pixels mean what they say.
        OrthographicCamera { id: cam; position: Qt.vector3d(0, 200, 0); eulerRotation.x: -90 }
        DirectionalLight { eulerRotation.x: -90 }

        Model {
            geometry: Poly3DGeometry {
                vertices: [Qt.vector2d(-60, -60), Qt.vector2d(60, -60),
                           Qt.vector2d(60, 60), Qt.vector2d(-60, 60)]
                showEdges: true
                edgeMode: %1
                extrude: %4
            }
            materials: CustomMaterial {
                property color baseColor: "#ffffff"
                property bool useToonShading: false
                property bool showEdges: true
                property int edgeMode: %1
                property real edgeThickness: 4.0
                property real edgeColorFactor: 0.4
                property color edgeColor: "#ff000000"
                vertexShader: "%2"
                fragmentShader: "%3"
                shadingMode: CustomMaterial.Shaded
            }
        }
    }
}
)")
        .arg(edgeMode, shaderUrl("poly3d.vert"), shaderUrl("poly3d.frag"))
        .arg(extrude);
}

} // namespace

class TestPoly3DWireframe : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void trianglesShowTheDiagonal();
    void faceBordersHideTheDiagonal();
    void extrudedFaceBordersKeepTheCapRim();

private:
    // Renders one scene. Returns a null image and fills errorOut when the scene
    // could not be built or the window never came up - which has to be reported
    // as an error rather than silently sampled as "all black".
    QImage render(const QString &edgeMode, QString *errorOut, double extrude = 0.0);

    QTemporaryDir m_sceneDir;
};

void TestPoly3DWireframe::initTestCase()
{
    // The platform plugins without a GPU surface render a View3D as an empty
    // frame. Sampling that would let every "dark pixel" assertion pass for the
    // wrong reason, so say so and stop instead.
    const QString platform = QGuiApplication::platformName();
    if (platform == QLatin1String("offscreen") || platform == QLatin1String("minimal"))
        QSKIP("the Poly3D wireframe can only be checked against a real render - "
              "this platform plugin has no GPU surface and draws View3D content blank");

    qmlRegisterType<Poly3dGeometry>("ClayCanvas3DTest", 1, 0, "Poly3DGeometry");
    QVERIFY(m_sceneDir.isValid());
}

QImage TestPoly3DWireframe::render(const QString &edgeMode, QString *errorOut, double extrude)
{
    const QString name = edgeMode.mid(edgeMode.lastIndexOf(QLatin1Char('.')) + 1)
                         + (extrude > 0.0 ? QStringLiteral("_prism") : QString());
    const QString path = m_sceneDir.filePath(QStringLiteral("scene_%1.qml").arg(name));
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        *errorOut = QStringLiteral("could not write the scene to ") + path;
        return QImage();
    }
    file.write(sceneSource(edgeMode, extrude).toUtf8());
    file.close();

    QQuickView view;
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.setColor(QColor(kBackground));
    view.resize(kViewSize, kViewSize);
    view.setSource(QUrl::fromLocalFile(path));
    if (view.status() != QQuickView::Ready) {
        QStringList messages;
        for (const QQmlError &error : view.errors())
            messages << error.toString();
        *errorOut = QStringLiteral("scene would not build: ") + messages.join(QLatin1Char('\n'));
        return QImage();
    }

    view.show();
    if (!QTest::qWaitForWindowExposed(&view)) {
        *errorOut = QStringLiteral("the render window was never exposed - no window system?");
        return QImage();
    }

    // Qt Quick 3D loads shaders and uploads meshes on the frames it renders, so
    // the first grab is not the one to trust.
    QImage image;
    for (int frame = 0; frame < 3; ++frame) {
        QTest::qWait(30);
        image = view.grabWindow();
    }

    if (image.isNull()) {
        *errorOut = QStringLiteral("grabWindow() returned a null image");
        return QImage();
    }

    // A failing pixel assertion is hard to argue with in words. Point
    // CLAY_TEST_IMAGE_DIR at a directory to keep what was actually drawn.
    const QByteArray dumpDir = qgetenv("CLAY_TEST_IMAGE_DIR");
    if (!dumpDir.isEmpty()) {
        image.save(QString::fromLocal8Bit(dumpDir) + QStringLiteral("/poly3d_")
                   + name + QStringLiteral(".png"));
    }

    return image.convertToFormat(QImage::Format_RGB32);
}

// The polygon's silhouette against the clear colour, so the sample points follow
// the shape rather than a hand-computed projection.
static bool findPolygonBounds(const QImage &image, QRect *out)
{
    int minX = image.width(), minY = image.height(), maxX = -1, maxY = -1;
    for (int y = 0; y < image.height(); ++y) {
        for (int x = 0; x < image.width(); ++x) {
            if (isBackground(image.pixel(x, y)))
                continue;
            minX = qMin(minX, x); maxX = qMax(maxX, x);
            minY = qMin(minY, y); maxY = qMax(maxY, y);
        }
    }
    if (maxX < 0)
        return false;
    *out = QRect(QPoint(minX, minY), QPoint(maxX, maxY));
    return true;
}

void TestPoly3DWireframe::trianglesShowTheDiagonal()
{
    QString error;
    const QImage image = render(QStringLiteral("Poly3DGeometry.Triangles"), &error);
    QVERIFY2(!image.isNull(), qPrintable(error));

    QRect bounds;
    QVERIFY2(findPolygonBounds(image, &bounds),
             "nothing was drawn at all - every pixel is still the clear colour, so this run says "
             "nothing about the barycentric channel. Check that the renderer has a graphics "
             "device before reading anything into the edge assertions.");
    QVERIFY2(bounds.width() > kViewSize / 4 && bounds.height() > kViewSize / 4,
             qPrintable(QStringLiteral("the polygon covers only %1x%2 pixels of a %3x%3 view - "
                                       "too little to sample meaningfully")
                            .arg(bounds.width()).arg(bounds.height()).arg(kViewSize)));

    const QPoint centre = bounds.center();
    // A quarter of the way from the centre towards the top edge: clear of the
    // rim and clear of either diagonal.
    const QPoint inside(centre.x(), centre.y() - bounds.height() / 4);

    const double fill = luminance(image.pixel(inside));
    const double diagonal = luminance(image.pixel(centre));

    QVERIFY2(fill > 0.25,
             qPrintable(QStringLiteral(
                 "a quarter of the way into a triangle, well clear of any edge, the polygon "
                 "sampled at luminance %1 - that is not a lit fill. The likeliest cause is that "
                 "the edge shading has swallowed the whole surface, which is exactly what a "
                 "barycentric channel arriving as all zeroes looks like: every pixel then reads "
                 "as sitting on an edge. Check that Poly3DGeometry still writes the "
                 "TangentSemantic slot and that Qt still hands it to the shader unchanged. "
                 "Without this the diagonal assertion below would pass for the wrong reason.")
                            .arg(fill)));

    QVERIFY2(diagonal < 0.5 * fill,
             qPrintable(QStringLiteral(
                 "edgeMode: Triangles drew no line on the square's shared diagonal - centre "
                 "luminance %1 against a fill of %2. The barycentric coordinates Poly3DGeometry "
                 "writes into the TangentSemantic slot are not reaching the fragment shader "
                 "intact. Qt normalising, orthogonalising or regenerating the tangent attribute "
                 "is the expected cause (see D3 in the poly3d-wireframe groundwork); a Qt upgrade "
                 "is the expected trigger.")
                            .arg(diagonal).arg(fill)));
}

void TestPoly3DWireframe::faceBordersHideTheDiagonal()
{
    QString error;
    const QImage image = render(QStringLiteral("Poly3DGeometry.FaceBorders"), &error);
    QVERIFY2(!image.isNull(), qPrintable(error));

    QRect bounds;
    QVERIFY2(findPolygonBounds(image, &bounds),
             "nothing was drawn at all - every pixel is still the clear colour.");

    const QPoint centre = bounds.center();
    const QPoint inside(centre.x(), centre.y() - bounds.height() / 4);

    const double fill = luminance(image.pixel(inside));
    const double diagonal = luminance(image.pixel(centre));

    QVERIFY2(fill > 0.25,
             qPrintable(QStringLiteral(
                 "a quarter of the way into a triangle, well clear of any edge, the polygon "
                 "sampled at luminance %1 - that is not a lit fill. An all-zero barycentric "
                 "channel would do this: every pixel then reads as sitting on an edge and the "
                 "whole surface comes out in edge colour.")
                            .arg(fill)));

    QVERIFY2(diagonal > 0.85 * fill,
             qPrintable(QStringLiteral(
                 "edgeMode: FaceBorders darkened the square's centre - luminance %1 against a "
                 "fill of %2 - so the interior diagonal is being drawn when it should be "
                 "suppressed. The per-triangle edge lift Poly3DGeometry adds to the barycentric "
                 "channel is not surviving the trip to the fragment shader, or the shader's "
                 "offset constant no longer matches kPoly3DEdgeSuppressOffset.")
                            .arg(diagonal).arg(fill)));

    // The rim is a real ring edge and must still be drawn - otherwise
    // "FaceBorders hides the diagonal" would also be satisfied by an attribute
    // that carries nothing at all.
    double rimDarkest = 1.0;
    for (int y = bounds.top(); y <= bounds.top() + qMax(4, bounds.height() / 12); ++y)
        rimDarkest = qMin(rimDarkest, luminance(image.pixel(centre.x(), y)));

    QVERIFY2(rimDarkest < 0.5 * fill,
             qPrintable(QStringLiteral(
                 "edgeMode: FaceBorders drew no line along the polygon's rim either - darkest "
                 "luminance near the top edge was %1 against a fill of %2. With the diagonal "
                 "hidden and the rim missing, the barycentric channel is carrying nothing at "
                 "all rather than carrying it correctly.")
                            .arg(rimDarkest).arg(fill)));
}

// Extruding moves the square's rim from "nothing on the other side" to "the
// seam where the cap meets a wall". Both are face borders, so FaceBorders must
// still draw it - while the diagonal, which is neither, stays hidden. A shader
// that read the seam lift as an ordinary interior edge would pass the diagonal
// half of this and lose the outline entirely, and nothing else in the suite
// would notice.
void TestPoly3DWireframe::extrudedFaceBordersKeepTheCapRim()
{
    QString error;
    const QImage image = render(QStringLiteral("Poly3DGeometry.FaceBorders"), &error, 40.0);
    QVERIFY2(!image.isNull(), qPrintable(error));

    QRect bounds;
    QVERIFY2(findPolygonBounds(image, &bounds),
             "nothing was drawn at all - every pixel is still the clear colour.");

    const QPoint centre = bounds.center();
    const QPoint inside(centre.x(), centre.y() - bounds.height() / 4);

    const double fill = luminance(image.pixel(inside));
    const double diagonal = luminance(image.pixel(centre));

    QVERIFY2(fill > 0.25,
             qPrintable(QStringLiteral(
                 "a quarter of the way into the top cap the prism sampled at luminance %1 - "
                 "that is not a lit fill.")
                            .arg(fill)));

    QVERIFY2(diagonal > 0.85 * fill,
             qPrintable(QStringLiteral(
                 "edgeMode: FaceBorders drew the top cap's triangulation diagonal on an "
                 "extruded polygon - luminance %1 against a fill of %2. Extruding must not "
                 "turn an interior edge into a face border.")
                            .arg(diagonal).arg(fill)));

    double rimDarkest = 1.0;
    for (int y = bounds.top(); y <= bounds.top() + qMax(4, bounds.height() / 12); ++y)
        rimDarkest = qMin(rimDarkest, luminance(image.pixel(centre.x(), y)));

    QVERIFY2(rimDarkest < 0.5 * fill,
             qPrintable(QStringLiteral(
                 "the extruded polygon's cap rim is not drawn in FaceBorders mode - darkest "
                 "luminance near the top edge was %1 against a fill of %2. That rim is a seam "
                 "with the wall below it, and a seam is a face border: the shader is reading "
                 "the second lift level as an ordinary interior diagonal, so an extruded "
                 "Poly3D has lost its outline.")
                            .arg(rimDarkest).arg(fill)));
}

QTEST_MAIN(TestPoly3DWireframe)

#include "tst_poly3dwireframe.moc"
