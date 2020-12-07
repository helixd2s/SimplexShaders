#version 460 compatibility

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


layout (location = 0) in vec2 vtexcoord;

// 
const float nscale = 1.f;
const float dscale = 1.f;

// 
float bilateral(in vec4 cnd, in vec4 tnd) {
    return exp(-nscale * max(1.f - dot(cnd.xyz, tnd.xyz), dscale * abs(cnd.w - tnd.w)));
};

//
vec4 getNormalWithDepth(in ivec2 coord) {
    mat2x3 ctex1g   = unpack2x3(texelFetch(colortex1, coord, 0).xyz);
    vec3 normal     = normalize(ctex1g[0]*2.0-1.0);
    vec3 tangent    = normalize(ctex1g[1]*2.0-1.0);
    vec3 bitangent  = normalize(cross(tangent, normal));

	return vec4(normal, texelFetch(depthtex0, coord, 0).r);
};

//
void calculateWeights(in ivec2 coord, inout float weights[9]) {
    for (int i=0;i<9;i++) { weights[i] = 0.f; };
    for (int cx=(coord.x-1);cx<(coord.x+2);cx++) {
        for (int cy=(coord.y-1);cy<(coord.y+2);cy++) {
            vec4 cnd = getNormalWithDepth(ivec2(cx,cy));

            float sum = 0.f;
            float tmpWeights[9];
            for (int i=0;i<9;i++) { tmpWeights[i] = 0.f; };

            for (int i=-1;i<2;i++) {
                for (int j=-1;j<2;j++) {
                    ivec2 tap = ivec2(coord.x,coord.y)+(i,j);
                    if ((i - cx <= 1) && (j - cy <= 1)) {
                        float w = bilateral(cnd, getNormalWithDepth(tap));
                        tmpWeights[(i+1)+(j+1)*3] = w;
                        sum += w;
                    };
                };
            };

            for (int i=0;i<9;i++) {
                weights[i] += tmpWeights[i] / sum;
            };
        };
    };
};

//
vec4 getAntiAliased(in ivec2 coord) {
    float weights[9];
    calculateWeights(coord, weights);

    vec3 result = vec3(0.f.xxx);
    for (int i=-1;i<2;i++) {
        for (int j=-1;j<2;j++) {
            result += weights[(i+1)+(j+1)*3] * (1.f/9.f) * texelFetch(colortex7, coord+ivec2(i,j), 0).xyz;
        };
    };
    return vec4(result, texelFetch(colortex7, coord, 0).w);
};

void main() {
	//vec2 texcoord = vtexcoord;
	ivec2 texcoord = ivec2(vtexcoord * vec2(viewWidth, viewHeight));

	vec3 sceneColor = getAntiAliased(texcoord).xyz;//texture(colortex7, texcoord, 0).rgb;
	sceneColor.xyz = pow(sceneColor.xyz, vec3(1.0/2.2));
	gl_FragColor = vec4(sceneColor, 1.0);
}
