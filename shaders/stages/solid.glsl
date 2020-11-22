//these will be available in the fragment shader now, this can be more efficient for some calculations too because per-vertex is cheaper than per fragment/pixel
//stuff like sunlight color get's usually done here because of that
#ifdef VERTEX_SHADER
layout (location = 0) out vec4 color;
layout (location = 1) out vec4 texcoord;
layout (location = 2) out vec4 lmcoord;
layout (location = 3) out vec3 normal;
layout (location = 4) out vec4 position;
layout (location = 5) out vec4 tangent;
layout (location = 6) flat out vec4 entity;
#endif

//these are our inputs from the vertex shader
#ifdef FRAGMENT_SHADER
layout (location = 0) in vec4 color;
layout (location = 1) in vec4 texcoord;
layout (location = 2) in vec4 lmcoord;
layout (location = 3) in vec3 normal;
layout (location = 4) in vec4 position;
layout (location = 5) in vec4 tangent;
layout (location = 6) flat in vec4 entity;
#endif

//
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

// 
uniform int instanceId;
uniform float viewWidth;
uniform float viewHeight;
uniform vec4 fogColor;
uniform int worldTime;
uniform int fogMode;

// 
const int GL_LINEAR = 9729;
const int GL_EXP = 2048;
const int countInstances = 1;

// 
#ifdef VERTEX_SHADER
attribute vec4 mc_Entity;
attribute vec4 at_tangent;
#endif

//we use this for all solid objects because they get rendered the same way anyways
//redundant code can be handled like this as an include to make your life easier
uniform sampler2D tex; 		//this is our albedo texture. optifine's "default" name for this is "texture" but that collides with the texture() function of newer OpenGL versions. We use "tex" or "gcolor" instead, although it is just falling back onto the same sampler as an undefined behavior
uniform sampler2D lightmap;	//the vanilla lightmap texture, basically useless with shaders

uniform sampler2D gaux4;
uniform sampler2D depthtex0;

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

/*DRAWBUFFERS:01234567*/

#include "./../lib/convert.glsl"
#include "./../lib/random.glsl"

uniform int frameCounter; 

