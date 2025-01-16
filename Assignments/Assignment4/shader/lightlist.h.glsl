#ifndef GLSL_LIGHTLIST
#define GLSL_LIGHTLIST

#include "shared.h.glsl"
#include "rng.h.glsl"

layout (std430, binding = 6) buffer bEmissiveTriangles
{ 
  GpuEmissiveTriangle emissiveTriangles[];
};

layout (std430, binding = 7) buffer bEmissiveCDF
{ 
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
    float lambda3 = rnd.y;

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


#endif // GLSL_LIGHTLIST