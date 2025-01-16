#ifndef GLSL_COMMON
#define GLSL_COMMON

const float M_PI = 3.1415926535897932384626433832795;

// functions to convert arrays in buffers to vec types

vec2 unpack(float arr[2]) {
    return vec2(arr[0], arr[1]);
}

vec3 unpack(float arr[3]) {
    return vec3(arr[0], arr[1], arr[2]);
}

uvec2 unpack(uint arr[2]) {
    return uvec2(arr[0], arr[1]);
}

uvec3 unpack(uint arr[3]) {
    return uvec3(arr[0], arr[1], arr[2]);
}

// functions to write to arrays in buffers with vec types

void write(out float arr[2], vec2 vec) {
    for (int i = 0; i < 2; i++)
        arr[i] = vec[i];
}

void write(out float arr[3], vec3 vec) {
    for (int i = 0; i < 3; i++)
        arr[i] = vec[i];
}

void write(out uint arr[2], uvec2 vec) {
    for (int i = 0; i < 2; i++)
        arr[i] = vec[i];
}

void write(out uint arr[3], uvec3 vec) {
    for (int i = 0; i < 3; i++)
        arr[i] = vec[i];
}

// sample warping function

vec3 squareToUniformSphere(vec2 rnd) {
    float z = 1.0f - 2.0f * rnd.y;
    float r = sqrt(1.0f - z*z);
    float phi = 2.0f * M_PI * rnd.x;
    return vec3(r * cos(phi), r * sin(phi), z);
}

float pdfSquareToUniformSphere(vec3 dir) {
    return 1.f / (4.f * M_PI);
}

vec3 squareToUniformHemisphere(vec2 rnd) {
    float z = rnd.y;
    float tmp = sqrt(1.f - z*z);
    float phi = 2.0f * M_PI * rnd.x;
    return vec3(cos(phi) * tmp, sin(phi) * tmp, z);
}

float pdfSquareToUniformHemisphere(vec3 dir) {
    return 1.f / (2.f * M_PI);
}

// Orthonormal Basis (z-axis is normal)

mat3 onb(vec3 n)
{
    float sign = n.z < 0 ? -1 : 1;
    const float a = -1.0f / (sign + n.z);
    const float b = n.x * n.y * a;
    return mat3(
        vec3(1.0f + sign * n.x * n.x * a, sign * b, -sign * n.x),
        vec3(b, sign + n.y * n.y * a, -n.y),
        n
    );
}

#endif
