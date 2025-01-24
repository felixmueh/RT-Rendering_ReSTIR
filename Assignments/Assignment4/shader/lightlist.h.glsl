#ifndef GLSL_LIGHTLIST
#define GLSL_LIGHTLIST

#include "shared.h.glsl"
#include "rng.h.glsl"

struct Reservoir {
    vec3 out_sample;
    vec3 emission;
    float weight_sum;
    float W;
    int sample_count;
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
    r.emission = vec3(0.0);
    r.W = 0.0;
    r.weight_sum = 0.0;
    r.sample_count = 0;
    return r;
}

vec3 directLight(vec3 pos, vec3 light_pos, vec3 emission, vec3 normal, vec3 albedo) {
    vec3 PL = light_pos-pos;
    vec3 dir = normalize(PL);
    float dist = length(PL);
    float geometry_term = max(dot(dir, normal), 0.0) / (dist*dist); // for area lights we could use cosTheta at light normal as well
    return emission * albedo * geometry_term;
}

void update_reservoir(inout Reservoir reservoir, vec3 y, vec3 emission, float weight, inout Rng rng) {
    reservoir.sample_count++;
    reservoir.weight_sum += weight;
    if (rngRndFloat(rng) < weight / reservoir.weight_sum) {
        reservoir.out_sample = y;
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
            g.position, r.out_sample, r.emission, g.normal, g.albedo
        );
    update_reservoir(
        s, r.out_sample, r.emission, length(contrib) * r.W * r.sample_count,
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

layout (std430, binding = 7) buffer bEmissiveCDF
{ 
  float emissiveCDF[];
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

uint sampleTriangle(float rnd) {
  uint i = 0;
  while(emissiveCDF[i] < rnd) {
    i++;
  }
  return i;
}

void sampleLight(vec3 rnd, out vec3 emission, out vec3 pos, out float pdf) {
  GpuEmissiveTriangle triangle = emissiveTriangles[sampleTriangle(rnd.x)];
  unpackEmissiveTriangle(triangle, emission);
  pos = samplePoint(triangle, rnd.yz);
  pdf = 1.0 / totalArea;
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
