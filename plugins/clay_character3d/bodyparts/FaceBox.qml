import QtQuick
import QtQuick3D
import Clayground.Canvas3D

/*!
    \qmltype FaceBox
    \inqmlmodule Clayground.Character3D
    \inherits Model
    \brief A body-part box that draws a face into its own front surface.

    Geometrically a \l Box3D and nothing more - the same \c Box3DGeometry, the
    same outline, the same toon lighting, so it sits in a character next to
    ordinary body parts without looking like a different material. What it adds
    is a \l panel: eyes and brows, or a mouth, rendered into the front face by
    the fragment shader.

    The face costs no draw calls and no vertices. That is the point of it: the
    thirteen small boxes it replaces were about two thirds of a head's draw
    calls while contributing nothing to its silhouette, and an eye built as a
    cube shows its own side wall as soon as the camera moves off axis.

    Every measurement it takes is in the box's own frame - x from the centre
    line, y up from the box's floor - which is the frame \l Head publishes its
    anchors in, so a face and the things worn on it cannot disagree about where
    the eyes are.

    \sa Head, Box3D
*/
Model {
    id: root

    /*!
        \qmlproperty enumeration FaceBox::Panel
        \brief Which part of the face this box carries.

        \value FaceBox.None Nothing - an ordinary box.
        \value FaceBox.Eyes Both eyes, their lids and their brows.
        \value FaceBox.Mouth The lip line, the cavity and the corners.
    */
    enum Panel { None, Eyes, Mouth }

    /*! Which part of the face to draw. Defaults to none. */
    property int panel: FaceBox.None

    /*!
        How much of it to draw. 0 keeps only what survives being small - the
        whites of the eyes, the lash line, the lip - and drops the irises,
        the highlights, the brows and the mouth corners. It is a shader branch
        rather than a change of geometry, so switching it mid-shot cannot pop.
    */
    property int faceDetail: 1

    property real width: 1.0
    property real height: width
    property real depth: width

    // The BodyPart contract, restated rather than inherited: BodyPart is a
    // Box3D, and a Box3D's colour and shading are aliases into the inline
    // material it declares, so replacing that material to draw a face would
    // leave those aliases dangling. Same properties, same defaults, so this
    // drops into a character where a BodyPart was.
    property vector3d basePos: Qt.vector3d(0, 0, 0)
    property vector3d baseEuler: Qt.vector3d(0, 0, 0)
    position: basePos
    eulerRotation: baseEuler
    castsShadows: true
    pickable: true

    property alias color: _material.baseColor
    property alias scaledFace: _geometry.scaledFace
    property alias faceScale: _geometry.faceScale
    property alias bevel: _geometry.bevel
    property alias showEdges: _geometry.showEdges
    property alias edgeThickness: _geometry.edgeThickness
    property alias edgeColorFactor: _geometry.edgeColorFactor
    property alias edgeColor: _geometry.edgeColor
    property alias edgeMask: _geometry.edgeMask
    property alias useToonShading: _material.useToonShading

    readonly property int allEdges: Box3DGeometry.AllEdges
    readonly property int topEdges: Box3DGeometry.TopEdges
    readonly property int bottomEdges: Box3DGeometry.BottomEdges
    readonly property int frontEdges: Box3DGeometry.FrontEdges
    readonly property int backEdges: Box3DGeometry.BackEdges
    readonly property int leftEdges: Box3DGeometry.LeftEdges
    readonly property int rightEdges: Box3DGeometry.RightEdges

    // --- the eyes, in this box's own units -----------------------------------

    /*! Eye centres: x out from the centre line, y up from the box floor. */
    property vector2d eyeCentre: Qt.vector2d(0, 0)
    /*! Half an eye's width. */
    property real eyeHalf: 0
    /*! Lower lid, 0 open to 1 nearly shut. Up from below is pleasure. */
    property real eyeSquint: 0
    /*! Upper lid, 0 open to 1 nearly shut. Down from above is a glare. */
    property real eyeHood: 0
    /*! Where the irises look, -1..1 of their free travel inside the white. */
    property vector2d gaze: Qt.vector2d(0, 0)
    property color eyeColor: "#4a3728"
    property color browColor: "#734120"
    /*! Brow displacement from its resting place above the eye. */
    property vector2d browOffset: Qt.vector2d(0, 0)
    /*! Half extents of one brow bar. */
    property vector2d browHalf: Qt.vector2d(0, 0)
    /*! Brow angle in degrees; positive lifts the outer end. */
    property real browAngle: 0
    /*!
        How far one brow rises while the other drops, as a length in the same
        units as \l browOffset. The only term on this face that tells the two
        sides apart - and the reason a raised eyebrow and a sneer are possible
        at all, since everything else here is mirrored.
    */
    property real browSkew: 0

    // --- the mouth -----------------------------------------------------------

    /*! Upper lip: x is always 0, y is up from the box floor. */
    property vector2d mouthCentre: Qt.vector2d(0, 0)
    /*! Half the mouth's width, and half the lip line's thickness. */
    property vector2d mouthHalf: Qt.vector2d(0, 0)
    /*! How far the cavity has opened downward. */
    property real mouthGap: 0
    /*! 0 a slot, 1 a circle. The shape of a rounded vowel, not just a narrower one. */
    property real mouthRound: 0
    /*! -1 frown, 0 neutral, 1 smile. */
    property real mouthCornerLift: 0
    /*!
        A one-sided lip curl, -1 to 1: the mouth tilts and one corner climbs
        clear of the other. A sneer, which is a different thing from a frown
        and the thing disgust is made of.
    */
    property real mouthSkew: 0
    property color lipColor: "black"
    property color cavityColor: "#20100c"

    geometry: Box3DGeometry {
        id: _geometry
        size: Qt.vector3d(root.width, root.height, root.depth)
        showEdges: true
        edgeThickness: 3.5
        edgeColorFactor: 0.4
        edgeMask: Box3DGeometry.AllEdges
        edgeMode: Box3DGeometry.FaceBorders
    }

    materials: [
        CustomMaterial {
            id: _material
            property color baseColor: "red"
            property bool useToonShading: false

            vertexShader: "../face3d.vert"
            fragmentShader: "../face3d.frag"
            shadingMode: CustomMaterial.Shaded

            // Same names, same meanings, same shared code as box3d.frag.
            property bool showEdges: _geometry.showEdges
            property real edgeThickness: _geometry.edgeThickness
            property real edgeColorFactor: _geometry.edgeColorFactor
            property color edgeColor: _geometry.edgeColor
            property int edgeMask: _geometry.edgeMask
            property int edgeMode: 0

            property vector2d boxSize: Qt.vector2d(root.width, root.height)
            // Asked of the geometry rather than derived from `bevel`, which is
            // a fraction of the shortest edge and is clamped - the geometry is
            // the only thing that knows what it actually used.
            property real faceInset: _geometry.bevelWidth
            property int facePanel: root.panel
            property int faceDetail: root.faceDetail

            property vector2d eyeCentre: root.eyeCentre
            property real eyeHalf: root.eyeHalf
            property real eyeSquint: root.eyeSquint
            property real eyeHood: root.eyeHood
            property vector2d gaze: root.gaze
            property color eyeColor: root.eyeColor
            property color browColor: root.browColor
            property vector2d browOffset: root.browOffset
            property vector2d browHalf: root.browHalf
            property real browAngle: root.browAngle
            property real browSkew: root.browSkew

            property vector2d mouthCentre: root.mouthCentre
            property vector2d mouthHalf: root.mouthHalf
            property real mouthGap: root.mouthGap
            property real mouthRound: root.mouthRound
            property real mouthCornerLift: root.mouthCornerLift
            property real mouthSkew: root.mouthSkew
            property color lipColor: root.lipColor
            property color cavityColor: root.cavityColor
        }
    ]
}
