#version 460 compatibility
#extension GL_NV_gpu_shader5 : enable
//can be anything up to 450, 120 is still common due to compatibility reasons, but i suggest something from 130 upwards so you can use the new "varying" syntax, i myself usually use "400 compatibility"

//set the main framebuffer attachment to use RGB16 as the format to give us higher color precision, for hdr you would want to use RGB16F instead
//this is commented out since Optifine only needs to parse it without being used in code
/*
const int colortex0Format   = RGB16;
const int colortex2Format 	= RGBA16;
*/

//include math functions from file
//#include "/lib/math.glsl"

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

//uniforms for scene texture binding
uniform sampler2D colortex0; 	//scene color
uniform sampler2D colortex1;	//scene normals
uniform sampler2D colortex2;	//scene lightmap
uniform sampler2D colortex3;
uniform sampler2D depthtex0;	//scene depth

//enable shadow2D shadows and bind shadowtex buffer
const bool shadowHardwareFiltering = true; 	//enable hardware filtering for shadow2D
uniform sampler2DShadow shadowtex1; 	//shadowdepth

//shadowmap resolution
const int shadowMapResolution   = 4096;

//shadowdistance
const float shadowDistance      = 128.0;

//input from vertex
layout (location = 0) in vec2 texcoord;
layout (location = 1) in vec3 lightVec;
layout (location = 2) in vec3 sunlightColor;
layout (location = 3) in vec3 skylightColor;
layout (location = 4) in vec3 torchlightColor;

//uniforms (projection matrices)
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;

//include position transform files
#include "/lib/math.glsl"
#include "/lib/transforms.glsl"
#include "/lib/shadowmap.glsl"
#include "/lib/convert.glsl"
#include "/lib/water.glsl"
#include "/lib/sslr.glsl"

uniform vec3 skyColor;

/* 	
    functions to be called in main and global variables go here
    however keep the amount of global variables rather low since the number of temp registers is limited,
    so large amounts of constantly changed global variables can cause performance bottlenecks
    also having non-constant global variables is considered bad practice and will cause issues
    if you sample a texture outside of void main() or a function
*/

//function to calculate position in shadowspace
vec3 getShadowCoordinate(in vec3 screenpos, in float bias) {
    vec3 position 	= screenpos;
        position   += vec3(bias)*lightVec;		//apply shadow bias to prevent shadow acne
        position 	= viewMAD(gbufferModelViewInverse, position); 	//do shadow position tranforms
        position 	= viewMAD(shadowModelView, position);
        position 	= projMAD(shadowProjection, position);

    //apply far plane fix and shadowmap distortion
        position.z *= 0.2;
        warpShadowmap(position.xy);

    return position*0.5+0.5;
}

//calculate shadow, using shadow2D shadows because they are a lot easier to setup here
float getShadow(sampler2DShadow shadowtex, in vec3 shadowpos) {
    float shadow 	= shadow2D(shadowtex, shadowpos).x;

    return shadow;
}

//simple lambertian diffuse shading, google "diffuse shading" for a better explaination than i could give right now
float getDiffuse(vec3 normal, vec3 lightvec) {
    float lambert 	= dot(normal, lightvec);
        lambert 	= max(lambert, 0.0);
    return lambert;
}

/*DRAWBUFFERS:01*/

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;
uniform int fogMode;

//void main is basically the main part where stuff get's done and function get called
void main() {
    ivec2 itexcoord = ivec2(gl_FragCoord.xy);
    mat2x3 ctex0g = unpack2x3(texelFetch(colortex0, itexcoord, 0).xyz);
    vec3 sceneDepth = texture(depthtex0, texcoord, 0).xxx;

    //sample necessary scene textures
    mat2x3 ctex1g   = unpack2x3(texelFetch(colortex1, itexcoord, 0).xyz);
    vec3 normal     = normalize(ctex1g[0]*2.0-1.0);
    vec3 tangent    = normalize(ctex1g[1]*2.0-1.0);
    vec3 bitangent  = normalize(cross(tangent, normal));

    // 
    vec3 world_bitangent = mat3(gbufferModelViewInverse) * bitangent;
    vec3 world_tangent = mat3(gbufferModelViewInverse) * tangent;
    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    // calculate necessary positions
    vec3 screenpos  = getScreenpos(sceneDepth.x, texcoord);
    vec3 worldpos   = toWorldpos(screenpos);
    vec4 bpos       = CameraSpaceToScreenSpace(vec4(screenpos, 1.f));

    // 
    float filterRefl = texelFetch(colortex0, itexcoord, 0).w;
    if (filterRefl > 0.999f && itexcoord.x >= (viewWidth/2) && itexcoord.y >= (viewHeight/2)) {
        vec3 ntexture = normalize(mix(get_water_normal(worldpos, 1.f, world_normal, world_tangent, world_bitangent).xzy, vec3(0.f,0.f,1.f), 0.96f));
        ctex1g[0] = normal = mat3(tangent, bitangent, normal) * ntexture;
    }

    vec3 reflectionColor = vec3(0.f.xxx);
    if (filterRefl > 0.999f && itexcoord.x >= (viewWidth/2) && itexcoord.y >= (viewHeight/2)) {
        vec4 sslrpos = EfficientSSR(screenpos.xyz, normalize(reflect(normalize(screenpos.xyz), normal)));
        ivec2 rtexcoord = ivec2((sslrpos.xy * 0.5f + 0.5f) * vec2(viewWidth, viewHeight) / 2) + ivec2(0, 0) / 2; 
        mat2x3 ctex0r = unpack2x3(texelFetch(colortex0, rtexcoord, 0).xyz);
        ctex0g[0] = distance(bpos.xyz, sslrpos.xyz) > 0.001f ? ctex0r[0] : pow(skyColor, 2.2f.xxx); // assign reflection as water color
    }


    //make terrain mask
    bool isTerrain  = sceneDepth.x < 1.0f;

    //variables for shadow calculation
    float shadow        = 1.0;
    float comparedepth  = 0.0;

    //write to framebuffer attachment

    gl_FragData[0] = vec4(pack2x3(ctex0g), texelFetch(colortex0, itexcoord, 0).a);
    gl_FragData[1] = vec4(pack2x3(ctex1g), texelFetch(colortex0, itexcoord, 0).a);
}
