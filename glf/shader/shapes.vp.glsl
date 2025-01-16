#version 330

uniform mat4 matMVP, matM, matNrml;
uniform vec3 camPos, lightPos;

uniform float time;

in  vec4 in_position;
in  vec4 in_normal;
in  vec2 in_texcoord;

out vec3 N;
out vec3 L;
out vec3 P;
out vec2 texCoord;
out vec4 screenP;
out float depth;

void main() {

	// Transformation
	gl_Position = matMVP * in_position;

	screenP = gl_Position;
	depth = gl_Position.z;

	// Position in Weltkoordinaten
	vec4 temp = matM * in_position;
	P = temp.xyz / temp.w;

	// transformierte Normale
	N = in_normal.xyz;

	// Vektor zur Lichtquelle
	L = normalize( lightPos - P );

	texCoord = in_texcoord;
}
