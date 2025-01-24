#ifndef GLSL_SHARED
#define GLSL_SHARED

#ifdef __cplusplus

#define FLOAT float
#define UINT uint32_t
#define VEC3 glm::vec3
#define VEC4 glm::vec4
#define MAT3 glm::mat3
#define MAT4 glm::mat4

#else

#define FLOAT float
#define UINT uint
#define VEC3 vec3
#define VEC4 vec4
#define MAT3 mat3
#define MAT4 mat4

#endif

#define RESERVOIR_BUFFER_IN_BINDING 8
#define RESERVOIR_BUFFER_OUT_BINDING 9
#define GBUFFER_BINDING 10
#define GBUFFER_LAST_FRAME_BINDING 11

struct GpuEmissiveTriangle {
    FLOAT data[12]; // Stores (p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, p3.x, p3.y, p3.z, emission.x, emission.y, emission.z)
};

#undef FLOAT
#undef UINT
#undef VEC3
#undef VEC4
#undef MAT3
#undef MAT4

#endif
