#version 430

out vec4 out_color;

uniform mat4 matMVP, matM, matNrml;
uniform vec3 camPos, lightPos;
uniform float time;

in vec3 P;
in vec3 N;
in vec3 L;
in vec2 texCoord;
in vec4 screenP;
in float depth;

uniform sampler2D tObjMapKa; 
uniform sampler2D tObjMapKd; 
uniform sampler2D tObjMapKs; 
uniform sampler2D tObjMapNs; 

uniform vec3 objMatAmbient;
uniform vec3 objMatDiffuse;
uniform vec3 objMatSpecular;
uniform vec3 objMatEmission;
uniform float objMatShininess;

uniform sampler2D tEnvMap; 
uniform sampler2D tEnvMapDiffuse; 
uniform sampler2D tEnvMapPF; 
uniform sampler2D tBRDFTable; 

uniform int depthOnlyHack;

uniform bool bSpecularEnvMap; /*## SpecularEnvMap 1 */
uniform int blub; /*## blub 2 1 4 */
uniform float bla; /*## test_variable 1.0 1.0 16.0 0.01*/

uniform float exposure;		/*## Exposure 0.25 0.01 10.0 0.05 */
uniform float gamma;		/*## Gamma 1.5 0.1 3.0 0.1 */

vec2 direction2latlong( vec3 dir )
{
	vec2 uv;
	uv.x = ( atan( dir.z, -dir.x ) ) / 6.2831853071796;
	uv.y = acos( dir.y ) / 3.1415926535898;
	return uv;
}

void	computeTangentSpace( in vec3 N, out mat3 TS )
{
	TS = mat3( 1.0 );
	vec3 NeverCoLinear = vec3( N.y, N.z, -N.x );
	vec3 T = normalize( cross( NeverCoLinear, N ) );
	vec3 B = cross( N, T );	
	TS = mat3( T, B, N );
}

float saturate( float x ) {
	return clamp( x, 0.0, 1.0 );
}

float irradianceTubeLight( vec3 lightP0, vec3 lightP1, vec3 p, vec3 n, vec3 r, out vec3 lightP, out float minDist ) {
	
	vec3 L0 = lightP0 - p;
	vec3 L1 = lightP1 - p;
	vec3 Ld = L1 - L0;

	float irr = 2.0 * saturate( dot( n, L0 ) / 2.0 / length( L0 ) + dot( n, L1 ) / 2.0 / length( L1 ) ) / 
	            ( length( L0 ) * length( L1 ) + dot( L0, L1 ) + 2.0 );

	// smallest distance to r
	float t = ( dot( r, L0 ) * dot( r, Ld ) - dot( L0, Ld ) ) / ( dot( Ld, Ld ) - dot( r, Ld ) * dot( r, Ld ) );

	lightP = L0 + saturate( t ) * Ld;

	//minDist = l;
	minDist = length( lightP );

	return irr;
}

float G1( float NdotX, float k ) {
	return NdotX / ( NdotX * ( 1.0 - k ) + k );
}

float G_Smith( float roughness, float NoV, float NoL )
{
	float k = roughness + 1.0;
	      k = k * k / 8.0;

	return G1( NoL, k ) * G1( NoV, k );
}

float D( float alpha, float NoH )
{
	float cosTheta = NoH;
	float sinTheta = sin( acos( NoH ) );
	float denom = NoH * NoH * ( alpha * alpha - 1.0 ) + 1.0;
	return alpha * alpha / ( 3.14 * denom * denom );
}

vec3 microfacetSpecular( vec3 color, float roughness, vec3 N, vec3 V, vec3 L, vec3 H )
{
	float NoV = max( dot( N, V ), 0.0001 );
	float NoL = saturate( dot( N, L ) );
	float NoH = saturate( dot( N, H ) );
	float VoH = saturate( dot( V, H ) );

	vec3 specLighting = vec3( 0.0 );

	if ( NoL > 0.0 )
	{
		float G  = G_Smith( roughness, NoV, NoL );
		float Fc = pow( 1.0 - VoH, 5.0 );
		vec3  F  = ( 1.0 - Fc ) * color + vec3( Fc );
		specLighting = NoL * vec3( D( roughness * 2.0, NoH ) ) * G * F / ( 4.0 * NoV );
	}

	return specLighting;
}

void main(void)
{
	out_color = vec4( 0.0 );
	out_color.xyz = N;
}
