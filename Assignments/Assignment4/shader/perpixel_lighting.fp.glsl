#version 430
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_gpu_shader_int64 : require

#include "shared.h.glsl"

out vec4 out_color;
out vec4 out_pos;
out vec4 out_normal;

uniform int n_samples;
#define N_CANDIDATES 16

uniform int sample_mode;

#define SAMPLE_MODE_UNIFORM 0
#define SAMPLE_MODE_RIS 1
#define SAMPLE_MODE_STREAMING_RIS 2
#define SAMPLE_MODE_RESTIR 3

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
#include "lightlist.h.glsl"

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

// MC estimate of the unshadowed direct illumination
vec3 directLightPerpixel(vec3 pos, vec3 light_pos, vec3 light_normal, vec3 emission, float pdf) {
    return directLight(pos, N, objMatDiffuse, light_pos, light_normal, emission) / pdf;
}

void sampleRis(out vec3 y, out vec3 n, out vec3 emission, out float weight_sum, inout Rng rng) {
    vec3 xs[N_CANDIDATES];
    vec3 ns[N_CANDIDATES];
    float ws[N_CANDIDATES];
    vec3 emissions[N_CANDIDATES];

    weight_sum = 0;
    for (int i = 0; i < N_CANDIDATES; i++) {
        vec3 pos;
        float pdf;
        vec3 emission_inner;
        vec3 normal;
        sampleLight(rngRndVec3(rng), emission_inner, pos, normal, pdf);

        float weight = length(directLightPerpixel(P, pos, normal, emission_inner, pdf));

        ws[i] = weight;
        xs[i] = pos;
        ns[i] = normal;
        emissions[i] = emission_inner;
        weight_sum += weight;
    }

    float r = rngRndFloat(rng);
    float c_sum = 0.0;
    int i = 0;
    while (i < N_CANDIDATES) {
        c_sum += ws[i] / weight_sum;
        if (r < c_sum) {
            break;
        }
        i++;
    }
    y = xs[i];
    emission = emissions[i];
    n = ns[i];
}

Reservoir streamingRis(inout Rng rng) {
    Reservoir r = new_reservoir();

    for (int i = 0; i < N_CANDIDATES; i++) {
        vec3 pos;
        vec3 normal;
        float pdf;
        vec3 emission_inner;
        sampleLight(rngRndVec3(rng), emission_inner, pos, normal, pdf);

        // weight = \hat{p}_q(x_i) / p(x_i)
        float weight = length(directLightPerpixel(P, pos, normal, emission_inner, pdf));
        update_reservoir(r, pos, normal, emission_inner, weight, rng);
    }

    vec3 contrib = directLightPerpixel(P, r.out_sample, r.out_normal, r.emission, 1.0);
    float p = length(contrib);
    if (length(p) < 1e-6) {
        // NOTE: multiply with 0 later so does not matter.
        r.W = 0.0;
    } else {
        r.W = 1.0 / p * (1.0 / float(r.sample_count) * r.weight_sum);
    }

    return r;
}

void main(void)
{
    Rng rng;
    uint FragIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
    rngInit(rng, uint64_t(frameIdx), uint64_t(FragIdx));

    out_pos = vec4(P, 1.0f);
    out_normal = vec4(N, 1.0f);

    vec3 color = vec3(0.0f);

    if (sample_mode == SAMPLE_MODE_RESTIR) {
// ========================================
// ReSTIR initialize reservoirs and GBuffer
// ========================================
        for (int i = 0; i < n_samples; i++) {
            Reservoir r = streamingRis(rng);

            vec3 pos = r.out_sample;
            vec3 PL = pos-P;
            vec3 dir = normalize(PL);
            float dist = length(PL);
            Ray ray = createRay(P + N * 1e-5, dir, 0, dist-1e-3);
            if ( castRay( ray ) ) {
                r.W = 0.0;
            }
            reservoirOut[FragIdx + width * height * i] = r;
        }
        GBufferInfo gBufferInfo;
        gBufferInfo.normal = N;
        gBufferInfo.position = P;
        gBufferInfo.albedo = objMatDiffuse;
        gBufferInfo.frame = frameIdx;
        gBuffer[FragIdx] = gBufferInfo;
        out_color.xyz = objMatEmission;
        return;
    }

    for (int i = 0; i < n_samples; i++) {
        if (sample_mode == SAMPLE_MODE_UNIFORM) {
// ========================================
// Uniform light sampling and shading
// ========================================
            vec3 rnd = rngRndVec3(rng);
            vec3 pos, normal, emission;
            float pdf;
            sampleLight(rnd, emission, pos, normal, pdf);

            vec3 PL = pos-P;
            vec3 dir = normalize(PL);
            float dist = length(PL);
            Ray r = createRay(P + N * 1e-5, dir, 0, dist-1e-3);
            // cast shadow ray, accumulate lighting if no intersection
            if ( !castRay( r ) ) {
                color += directLightPerpixel(P, pos, normal, emission, pdf);
            }
        } else if (sample_mode == SAMPLE_MODE_RIS) {
// ========================================
// RIS sampling and shading
// ========================================
            vec3 rnd = rngRndVec3(rng);
            vec3 pos, normal, emission;
            float pdf, weight;
            sampleRis(pos, normal, emission, weight, rng);

            vec3 PL = pos-P;
            vec3 dir = normalize(PL);
            float dist = length(PL);
            Ray r = createRay(P + N * 1e-5, dir, 0, dist-1e-3);
            // cast shadow ray, accumulate lighting if no intersection
            if ( !castRay( r ) ) {
                vec3 f = directLightPerpixel(P, pos, normal, emission, 1.0);
                if (length(f) > 1e-6) {
                    float p = length(f);
                    color += f / p * weight / float(N_CANDIDATES);
                }
            }
        } else if (sample_mode == SAMPLE_MODE_STREAMING_RIS) {
// ========================================
// Streaming RIS sampling and shading
// ========================================
            Reservoir r = streamingRis(rng);

            vec3 pos = r.out_sample;
            vec3 PL = pos-P;
            vec3 dir = normalize(PL);
            float dist = length(PL);
            Ray ray = createRay(P + N * 1e-5, dir, 0, dist-1e-3);
            // cast shadow ray, accumulate lighting if no intersection
            if ( !castRay( ray ) ) {
                vec3 contrib = directLightPerpixel(P, pos, r.out_normal, r.emission, 1.0);
                color += contrib * r.W;
            }
        } else {
// ========================================
// Uniform hemisphere sampling and shading
// ========================================
            vec3 dir = onb(N) * squareToUniformHemisphere(rngRndVec2(rng));
            float pdf = pdfSquareToUniformHemisphere(dir);

            Ray r = createRay(P + N * 1e-3, dir, 0, 1e30);
            // trace ray, accumulate lighting if intersecting emissive triangle
            if ( traceRay( r ) ) {
                Intersection isect = getIntersection(r);
                float cosTheta = max(dot(dir, N), 0.0);
                color += objMatDiffuse * isect.emission * cosTheta / pdf;
            }
        }
    }

    out_color.xyz = objMatEmission + color / float(n_samples);
}
