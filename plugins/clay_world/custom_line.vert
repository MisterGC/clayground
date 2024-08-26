void MAIN()
{
    vec4 worldPos = MODEL_MATRIX * vec4(VERTEX, 1.0);
    POSITION = MODELVIEWPROJECTION_MATRIX * worldPos; //+ vec4(offset, 0.0));
}
