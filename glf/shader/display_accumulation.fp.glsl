#version 330

uniform sampler2D tSource;

uniform float scale;

in  vec2 texcoord;

out vec4 result;

void main(void)
{
	vec4 color = texture2D( tSource, texcoord.xy );

	color *= scale;

	result = color;
}
