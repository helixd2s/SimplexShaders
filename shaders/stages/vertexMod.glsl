{
    float deferW = gl_Position.w;
    gl_Position /= deferW;
    
    // 
    gl_Position.xy = gl_Position.xy * 0.5f + 0.5f;

    // split screen 
    gl_Position.xy *= 0.5f;
    
    if (entity.x == 3.f || entity.x == 4.f) {
        gl_Position.x += 0.5f;
    };

    if (entity.x == 5.f) {
        gl_Position.y += 0.5f;
        gl_Position.x += 0.5f;
    };

#ifdef CLOUDS
    gl_Position.x += 0.5f;
#endif

#ifdef BASIC
    gl_Position.x += 0.5f;
#endif

#ifdef WEATHER
    gl_Position.x += 0.5f;
#endif

    // 
    gl_Position.xy = gl_Position.xy * 2.f - 1.f;
    gl_Position *= deferW;
}
