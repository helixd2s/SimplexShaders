#version 460 compatibility

uniform sampler2D colortex7;

layout (location = 0) in vec2 vtexcoord;

void main() {
	vec2 texcoord = vtexcoord;

	vec3 sceneColor = texture(colortex7, texcoord, 0).rgb;
	sceneColor.xyz = pow(sceneColor.xyz, vec3(1.0/2.2));
	gl_FragColor = vec4(sceneColor, 1.0);
}
