// LabStage3D vertex shader - hands the fragment stage the world position.
//
// The whole grid is a function of where a fragment lands in the WORLD, not of
// where it lands on the quad: that is what lets one plane of any size carry a
// raster whose lines sit on round world coordinates, and what makes the raster
// survive the quad being scaled or moved.
VARYING vec3 vWorld;

void MAIN()
{
    vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
