// The face, drawn into the front of a head box instead of built in front of it.
//
// Composed with box3d_edges.glsl ahead of it and box3d_toon.glsl after it into
// face3d.frag - which is generated, so edit THIS file. The composition is
// declared in plugins/clay_character3d/CMakeLists.txt, and the two parts it
// borrows come from Canvas3D so that a head is outlined and lit by exactly the
// code every other body part is outlined and lit by.
//
// WHY THIS EXISTS
//
// A face used to be thirteen boxes: two eyes, two irises, two brows, a nose,
// two ears, a mouth cavity, a lip and two corner strokes. Boxes are the wrong
// primitive for most of them. An eye is not an object in front of a head, it is
// a marking on one, and building it as a cube meant that at twenty degrees off
// axis you could see the eye's side wall - a white block bolted to the skull.
// The measurements say the same thing from the other end: a draw call costs
// about 17.8 us here and vertices are too cheap to measure, so ten small boxes
// are pure overhead for something that has no silhouette to contribute.
//
// Drawn here, the whole face is worth zero draw calls and no vertices, which is
// what makes it affordable to keep a face on a character that has become small
// on screen instead of deleting it - see Head::detail.
//
// Deliberately NOT a texture. The lids, the gaze and the mouth all move every
// frame while a character talks, so a texture would mean re-rasterising one per
// character per frame; and an image has a resolution, which these shapes, being
// distance fields, do not. What follows re-evaluates from uniforms for free and
// stays sharp at any size.
//
// Everything is computed in the BOX'S OWN units, not in UV: `local` below undoes
// the 0..1 mapping, so every uniform this file takes is a length in the same
// frame Head.qml already measures its anchors in. That is what stops the face
// from being a second, disagreeing copy of where the face is.

VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec2 vUV;
VARYING vec3 vOrigPosition;
VARYING vec3 vWorldPosition;
VARYING float vFaceID;
VARYING vec3 vBary;
VARYING float vFaceFront;

// Uniforms from the CustomMaterial. The edge and toon ones are the same set
// box3d.frag takes, because the parts above and below need them.
// - vec2  boxSize          width and height of this box, world units
// - float faceInset        what the chamfer takes off each side of the quad
// - int   facePanel        0 none, 1 eyes and brows, 2 mouth
// - int   faceDetail       0 marks only, 1 the whole face
// - vec4  eyeColor, browColor, lipColor, cavityColor
// - vec2  eyeCentre        x from the centre line, y from the box floor
// - float eyeHalf          half an eye's width
// - float eyeSquint        lower lid, 0 open to 1 shut
// - float eyeHood          upper lid, 0 open to 1 shut
// - vec2  gaze             where the irises look, -1..1 of their free travel
// - vec2  browOffset       from the resting place above the eye
// - vec2  browHalf         half extents of one brow bar
// - float browAngle        degrees, positive lifts the outer end
// - vec2  mouthCentre      x always 0, y of the upper lip
// - vec2  mouthHalf        half the mouth's width, and the cavity's closed height
// - float mouthGap         how far the cavity has opened downward
// - float mouthCornerLift  -1 frown, 0 neutral, 1 smile

