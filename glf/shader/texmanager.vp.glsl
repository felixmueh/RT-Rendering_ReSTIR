#version 120

uniform vec4  displayParameters, showPosition;

void main() {
	vec2 pos;

	gl_Position.zw = vec2( 1.0 );

	pos.xy = ( gl_Vertex.xy * showPosition.zw + showPosition.xy ) / displayParameters.xy;
	pos.y  = 1 - pos.y;
	gl_Position.xy = pos.xy * 2.0f - 1.0f;

	gl_TexCoord[ 0 ] = gl_Vertex;
	gl_TexCoord[ 0 ].y = 1.0f - gl_TexCoord[ 0 ].y;
}
