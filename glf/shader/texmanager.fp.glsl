#version 120

uniform sampler2D   tTexture; 

uniform vec4  rgbaExposure;
uniform float showAlpha;

void main(void)
{
	vec4 inp = texture2D( tTexture, gl_TexCoord[ 0 ].xy ); 
	
	inp *= rgbaExposure;
	
	if ( showAlpha > 0.5f )
		inp = inp.wwww;
	
	gl_FragColor = inp;
}
