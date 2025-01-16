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

#undef FLOAT
#undef UINT
#undef VEC3
#undef VEC4
#undef MAT3
#undef MAT4

#endif