void main() {
#ifdef VERTEX_SHADER
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	
	position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    position.xyz += cameraPosition;

	gl_Position = gl_ProjectionMatrix * (gbufferModelView * (position - vec4(cameraPosition, 0.f)));
	
	color = gl_Color;
	
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
	gl_FogFragCoord = gl_Position.z;

    vec4 vnormal = gbufferModelViewInverse * vec4(normalize(gl_NormalMatrix*gl_Normal), 0.f);

	normal = (gbufferModelView * vnormal).xyz;

    tangent = at_tangent;

    entity = mc_Entity;

	#include "./vertexMod.glsl"
#endif

#ifdef FRAGMENT_SHADER
	// sado guru algorithm
	vec2 coordf = gl_FragCoord.xy * 2.f;// * gl_FragCoord.w;
	coordf.xy /= vec2(viewWidth, viewHeight);
	if (entity.x == 3.f || entity.x == 4.f) { coordf.x -= 1.f; };
    if (entity.x == 5.f) { coordf.x -= 1.f; coordf.y -= 1.f; };

#ifdef CLOUDS
    coordf.x -= 1.f;
#endif

#ifdef BASIC
    coordf.x -= 1.f;
#endif

#ifdef WEATHER
    coordf.x -= 1.f;
#endif

    // 
    vec4 viewpos = gbufferProjectionInverse * vec4(coordf * 2.f - 1.f, gl_FragCoord.z, 1.f); viewpos /= viewpos.w;
    vec3 worldview = normalize(viewpos.xyz);
    //vec4 worldpos = gbufferModelViewInverse * viewpos;
    //vec3 worldview = normalize(worldpos.xyz - cameraPosition);

    #ifdef TRANSLUCENT
    bool depthCorrect = gl_FragCoord.z <= texture(depthtex0, coordf*0.5f).x;
    #else
    bool depthCorrect = true;
    #endif

    // 
    #ifdef SOLID
    bool normalCorrect = dot(worldview.xyz, normal.xyz) <= 0.f;
    #else
    bool normalCorrect = true;
    #endif
    
    
    gl_FragDepth = 2.f;

    float outdepth = 1.f;
    float outenabled = 0.f;
    vec3 outcolor = vec3(0.f.xxx);
    vec3 outnormal = vec3(0.f.xxx);
    vec3 outtexcoord = vec3(0.f.xxx);
    vec3 outlmcoord = vec3(0.f.xxx);
    vec3 outtangent = vec3(0.f.xxx);

    float rand = random(vec4(gl_FragCoord.xyz, float(frameCounter)/720719.f));

    const float height = texture(gaux4, vec2(0.25f, 0.25f)).y;
	if (coordf.x >= 0.f && coordf.y >= 0.f && coordf.x < 1.f && coordf.y < 1.f && depthCorrect && normalCorrect) {

        // 
        vec4 ftex = texture(tex, texcoord.st);
        vec4 flightmap = texture(lightmap, lmcoord.st);

    #ifdef CLOUDS
        outenabled = rand < ftex.a*color.a && ftex.a > 0.99f ? 1.f : 0.f;
		outcolor = (ftex * color).xyz;
		outnormal = normal.xyz*0.5+0.5;
        outlmcoord.xy = lmcoord.xy;
        outtexcoord.xy = texcoord.xy;
		outdepth = gl_FragCoord.z;
        
    #endif

    #ifdef SOLID
        outenabled = rand < ftex.a ? 1.f : 0.f;
		outcolor = (ftex * color).xyz;
		outnormal = normal.xyz*0.5+0.5;
        outlmcoord.xy = lmcoord.xy;
        outtexcoord.xy = texcoord.xy;
		outdepth = gl_FragCoord.z;
        if (entity.x == 5.f) { outenabled = 1.f; outcolor = vec3(0.f.xxx); }; // water are NOT transparent technically
    #endif

    #ifdef SKY
        #ifdef BASIC
            outenabled = rand < color.a ? 1.f : 0.f;
            outcolor = color.xyz;
        #else
            outcolor = (ftex * color).xyz;
            outenabled = rand < ftex.a * color.a * length(outcolor.xyz) ? 1.f : 0.f;//rand < ftex.a * color.a ? 1.f : 0.f;
        #endif
        outnormal = vec3(0.f.xx, 1.f);

        if (fogMode == GL_EXP) {
            outcolor.rgb = mix(outcolor.rgb, gl_Fog.color.rgb, 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
        } else if (fogMode == GL_LINEAR) {
            outcolor.rgb = mix(outcolor.rgb, gl_Fog.color.rgb, clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0));
        }
    #endif

    #ifdef WEATHER
        outenabled = rand < ftex.a ? 1.f : 0.f;
        outcolor.rgb = (ftex * color).xyz;
        outdepth = gl_FragCoord.z;
    #endif

    #ifdef HAND
        outenabled = rand < ftex.a ? 1.f : 0.f;
        outcolor.rgb = (ftex * color).xyz;
        outdepth = gl_FragCoord.z;
    #endif

    #ifdef OTHER
        #ifdef BASIC
            outenabled = rand < color.a ? 1.f : 0.f;
            outcolor = color.xyz;
        #else
            outenabled = rand < ftex.a ? 1.f : 0.f;
            outcolor = (ftex * color).xyz;
        #endif

        outdepth = gl_FragCoord.z;
    #endif
	} else {
        discard;
		outdepth = 2.f;
        outenabled = 0.f;
	};


    // 
    if (outenabled < 1.f) {
        discard;
    };

    gl_FragDepth = outdepth;
    gl_FragData[0] = vec4(pack2x3(mat2x3(pow(outcolor, vec3(2.2f.xxx)), vec3(0.f.xx, 0.f))), outenabled);
    gl_FragData[1] = vec4(pack2x3(mat2x3(outnormal, outtangent)), outenabled);
    gl_FragData[2] = vec4(pack2x3(mat2x3(outtexcoord, outlmcoord)), outenabled);
    gl_FragData[3] = vec4(0.f.xxxx);
    gl_FragData[4] = vec4(0.f.xxxx);
    gl_FragData[5] = vec4(0.f.xxxx);
    gl_FragData[6] = vec4(0.f.xxxx);
    gl_FragData[7] = vec4(0.f.xxxx);

#endif


}

