#version 330

uniform sampler2D tOffScreenBuffer0;
uniform sampler2D tOffScreenBuffer1;

in  vec2 texcoord;

out vec4 result;

void main(void)
{
	vec4 left  = texture2D( tOffScreenBuffer0, texcoord.xy );
	vec4 right = texture2D( tOffScreenBuffer1, texcoord.xy );

	vec4 color = vec4( 0.0 );

	color.x = left.x;
	color.y = right.y;

	//http://3dtv.at/Knowhow/AnaglyphComparison_en.aspx
	color.x = left.x * 0.7 + left.y * 0.3;
	color.yz = right.yz;

	result = color;
}
