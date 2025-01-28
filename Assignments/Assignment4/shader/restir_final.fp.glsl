#version 430
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_gpu_shader_int64 : require

#include "shared.h.glsl"

out vec4 out_color;


// If you need the texture coords from the vertex shader:
in vec2 v_texcoord;

#include "common.h.glsl"
#include "lightlist.h.glsl"
#include "raytrace.h.glsl"

uniform int width, height;

uniform int frameIdx;

uniform int n_samples;

void main()
{
    uint FragIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
    GBufferInfo gBufferInfo = gBuffer[FragIdx];

    vec3 P = gBufferInfo.position;
    vec3 N = gBufferInfo.normal;

    vec3 color = vec3(0.0);
    for (int i = 0; i < n_samples; i++) {
        Reservoir r = reservoirIn[FragIdx + i * width * height];
        vec3 contrib = directLight(
            gBufferInfo.position, gBufferInfo.normal, gBufferInfo.albedo, r.out_sample, r.out_normal, r.emission
        );
        
        vec3 dir = r.out_sample - P;
        Ray ray = createRay(P + N * 1e-5, normalize(dir), 0, length(dir)-1e-3);
        if ( castRay( ray ) ) {
            r.W = 0.0;
        }
        color += contrib * r.W;
    }

    out_color.xyz = color / float(n_samples);
}
