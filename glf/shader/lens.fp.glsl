#version 120

uniform sampler2D   tTexture; 

uniform vec4  rgbaExposure;
uniform float showAlpha;

uniform float scale;

uniform int zoomValue;

in vec2 texelCoord;

void main(void)
{
	vec4 inp = texture2D( tTexture, gl_TexCoord[ 0 ].xy );
	
	vec2 t = fract( texelCoord.xy );
	float d = 1.0 - max( t.x, t.y );
	if ( d > 0.1 ) d = 1.0;
	if ( zoomValue > 4 )
		inp *= vec4( d ) * 1.0;
	
	inp *= scale;

	gl_FragColor = inp;
}
