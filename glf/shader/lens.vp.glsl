#version 120

uniform vec4  displayParameters, showPosition, textureRectangle;

varying vec2 texelCoord;

void main() {
	vec2 pos;

	gl_Position.zw = vec2( 1.0 );

	pos.xy = ( gl_Vertex.xy * showPosition.zw + showPosition.xy ) / displayParameters.xy;
	pos.y  = 1 - pos.y;
	gl_Position.xy = pos.xy * 2.0 - 1.0;

	gl_TexCoord[ 0 ].xy = gl_Vertex.xy * textureRectangle.zw + textureRectangle.xy;

	texelCoord.xy = (gl_Vertex.xy * textureRectangle.zw + textureRectangle.xy) * displayParameters.xy;


	gl_TexCoord[ 0 ].zw = vec2( 0.0, 1.0 );
	gl_TexCoord[ 0 ].y = 1.0f - gl_TexCoord[ 0 ].y;
}
