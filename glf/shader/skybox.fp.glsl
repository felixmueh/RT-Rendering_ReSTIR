#version 330

in vec3 dir;

out vec4 out_color;

uniform sampler2D   tEnvMap; 

vec2 direction2latlong( vec3 _dir )
{
	vec2 uv;

	uv.x = ( 6.2831853071796f + atan( dir.z, -dir.x ) ) / 6.2831853071796f;
	uv.y = acos( dir.y ) / 3.1415926535898f;
	return uv;
}


void main(void)
{
	vec2 tc = direction2latlong( normalize( dir ) );
	out_color = textureLod( tEnvMap, tc, 0.0 );
}
