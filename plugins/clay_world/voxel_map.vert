VARYING vec4 colorOut;

void MAIN()
{
    POSITION = MODELVIEWPROJECTION_MATRIX * vec4(VERTEX, 1.0);
    colorOut = COLOR;
}

