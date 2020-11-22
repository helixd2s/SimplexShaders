#version 460 compatibility

layout (location = 0) in vec2 vtexcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex7;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform float viewWidth;
uniform float viewHeight;

//uniforms (projection matrices)
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform vec3 cameraPosition;

/*DRAWBUFFERS:01234567*/

/*
    const int colortex0Format = RGBA32F;
    const int colortex1Format = RGBA32F;
    const int colortex2Format = RGBA32F;
    const int colortex3Format = RGBA32F;
    const int colortex4Format = RGBA32F;
    const int colortex5Format = RGBA32F;
    const int colortex6Format = RGBA32F;
    const int colortex7Format = RGBA32F;

    const vec4 colortex0ClearColor = vec4(0.f,0.f,0.f,0.f);
    const vec4 colortex1ClearColor = vec4(0.f,0.f,0.f,0.f);
    const vec4 colortex2ClearColor = vec4(0.f,0.f,0.f,0.f);
    const vec4 colortex3ClearColor = vec4(0.f,0.f,0.f,0.f);
    const vec4 colortex4ClearColor = vec4(0.f,0.f,0.f,0.f);
    const vec4 colortex5ClearColor = vec4(0.f,0.f,0.f,0.f);
    const vec4 colortex6ClearColor = vec4(0.f,0.f,0.f,0.f);
    const vec4 colortex7ClearColor = vec4(0.f,0.f,0.f,0.f);
*/

#include "/lib/math.glsl"
#include "/lib/convert.glsl"
#include "/lib/transforms.glsl"

//float pow2(in float a) {
//    return a*a;
//}

vec4 getSmoothTransparent(in ivec2 texcoord){
    float alpha = 0.f, sampled = 0.f;
    vec3 color = vec3(0.f.xxx);
    for (int x=-2;x<3;x++) {
        for (int y=-2;y<3;y++) {
            ivec2 wtexcoord = texcoord + ivec2(x,y);
            bool hasTrnsp = texelFetch(colortex0, wtexcoord, 0).w > 0.f;
            mat2x3 ctex0w = unpack2x3(texelFetch(colortex0, wtexcoord, 0).xyz);
            if (hasTrnsp) { color += vec3(ctex0w[0].xyz), sampled += 1.f; };
            alpha += 1.f;
        }
    }
    return vec4(color/max(alpha,1.f),clamp(sampled/max(alpha,1.f), 0.f, 1.f));
}

void main() {
    ivec2 gtexcoord = ivec2(vtexcoord * vec2(viewWidth, viewHeight)) / 2;
    ivec2 ttexcoord = ivec2(vtexcoord * vec2(viewWidth, viewHeight)) / 2 + ivec2(viewWidth, 0) / 2;
    ivec2 wtexcoord = ivec2(vtexcoord * vec2(viewWidth, viewHeight)) / 2 + ivec2(viewWidth, viewHeight) / 2;

    // 
    bool hasTrnsp = texelFetch(colortex0, ttexcoord, 0).w > 0.f;
    bool hasWater = texelFetch(colortex0, wtexcoord, 0).w > 0.f;
    mat2x3 ctex0g = unpack2x3(texelFetch(colortex0, gtexcoord, 0).xyz);
    mat2x3 ctex0t = unpack2x3(texelFetch(colortex0, ttexcoord, 0).xyz);
    mat2x3 ctex0w = unpack2x3(texelFetch(colortex0, wtexcoord, 0).xyz);

    // 
    mat2x3 ctex1g   = unpack2x3(texelFetch(colortex1, wtexcoord, 0).xyz);
    vec3 normal     = normalize(ctex1g[0]*2.0-1.0);
    vec3 tangent    = normalize(ctex1g[1]*2.0-1.0);
    vec3 bitangent  = normalize(cross(tangent, normal));

    // grounding
	vec4 sceneColor = vec4(ctex0g[0], 1.f);
    float sceneDepth = texelFetch(depthtex0, gtexcoord, 0).r;

    // transparent layers (for shading)
	vec4 transpColor = vec4(ctex0t[0], hasTrnsp ? 1.f : 0.f);
    float transpDepth = texelFetch(depthtex0, ttexcoord, 0).r;

    // waters layers (for shading)
	vec4 waterColor = vec4(ctex0w[0], hasWater ? 1.f : 0.f);
    float waterDepth = texelFetch(depthtex0, wtexcoord, 0).r;

    //
    vec3 screenpos  = getScreenpos(sceneDepth.x, vtexcoord.xy*0.5f);
    vec3 worldpos   = toWorldpos(screenpos);

    //
    float reflcoef  = 1.f - abs(dot(normalize(screenpos), normal));

    // when looking behind the water
    if (sceneDepth >= transpDepth) { // don't account clouds
        sceneColor.xyz = mix(sceneColor.xyz, transpColor.xyz/max(pow2(transpColor.w), 0.001f), clamp((transpColor.w), 0.f, 1.f));
    };

    // 
    float filterRefl = texelFetch(colortex0, wtexcoord, 0).w;
    if (transpDepth >= waterDepth && sceneDepth >= waterDepth) { // don't account clouds
        sceneColor.xyz = mix(sceneColor.xyz, waterColor.xyz, clamp(filterRefl > 0.999f ? (0.1f + reflcoef*vec3(0.5f.xxx)) : vec3(0.f.xxx), 0.f, 1.f));
    };

    gl_FragData[7] = vec4(sceneColor.xyz, 1.f);
	//gl_FragData[0] = vec4(mix(sceneColor, waterColor, texture(colortex0, wtexcoord, 0).w), 1.0);
    //gl_FragData[7] = texture(colortex7, vtexcoord);
    //gl_FragData[0] = vec4(texture(colortex0, vtexcoord, 0).xyz, 1.f);
    //gl_FragData[0] = vec4(texture(colortex7, vtexcoord).yyy * 0.1f, 1.0);
};
