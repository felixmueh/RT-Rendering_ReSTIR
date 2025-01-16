#version 430
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_gpu_shader_int64 : require

#include "shared.h.glsl"

out vec4 out_color;
out vec4 out_pos;
out vec4 out_normal;

uniform mat4 matMVP, matM, matNrml;
uniform vec3 camPos, lightPos;
uniform float time;
uniform int frameIdx;

in vec3 P;
in vec4 eyeP;
in vec3 N;
in float AO;
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

uniform int width, height;


//uniform sampler2D tShadowMap; 
//in vec4 posWS;
//in vec4 texCoordSM;

//#include "helpers.h.glsl"
//#include "tangentspace.h.glsl"

#include "raytrace.h.glsl"
#include "envmap.h.glsl"
#include "rng.h.glsl"
#include "common.h.glsl"

//taken from: https://gist.github.com/dpiponi/cb585cfc36462ff679e93c5024717c5d

// A single iteration of Bob Jenkins' One-At-A-Time hashing algorithm.
uint hash( uint x ) {
    x += ( x << 10u );
    x ^= ( x >>  6u );
    x += ( x <<  3u );
    x ^= ( x >> 11u );
    x += ( x << 15u );
    return x;
}

// Compound versions of the hashing algorithm I whipped together.
uint hash( uvec2 v ) { return hash( v.x ^ hash(v.y)                         ); }
uint hash( uvec3 v ) { return hash( v.x ^ hash(v.y) ^ hash(v.z)             ); }
uint hash( uvec4 v ) { return hash( v.x ^ hash(v.y) ^ hash(v.z) ^ hash(v.w) ); }



// Construct a float with half-open range [0:1] using low 23 bits.
// All zeroes yields 0.0, all ones yields the next smallest representable value below 1.0.
float floatConstruct( uint m ) {
    const uint ieeeMantissa = 0x007FFFFFu; // binary32 mantissa bitmask
    const uint ieeeOne      = 0x3F800000u; // 1.0 in IEEE binary32

    m &= ieeeMantissa;                     // Keep only mantissa bits (fractional part)
    m |= ieeeOne;                          // Add fractional part to 1.0

    float  f = uintBitsToFloat( m );       // Range [1:2]
    return f - 1.0;                        // Range [0:1]
}

// Pseudo-random value in half-open range [0:1].
float random( float x ) { return floatConstruct(hash(floatBitsToUint(x))); }
float random( vec2  v ) { return floatConstruct(hash(floatBitsToUint(v))); }
float random( vec3  v ) { return floatConstruct(hash(floatBitsToUint(v))); }
float random( vec4  v ) { return floatConstruct(hash(floatBitsToUint(v))); }

layout(early_fragment_tests) in;

void main(void)
{
    Rng rng;
    uint FragIdx = uint(gl_FragCoord.x + gl_FragCoord.y * width);
    rngInit(rng, frameIdx, FragIdx);

    out_pos = vec4(P, 1.0f);
    out_normal = vec4(N, 1.0f);

    vec3 contrib = vec3(0);
    vec3 pos = P;
    
    vec3 dir = onb(N) * squareToUniformHemisphere(rngRndVec2(rng));
    vec3 thp = vec3(1) / pdfSquareToUniformHemisphere(dir);

    Ray r = createRay(pos + N * 1e-5, dir, 0, 1e30);

    // cast shadow ray, accumulate lighting if no intersection
    if ( !traceRay( r ) ) {
        contrib += thp * envmapGet(dir);
    }
    else {
        Intersection isect = getIntersection(r);

        dir = onb(isect.n) * squareToUniformHemisphere(rngRndVec2(rng));
        thp *= isect.albedo * abs(dot(dir, isect.n)) / pdfSquareToUniformHemisphere(dir);

        r = createRay(isect.p + isect.n * 1e-5, dir, 0, 1e30);

        if ( !castRay( r )) {
            contrib += thp * envmapGet(r.dir);
        }
    }
    
    // labertian cosine of RTE
    float cosTheta = max(dot(dir, N), 0.0);
    out_color.xyz = objMatAmbient * contrib * cosTheta;
}
