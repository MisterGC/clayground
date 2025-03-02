// Pass through necessary variables for lighting
VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec3 pos;

void MAIN()
{
    // Pass the color through
    colorOut = COLOR;
    pos = VERTEX;
}

