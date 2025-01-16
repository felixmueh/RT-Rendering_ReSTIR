#version 140

uniform mat4 matMVP, matM, matMV, matNrml;
uniform vec3 camPos, lightPos;

uniform mat4 matSM;
uniform vec3 lightPosWS;

uniform float time;

in  vec4 in_position;
in  vec4 in_normal;
in  vec2 in_texcoord;

out vec3 N;
out vec3 L;
out float AO;
out vec3 P;
out vec4 eyeP;
out vec2 texCoord;
out vec4 screenP;

out vec4 posWS;
out float depth;

void main() {

	// Transformation
	gl_Position = matMVP * in_position;

	// Position in Weltkoordinaten
	vec4 temp = matM * in_position;
	P = temp.xyz / temp.w;

	eyeP = -matMV * in_position;

	// transformierte Normale
	N = ( matNrml * vec4( in_normal.xyz, 0.0 ) ).xyz;

	// Vektor zur Lichtquelle
	L = normalize( lightPos - P );
}
