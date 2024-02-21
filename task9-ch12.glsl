void main()
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    float r = uv.x;
    float g = uv.y;
    float b = 0.2;

    vec3 col = vec3(r, g, b);
    gl_FragColor = vec4(col, 1.0);
}