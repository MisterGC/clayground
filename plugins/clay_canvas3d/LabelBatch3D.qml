// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D

/*!
    \qmltype LabelBatch3D
    \inqmlmodule Clayground.Canvas3D
    \brief Renders thousands of SDF text labels in a few instanced draw calls.

    LabelBatch3D draws very large sets of short text labels - tens of thousands -
    as instanced signed-distance-field glyphs, following deck.gl's TextLayer
    model: one GPU instance per glyph over a shared glyph atlas, so N labels cost
    one draw call for the glyphs (plus one for the optional pill backgrounds)
    rather than N items. Each label is a world-anchored point with its own text,
    color and size; glyphs stay crisp at any zoom because they are rendered from
    an SDF atlas, not a rasterized texture.

    LabelBatch3D is the mass-scale sibling of \l Label3D, not a replacement: rich
    per-label content, icons, leaders and per-frame billboard tracking stay
    Label3D's job. Reach for LabelBatch3D when you need many cheap, uniform text
    labels (data-point names, map features, particle tags).

    Feed it with the \l labels list or \l setLabels; move labels without
    re-shaping via \l updatePositionsBulk.

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    View3D {
        id: view
        LabelBatch3D {
            viewportSize: Qt.vector2d(view.width, view.height)
            sizeMode: LabelBatch3D.Screen
            halo: true
            labels: [
                { position: Qt.vector3d(0, 0, 0), text: "ALPHA", color: "#00d9ff", size: 22 },
                { position: Qt.vector3d(80, 0, 0), text: "BETA",  color: "#ff3366", size: 22 }
            ]
        }
    }
    \endqml

    \note In Screen size mode the shader needs the View3D pixel size, so bind
    \l viewportSize to the enclosing View3D's width/height.

    \sa Label3D, PathLabel3D, LineBatch3D
*/
Node {
    id: root

    /*!
        \qmlproperty enumeration LabelBatch3D::sizeMode
        \brief How label size is interpreted.

        \value LabelBatch3D.Screen Size is in screen pixels; labels keep a
               constant on-screen height and always face the camera (default).
        \value LabelBatch3D.World Size is in world units; labels scale with the
               scene and honor \l orientation.
    */
    enum SizeMode { Screen, World }

    /*!
        \qmlproperty enumeration LabelBatch3D::orientation
        \brief How World-sized labels are oriented (ignored in Screen mode).

        \value LabelBatch3D.Billboard The label faces the camera (default).
        \value LabelBatch3D.Flat The label lies flat in the world \c XZ ground
               plane (map/street style), read from above.
    */
    enum Orientation { Billboard, Flat }

    /*!
        \qmlproperty list LabelBatch3D::labels
        \brief Declarative list of labels.

        Each element is an object
        \c{{ position: Qt.vector3d, text: <string>, color: <color>,
        size: <real>, priority: <int>, opacity: <real> }}. Only \c position and
        \c text are required. For large generated sets prefer \l setLabels with a
        pre-built JS array.
    */
    property alias labels: _inst.labels

    /*!
        \qmlproperty int LabelBatch3D::sizeMode
        \brief The active size mode, one of the SizeMode values. Default Screen.
    */
    property int sizeMode: LabelBatch3D.Screen

    /*!
        \qmlproperty int LabelBatch3D::orientation
        \brief The active orientation, one of the Orientation values. Default
        Billboard. Only applies in World size mode.
    */
    property int orientation: LabelBatch3D.Billboard

    /*!
        \qmlproperty vector2d LabelBatch3D::viewportSize
        \brief The pixel size of the enclosing View3D.

        Required in Screen size mode to keep on-screen size constant. Bind it to
        \c{Qt.vector2d(view3D.width, view3D.height)}.
    */
    property vector2d viewportSize: Qt.vector2d(1920, 1080)

    /*!
        \qmlproperty QtObject LabelBatch3D::font
        \brief Grouped font config for the shared glyph atlas.

        \table
        \header \li Sub-property \li Meaning
        \row \li \c family   \li Font family (defaults to the platform monospace).
        \row \li \c weight   \li Font weight (e.g. 400 normal, 700 bold).
        \row \li \c baseSize \li Atlas rasterization size in px; higher is crisper
                                 when magnified but uses a larger atlas.
        \endtable

        \note One atlas is baked per LabelBatch3D instance; changing any font
        sub-property clears and re-bakes it.
    */
    property FontConfig font: FontConfig {}

    /*!
        \qmlproperty bool LabelBatch3D::halo
        \brief Whether glyphs get a halo outline for busy backgrounds. Default true.
    */
    property bool halo: true

    /*!
        \qmlproperty color LabelBatch3D::haloColor
        \brief Halo color (a dark halo is the robust default on bright and dark).
    */
    property color haloColor: "#000000"

    /*!
        \qmlproperty real LabelBatch3D::haloWidth
        \brief Halo band width in SDF units past the glyph edge (0..0.5). Default 0.18.
    */
    property real haloWidth: 0.18

    /*!
        \qmlproperty bool LabelBatch3D::pill
        \brief Whether a rounded background pill is drawn behind each label.
        Default false.
    */
    property bool pill: false

    /*!
        \qmlproperty color LabelBatch3D::pillColor
        \brief Pill fill color (dark semi-transparent default).
    */
    property color pillColor: "#cc16213e"

    /*!
        \qmlproperty real LabelBatch3D::pillPadding
        \brief Padding in base pixels between the text box and the pill edge.
    */
    property real pillPadding: 8

    /*!
        \qmlproperty real LabelBatch3D::pillRadius
        \brief Pill corner radius in base pixels.
    */
    property real pillRadius: 12

    /*!
        \qmlproperty real LabelBatch3D::batchOpacity
        \brief Batch-wide opacity multiplier (0..1). Default 1.

        Named \c batchOpacity rather than \c opacity so it does not shadow the
        inherited Node \c opacity (which would fade the whole node tree instead
        of feeding the label shaders).
    */
    property real batchOpacity: 1.0

    /*!
        \qmlproperty int LabelBatch3D::count
        \readonly
        \brief The number of labels currently in the batch.
    */
    property alias count: _inst.count

    /*!
        \qmlproperty int LabelBatch3D::glyphCount
        \readonly
        \brief The number of glyph instances currently drawn.
    */
    property alias glyphCount: _inst.glyphCount

    /*!
        \qmlproperty real LabelBatch3D::shapeMsLast
        \readonly
        \brief Wall-clock milliseconds spent shaping on the last \l setLabels.
    */
    property alias shapeMsLast: _inst.shapeMsLast

    /*!
        \qmlproperty int LabelBatch3D::atlasWidth
        \readonly
        \brief Current glyph-atlas width in texels.
    */
    property alias atlasWidth: _atlas.atlasWidth

    /*!
        \qmlproperty int LabelBatch3D::atlasHeight
        \readonly
        \brief Current glyph-atlas height in texels.
    */
    property alias atlasHeight: _atlas.atlasHeight

    // Grouped font config. Inline component so the sub-property set is statically
    // known (grouped assignment and qmllint both resolve it).
    component FontConfig: QtObject {
        property string family: Qt.platform.os === "osx" ? "Menlo" :
                                Qt.platform.os === "windows" ? "Consolas" : "monospace"
        property int weight: 700
        property int baseSize: 48
    }

    /*!
        \qmlmethod void LabelBatch3D::setLabels(list labels)
        \brief Replaces the batch contents from a JS array (fast bulk path).

        Each element is an object
        \c{{ position, text, color, size, priority, opacity }} (only \c position
        and \c text are required). Shaping runs once; \l shapeMsLast reports its
        cost.
    */
    function setLabels(labels) {
        _inst.labels = labels
    }

    /*!
        \qmlmethod void LabelBatch3D::updatePositionsBulk(ByteArray positions, int first)
        \brief Moves labels without re-shaping.

        \a positions is a packed float32 buffer with 3 floats per label
        (\c{x, y, z}) in label order, applied starting at label \a first. Only the
        anchors are rewritten (glyph layout and UVs are untouched), so animating
        moving labels stays cheap.
    */
    function updatePositionsBulk(positions, first) {
        _inst.updatePositionsBulk(positions, first === undefined ? 0 : first)
    }

    /*!
        \qmlmethod list LabelBatch3D::priorities()
        \brief Returns the per-label priority values (for a future declutter
        manager). Priorities are stored and read back but not yet acted on.
    */
    function priorities() {
        return _inst.priorities()
    }

    // Shared SDF glyph atlas: handed to both the shaper and the glyph material's
    // texture, so the shaper's UVs always match the committed atlas.
    LabelGlyphAtlas {
        id: _atlas
        fontFamily: root.font.family
        fontWeight: root.font.weight
        baseSize: root.font.baseSize
    }

    // Pill backgrounds (drawn first, behind the glyphs). deck.gl two-draw model.
    Model {
        id: _pillModel
        visible: root.pill
        castsShadows: false
        receivesShadows: false
        geometry: LineBatchGeometry {
            boundsMin: _inst.boundsMin
            boundsMax: _inst.boundsMax
        }
        instancing: LabelPillInstancing {
            source: _inst
        }
        materials: [
            CustomMaterial {
                shadingMode: CustomMaterial.Unshaded
                cullMode: Material.NoCulling
                sourceBlend: CustomMaterial.SrcAlpha
                destinationBlend: CustomMaterial.OneMinusSrcAlpha
                depthDrawMode: Material.NeverDepthDraw
                property vector2d viewportSize: root.viewportSize
                property real baseSize: _atlas.baseSize
                property real sizeMode: root.sizeMode
                property real orientationMode: root.orientation
                property color pillColor: root.pillColor
                property real pillRadius: root.pillRadius
                property real labelOpacity: root.batchOpacity
                vertexShader: "label_pill.vert"
                fragmentShader: "label_pill.frag"
            }
        ]
    }

    // Glyphs.
    Model {
        id: _glyphModel
        castsShadows: false
        receivesShadows: false
        geometry: LineBatchGeometry {
            boundsMin: _inst.boundsMin
            boundsMax: _inst.boundsMax
        }
        instancing: LabelBatchInstancing {
            id: _inst
            atlas: _atlas
            pillPadding: root.pillPadding
        }
        materials: [
            CustomMaterial {
                shadingMode: CustomMaterial.Unshaded
                cullMode: Material.NoCulling
                sourceBlend: CustomMaterial.SrcAlpha
                destinationBlend: CustomMaterial.OneMinusSrcAlpha
                depthDrawMode: Material.NeverDepthDraw
                property vector2d viewportSize: root.viewportSize
                property real baseSize: _atlas.baseSize
                property real sizeMode: root.sizeMode
                property real orientationMode: root.orientation
                property color haloColor: root.halo ? root.haloColor : Qt.rgba(0, 0, 0, 0)
                property real haloWidth: root.halo ? root.haloWidth : 0.0
                property real labelOpacity: root.batchOpacity
                property TextureInput atlasTex: TextureInput {
                    texture: Texture {
                        minFilter: Texture.Linear
                        magFilter: Texture.Linear
                        tilingModeHorizontal: Texture.ClampToEdge
                        tilingModeVertical: Texture.ClampToEdge
                        textureData: _atlas
                    }
                }
                vertexShader: "label_batch.vert"
                fragmentShader: "label_batch.frag"
            }
        ]
    }
}
