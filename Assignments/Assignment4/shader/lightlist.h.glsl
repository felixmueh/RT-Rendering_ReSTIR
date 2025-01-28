#ifndef GLSL_LIGHTLIST
#define GLSL_LIGHTLIST
#define SAMPLE_ALIAS

#include "shared.h.glsl"
#include "rng.h.glsl"

struct Reservoir {      // Size for correct alignment: 48 Bytes
    vec3 out_sample;    // 12 
    float weight_sum;   // 4
    vec3 emission;      // 12
    float W;            // 4
    vec3 out_normal;    // 12 
    int sample_count;   // 4
};

struct GBufferInfo {
    vec3 normal;
    vec3 position;
    vec3 albedo;
    int frame;
};

Reservoir new_reservoir() {
    Reservoir r;
    r.out_sample = vec3(0.0);
    r.out_normal = vec3(0.0);
    r.emission = vec3(0.0);
    r.W = 0.0;
    r.weight_sum = 0.0;
    r.sample_count = 0;
    return r;
}

// evaluate rendering equation for a given surface (pos, normal, albedo) and light source (light_pos, light_normal, emission)
vec3 directLight(vec3 pos, vec3 normal, vec3 albedo, vec3 light_pos, vec3 light_normal, vec3 emission) {
    vec3 PL = light_pos-pos;
    vec3 dir = normalize(PL);
    float dist = length(PL);
    float cosThetaL = abs(dot(-dir, light_normal)); // NOTE: our emissive triangles emit light in both directions...
    float cosTheta = max(dot(dir, normal), 0.0);    // ... but surfaces are illuminated only at the front facing side
    float geometry_term = cosTheta * cosThetaL / (dist*dist);
    return emission * albedo * geometry_term;
}

void update_reservoir(inout Reservoir reservoir, vec3 y, vec3 n, vec3 emission, float weight, inout Rng rng) {
    reservoir.sample_count++;
    reservoir.weight_sum += weight;
    if (rngRndFloat(rng) < weight / reservoir.weight_sum) {
        reservoir.out_sample = y;
        reservoir.out_normal = n;
        reservoir.emission = emission;
    }
}

// Reservoir s;
// for (auto r : reservoirs) {
//     combine_reservoirs(s, r, gBuffer);
// }
// s.M =
// s.W =
// return s;

void combine_reservoirs(inout Reservoir s, Reservoir r, GBufferInfo g, inout Rng rng) {
    // recalculate the approximate rendering equation for the current frame
    vec3 contrib = directLight(
            g.position, g.normal, g.albedo, r.out_sample, r.out_normal, r.emission
        );
    update_reservoir(
        s, r.out_sample, r.out_normal, r.emission, length(contrib) * r.W * r.sample_count,
        rng
    );
}

float relative_distance(vec3 a, vec3 b) {
    return length(a - b) / max(length(a), length(b));
}

bool validate_reuse(GBufferInfo p, GBufferInfo q, float threshold_normal, float threshold_albedo, float threshold_position) {
    if (dot(p.normal, q.normal) < cos(threshold_normal * M_PI / 180)) {
        return false; // normals are too different
    }

    if (length(p.albedo - q.albedo) > threshold_albedo) {
        return false; // albedo is too different
    }

    if (relative_distance(p.position, q.position) > threshold_position) {
        return false; // albedo is too different
    }
    return true;
}

layout (std430, binding = 6) buffer bEmissiveTriangles
{ 
  GpuEmissiveTriangle emissiveTriangles[];
};

layout(std430, binding = ALIAS_PROB_BINDING) buffer bAliasProb
{
    float emissiveAliasPdf[];  // scaled probabilities in [0,1]
};

layout(std430, binding = ALIAS_IDX_BINDING) buffer bAliasIndex
{
    uint emissiveAliasIdx[];
};

layout(std430, binding = RESERVOIR_BUFFER_IN_BINDING) buffer bReservoirIn {
    Reservoir reservoirIn[];
};

layout(std430, binding = RESERVOIR_BUFFER_OUT_BINDING) buffer bReservoirOut {
    Reservoir reservoirOut[];
};

