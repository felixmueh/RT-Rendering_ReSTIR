uniform sampler2D tEnvMap; 

vec2 direction2latlong( vec3 dir )
{
	vec2 uv;

	uv.x = ( 6.2831853071796f + atan( dir.z, -dir.x ) ) / 6.2831853071796f;
	uv.y = acos( dir.y ) / 3.1415926535898f;
	return uv;
}

// query environment map
vec3 envmapGet(vec3 dir) {
	vec2 tc = direction2latlong( normalize( dir ) );
	return textureLod( tEnvMap, tc, 0.0 ).xyz;
}
