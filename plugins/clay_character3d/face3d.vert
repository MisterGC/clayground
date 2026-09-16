// Face3D vertex shader - box3d.vert plus one flag.
//
// Everything here is box3d.vert's job, done identically, because the geometry
// underneath is the same Box3DGeometry. The addition is vFaceFront: the face is
// drawn on the front quad only, and "front" has to be a stricter test than the
// face ID.
//
// vFaceID comes off the normal with a 0.9 threshold, which is right for picking
// a UV convention but wrong for a decal. Box3DGeometry::bevel chamfers every
// edge and gives the chamfer strips an averaged normal - (0, 0.707, 0.707) for
// the one between the top and the front - so they land in the same bucket as
// the front face while carrying the constant UV (0.5, 0.5) the outline code
// relies on. A face gated on vFaceID would therefore smear whatever sits at the
// middle of the face across every chamfer around it. 0.995 admits the flat
// quad and nothing else.

VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec2 vUV;
VARYING vec3 vOrigPosition;
VARYING vec3 vWorldPosition;
VARYING float vFaceID;
VARYING vec3 vBary;
VARYING float vFaceFront;

void MAIN()
{
    // Barycentric coordinates for edgeMode: Triangles. They travel on the
    // tangent slot - Box3DGeometry writes (1,0,0)/(0,1,0)/(0,0,1) per
    // triangle corner there - so this is a data channel, not a tangent, and
    // it is passed through untouched. Nothing on this material may enable
    // normal mapping.
    vBary = TANGENT;

    colorOut = baseColor.a > 0.0 ? baseColor : COLOR;
    vUV = UV0;
    vOrigPosition = VERTEX;
    vWorldPosition = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vViewVec = VIEW_MATRIX[3].xyz - vWorldPosition;
    vNormal = normalize(mat3(MODEL_MATRIX) * NORMAL);

    // Which face of the cube we're on, from the normal
    vec3 absNormal = abs(NORMAL);
    if (absNormal.x > 0.9) {
        vFaceID = NORMAL.x > 0.0 ? 1.0 : 2.0; // Right or Left face
    } else if (absNormal.y > 0.9) {
        vFaceID = NORMAL.y > 0.0 ? 3.0 : 4.0; // Top or Bottom face
    } else {
        vFaceID = NORMAL.z > 0.0 ? 5.0 : 6.0; // Front or Back face
    }

    // The flat front quad, and not the chamfers that share its face ID.
    vFaceFront = NORMAL.z > 0.995 ? 1.0 : 0.0;
}
