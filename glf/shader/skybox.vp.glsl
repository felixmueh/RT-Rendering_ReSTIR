#version 330

in  vec4 in_position;

uniform mat4 matMVP, matLight;

out vec3 dir;

uniform vec3 camPos;

void main() {
	gl_Position = matMVP * ( in_position + vec4( camPos, 0.0 ) );

	vec4 t = matLight * in_position;
	dir = normalize( t.xyz / t.w );
}