// Rounded box, signed. Negative inside.
float sdRoundBox(vec2 p, vec2 b, float r) {
    r = min(r, min(b.x, b.y));
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// How much of this pixel the shape covers. One pixel of ramp either side of the
// boundary, measured from the field's own screen-space gradient - the same
// trick the outline uses, and the reason these shapes do not crawl when the
// character is small or the camera is moving.
float clayFill(float d) {
    float px = max(fwidth(d), 1e-8);
    return 1.0 - smoothstep(-px * 0.5, px * 0.5, d);
}

vec4 over(vec4 dst, vec4 src, float a) {
    return mix(dst, vec4(src.rgb, dst.a), clamp(a * src.a, 0.0, 1.0));
}

vec2 rot(vec2 p, float deg) {
    float a = radians(deg);
    float c = cos(a), s = sin(a);
    return vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
}

// One eye: white, lids, iris, and the lash line that keeps a shut eye legible.
vec4 drawEye(vec4 dst, vec2 p, float side) {
    vec2 c = vec2(side * eyeCentre.x, eyeCentre.y);
    vec2 q = p - c;

    // What each lid takes. Half the eye is as far as either goes - past that
    // the iris has nowhere to sit and the face reads as asleep rather than as
    // pleased. Which lid moves is the whole of the difference between the
    // emotions at the eyes: up from below is pleasure, down from above is a
    // glare. Getting that backwards produces a face that is unmistakably wrong
    // and impossible to name.
    float lo = -eyeHalf + eyeHalf * eyeSquint;
    float hi =  eyeHalf - eyeHalf * eyeHood;

    // The white, cut by both lids. A rounded rectangle rather than the square
    // the box version had: at a distance a hard corner is the first thing to
    // alias, and an eye is the smallest thing on the face.
    float d = sdRoundBox(q, vec2(eyeHalf, eyeHalf), eyeHalf * 0.35);
    float lidded = max(d, max(lo - q.y, q.y - hi));
    dst = over(dst, vec4(1.0, 1.0, 1.0, 1.0), clayFill(lidded));

    // The iris, clipped to whatever of the white is still showing, so it
    // disappears under a closing lid instead of floating over it.
    //
    // Drawn at EVERY detail level. Dropping it was the obvious saving and the
    // wrong one: a white eye with nothing in it is a blind stare, which is a
    // stronger and worse read at a distance than the missing detail it was
    // meant to hide. What Low drops is the highlight, not the pupil - the same
    // mistake, one step milder, as deleting the face outright used to be.
    float irisR = eyeHalf * 0.46;
    vec2 free = vec2(eyeHalf - irisR, eyeHalf - irisR) * 0.75;
    vec2 ic = q - vec2(gaze.x, gaze.y) * free;
    float di = max(length(ic) - irisR, lidded);
    dst = over(dst, eyeColor, clayFill(di));

    if (faceDetail > 0) {
        // A pupil highlight. One dot, up and to the light side - the cheapest
        // thing that stops an eye reading as a painted disc. This one really
        // does stop being worth its pixels when the eye is a few across.
        float dh = max(length(ic - vec2(-irisR * 0.32, irisR * 0.34)) - irisR * 0.26,
                       lidded);
        dst = over(dst, vec4(1.0, 1.0, 1.0, 0.9), clayFill(dh));
    }

    // The lash line, along the upper lid. Drawn whatever the lids are doing:
    // when they meet it is the only thing left, and a blink that ends in a bare
    // face reads as the eyes having been deleted rather than closed.
    float lash = sdRoundBox(q - vec2(0.0, hi), vec2(eyeHalf * 0.98, eyeHalf * 0.11),
                            eyeHalf * 0.06);
    dst = over(dst, vec4(browColor.rgb, 1.0), clayFill(lash));

    return dst;
}

vec4 drawBrow(vec4 dst, vec2 p, float side) {
    // Hung off the eye's RESTING position, never off its current one: a brow
    // anchored to the lidded height rides the lids down, and an eyebrow that
    // follows the lid is an eyebrow inside the eye.
    vec2 c = vec2(side * eyeCentre.x, eyeCentre.y) + vec2(side * browOffset.x, browOffset.y);
    vec2 q = rot(p - c, side * browAngle);
    dst = over(dst, browColor, clayFill(sdRoundBox(q, browHalf, browHalf.y * 0.5)));
    return dst;
}

// The mouth: a dark cavity that opens downward from a lip line that does not
// move, plus two corner strokes hinged at the ends of that line.
vec4 drawMouth(vec4 dst, vec2 p) {
    vec2 q = p - mouthCentre;

    // Cavity. Its top edge stays at the lip line and the bottom grows down.
    float halfH = (mouthHalf.y + mouthGap) * 0.5;
    float dc = sdRoundBox(q - vec2(0.0, -halfH), vec2(mouthHalf.x, halfH),
                          mouthHalf.y * 0.6);
    dst = over(dst, cavityColor, clayFill(dc));

    // The lip line, covering the cavity's top edge so a closed mouth reads as
    // one clean stroke rather than as a slot. Hung UNDER the mouth line, not
    // straddling it, so the line itself is where the mouth is.
    float dl = sdRoundBox(q - vec2(0.0, -mouthHalf.y * 0.2),
                          vec2(mouthHalf.x, mouthHalf.y * 0.2), mouthHalf.y * 0.12);
    dst = over(dst, lipColor, clayFill(dl));

    if (faceDetail > 0) {
        // Corners, hinged AT the end of the lip line and turned, rather than
        // moved up and down beside it. As free marks they rose clear of the lip
        // they belong to and a smiling character wore two dots floating past
        // the ends of a straight mouth - startled, not pleased. A stroke that
        // starts at the mouth and turns keeps the shape continuous, which is
        // the whole reason a viewer reads it as one expression.
        for (int i = 0; i < 2; ++i) {
            float side = i == 0 ? -1.0 : 1.0;
            // The hinge sits a little INSIDE the end of the lip line, so the
            // stroke's inner end always overlaps it. Hinged exactly at the end,
            // the two rounded shapes meet at a notch and the mouth reads as
            // three marks rather than one.
            vec2 hinge = vec2(side * (mouthHalf.x - mouthHalf.y * 0.35), 0.0);
            // rot() turns the sample point, so the shape turns the other way -
            // hence no minus here. With one, joy frowned and anger smiled.
            vec2 r = rot(q - hinge, side * mouthCornerLift * 40.0);
            // Hung from the mouth line like the lip is, not straddling it -
            // otherwise the corners ride above the stroke they belong to and
            // the mouth reads as three separate marks.
            float len = mouthHalf.x * 0.42;
            float dcr = sdRoundBox(r - vec2(side * len, -mouthHalf.y * 0.35),
                                   vec2(len, mouthHalf.y * 0.35),
                                   mouthHalf.y * 0.2);
            dst = over(dst, lipColor, clayFill(dcr));
        }
    }
    return dst;
}

void MAIN()
{
    vec4 skin = colorOut;
    vec4 c = skin;

    if (facePanel != 0 && vFaceFront > 0.5) {
        // Out of UV and back into the box's own frame. The box origin is
        // bottom-centre, so x runs from -w/2 and y from the floor up - which is
        // the frame Head.qml's anchors are already written in.
        //
        // faceInset is what a chamfer takes off each side. The front quad still
        // carries 0..1 UVs after Box3DGeometry insets it, so mapping straight
        // through boxSize silently scales the whole face down by the chamfer -
        // at roundness 0.32 on a cartoon head that is a face at 57% of its
        // size, with the eyes closer together than every anchor says they are.
        // Accessories are placed from the anchors, so a beveled head would wear
        // its spectacles wider than its own eyes.
        vec2 span = max(boxSize - 2.0 * faceInset, vec2(1e-6));
        vec2 local = vec2((vUV.x - 0.5) * span.x, faceInset + vUV.y * span.y);

        if (facePanel == 1) {
            c = drawEye(c, local, -1.0);
            c = drawEye(c, local,  1.0);
            if (faceDetail > 0) {
                c = drawBrow(c, local, -1.0);
                c = drawBrow(c, local,  1.0);
            }
        } else {
            c = drawMouth(c, local);
        }
    }

    // The outline darkens from the SKIN, not from whatever the face happens to
    // have put under it - otherwise the head's border turns white where it runs
    // past an eye.
    BASE_COLOR = clayEdgeMix(c, skin, vUV, vFaceID, vBary);

    if (useToonShading) {
        METALNESS = 0.0;
        ROUGHNESS = 1.0;
    }
}
