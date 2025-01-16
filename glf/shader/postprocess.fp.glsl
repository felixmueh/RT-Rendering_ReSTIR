#version 330
#extension GL_ARB_texture_multisample : enable

uniform sampler2D tOffScreenBuffer;

uniform sampler2DMS tOffScreenBufferMS;
uniform int tOffScreenBufferWidth, tOffScreenBufferHeight;

uniform int useMultisampling, msNumSamples;

in  vec2 texcoord;
out vec4 result;

uniform float exposure;		/*## Exposure 0.0 -10.0 10.0 0.025 */
uniform float gamma;		/*## Gamma 1.0 0.1 3.0 0.1 */
uniform int maxMultiSamples; /*## Multisampling 16 1 16 */

vec4 resolveTexel( vec2 texcoord )
{
	return texture2D( tOffScreenBuffer, texcoord.xy );
}

void main(void)
{
	vec4 c = resolveTexel( texcoord.xy );

	c.xyz *= pow( 2.0, exposure );
	c.x = pow( c.x, 1.0 / gamma );
	c.y = pow( c.y, 1.0 / gamma );
	c.z = pow( c.z, 1.0 / gamma ); 

	result = c;
}
