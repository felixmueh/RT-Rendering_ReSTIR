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

vec3 directLight(vec3 pos, vec3 light_pos, vec3 emission, float pdf) {
    vec3 PL = light_pos-pos;
    vec3 dir = normalize(PL);
    float dist = length(PL);
    Ray r = createRay(pos + N * 1e-5, dir, 0, dist-1e-3);
    // cast shadow ray, accumulate lighting if no intersection
    float geometry_term = max(dot(dir, N), 0.0) / (dist*dist); // for area lights we could use cosTheta at light normal as well
    return emission * objMatDiffuse * geometry_term / pdf;
}

void sampleRis(out vec3 y, out vec3 emission, out float weight_sum, inout Rng rng) {
    vec3 xs[N_CANDIDATES];
    float ws[N_CANDIDATES];
    vec3 emissions[N_CANDIDATES];

    weight_sum = 0;
    for (int i = 0; i < N_CANDIDATES; i++) {
        vec3 pos;
        float pdf;
        vec3 emission_inner;
        sampleLight(rngRndVec3(rng), emission_inner, pos, pdf);

        float weight = length(directLight(P, pos, emission_inner, pdf));

        ws[i] = weight;
        xs[i] = pos;
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
}

Reservoir streamingRis(inout Rng rng) {
    Reservoir r = new_reservoir();

    for (int i = 0; i < N_CANDIDATES; i++) {
        vec3 pos;
        float pdf;
        vec3 emission_inner;
        sampleLight(rngRndVec3(rng), emission_inner, pos, pdf);

        // weight = \hat{p}_q(x_i) / p(x_i)
        float weight = length(directLight(P, pos, emission_inner, pdf));
        update_reservoir(r, pos, emission_inner, weight, rng);
    }

    vec3 pos = r.out_sample;
    vec3 PL = pos-P;
    vec3 dir = normalize(PL);
    float dist = length(PL);
    r.f = directLight(P, pos, r.emission, 1.0);
    float p = length(r.f);
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
    uint FragIdx = uint(gl_FragCoord.x + gl_FragCoord.y * width);
    rngInit(rng, uint64_t(frameIdx), uint64_t(FragIdx));

    out_pos = vec4(P, 1.0f);
    out_normal = vec4(N, 1.0f);

    vec3 color = vec3(0.0f);


    // TODO: implement multiple samples for restir (N=4?)
    // This requires a reservoir buffer for every sample
    if (sample_mode == SAMPLE_MODE_RESTIR) {
        Reservoir r = streamingRis(rng);

        vec3 pos = r.out_sample;
        vec3 PL = pos-P;
        vec3 dir = normalize(PL);
        float dist = length(PL);
        Ray ray = createRay(P + N * 1e-5, dir, 0, dist-1e-3);
        if ( traceRay( ray ) ) {
            r.W = 0.0;
        }
        // r.f = vec3(1.0, 0.0, 0.0);
        reservoirs[FragIdx] = r;
        out_color.xyz = vec3(0.1, 0.0, 0.0); // Dark red
        return;
    }

    for (int i = 0; i < n_samples; i++) {
        if (sample_mode == SAMPLE_MODE_UNIFORM) {
            vec3 rnd = rngRndVec3(rng);
            vec3 pos, emission;
            float pdf;
            sampleLight(rnd, emission, pos, pdf);

            vec3 PL = pos-P;
            vec3 dir = normalize(PL);
            float dist = length(PL);
            Ray r = createRay(P + N * 1e-5, dir, 0, dist-1e-3);
            // cast shadow ray, accumulate lighting if no intersection
            if ( !traceRay( r ) ) {
                vec3 f = directLight(P, pos, emission, pdf);
                color += f;
            }
        } else if (sample_mode == SAMPLE_MODE_RIS) {
            vec3 rnd = rngRndVec3(rng);
            vec3 pos, emission;
            float pdf;
            // sampleLight(rnd, emission, pos, pdf);
            float weight;
            sampleRis(pos, emission, weight, rng);

            vec3 PL = pos-P;
            vec3 dir = normalize(PL);
            float dist = length(PL);
            Ray r = createRay(P + N * 1e-5, dir, 0, dist-1e-3);
            // cast shadow ray, accumulate lighting if no intersection
            if ( !traceRay( r ) ) {
                vec3 f = directLight(P, pos, emission, 1.0);
                if (length(f) > 1e-6) {
                    float p = length(f);
                    color += f / p * weight / float(N_CANDIDATES);
                }
            }
        } else if (sample_mode == SAMPLE_MODE_STREAMING_RIS) {
            Reservoir r = streamingRis(rng);

            vec3 pos = r.out_sample;
            vec3 PL = pos-P;
            vec3 dir = normalize(PL);
            float dist = length(PL);
            Ray ray = createRay(P + N * 1e-5, dir, 0, dist-1e-3);
            // cast shadow ray, accumulate lighting if no intersection
            if ( !traceRay( ray ) ) {
                color += r.f * r.W;
            }
        } else {
           out_color.xyz = vec3(1.0f, 1.0f, 0.0f);
           return;
        }
    }

    out_color.xyz = color / float(n_samples);

/*
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

    */

}