layout(std430, binding = GBUFFER_BINDING) buffer bGBuffer {
    GBufferInfo gBuffer[];
};

layout(std430, binding = GBUFFER_LAST_FRAME_BINDING) buffer bGBufferLastFrame {
    GBufferInfo gBufferLastFrame[];
};

layout(std430, binding = TRIANGLE_CDF_BINDING) buffer bEmissiveCDF {
    float emissiveCDF[];
};

uniform float totalArea;
uniform int nEmissiveTriangles;

void unpackEmissiveTriangle(in GpuEmissiveTriangle t, out vec3 p1, out vec3 p2, out vec3 p3, out vec3 emission) {
    p1 = vec3(t.data[0], t.data[1], t.data[2]);
    p2 = vec3(t.data[3], t.data[4], t.data[5]);
    p3 = vec3(t.data[6], t.data[7], t.data[8]);
    emission = vec3(t.data[9], t.data[10], t.data[11]);
}

void unpackEmissiveTriangle(in GpuEmissiveTriangle t, out vec3 emission) {
    emission = vec3(t.data[9], t.data[10], t.data[11]);
}

void unpackEmissiveTriangle(in GpuEmissiveTriangle t, out vec3 p1, out vec3 p2, out vec3 p3) {
    p1 = vec3(t.data[0], t.data[1], t.data[2]);
    p2 = vec3(t.data[3], t.data[4], t.data[5]);
    p3 = vec3(t.data[6], t.data[7], t.data[8]);
}

vec3 samplePoint(GpuEmissiveTriangle t, vec2 rnd) {
    // Unpack the triangle's vertices and emission values
    vec3 p1, p2, p3;
    unpackEmissiveTriangle(t, p1, p2, p3);

    // Compute the barycentric coordinates for uniform sampling
    float sqrt_r1 = sqrt(rnd.x);
    float lambda1 = 1.0 - sqrt_r1;
    float lambda2 = sqrt_r1 * (1.0 - rnd.y);
    float lambda3 = sqrt_r1 * rnd.y;

    // Sample the point on the triangle using the barycentric coordinates
    vec3 sampledPoint = lambda1 * p1 + lambda2 * p2 + lambda3 * p3;

    return sampledPoint;
}

uint sampleTriangleCDFSum(float rnd) {
  uint i = 0;
  while(emissiveCDF[i] < rnd) {
    i++;
  }
  return i;
}

// Sample a triangle using alias (Walker) table
uint sampleTriangle(float rnd) {
    // Convert rnd in [0,1] to an integer in [0, nEmissiveTriangles-1]
    float scaled = rnd * float(nEmissiveTriangles);
    uint i = uint(floor(scaled));
    float r = fract(scaled);

    // If the fraction is below the pdf threshold, pick i, else alias
    return (r < emissiveAliasPdf[i]) ? i : emissiveAliasIdx[i];
}

// draw a random sample from the emissive triangles
void sampleLight(vec3 rnd, out vec3 emission, out vec3 pos, out vec3 normal, out float pdf) {
#ifdef SAMPLE_ALIAS
  GpuEmissiveTriangle triangle = emissiveTriangles[sampleTriangle(rnd.x)];
#else
  GpuEmissiveTriangle triangle = emissiveTriangles[sampleTriangleCDFSum(rnd.x)];
#endif
  vec3 p1, p2, p3;
  unpackEmissiveTriangle(triangle, p1, p2, p3, emission);
  pos = samplePoint(triangle, rnd.yz);
  pdf = 1.0 / totalArea;
  normal = normalize(cross(p2 - p1, p3 - p1));
}

float min_dist_to_triangle_vertices(vec3 pos) {
    float min_dist = 1e30;
    for (int idx = 0; idx < emissiveTriangles.length(); idx++) {
        vec3 v0, v1, v2;
        unpackEmissiveTriangle(emissiveTriangles[idx], v0, v1, v2);

        min_dist = min(min_dist, distance(v0, pos));
        min_dist = min(min_dist, distance(v1, pos));
        min_dist = min(min_dist, distance(v2, pos));
    }
    return min_dist;
}


#endif // GLSL_LIGHTLIST
