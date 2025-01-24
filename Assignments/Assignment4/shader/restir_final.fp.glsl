#version 430
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_gpu_shader_int64 : require

#include "shared.h.glsl"

out vec4 out_color;


// If you need the texture coords from the vertex shader:
in vec2 v_texcoord;

#include "common.h.glsl"
#include "lightlist.h.glsl"

uniform int width, height;

uniform int frameIdx;

void main()
{
    uint FragIdx = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * width;
    GBufferInfo gBufferInfo = gBuffer[FragIdx];

    vec3 color = vec3(0.0);
    for (int i = 0; i < N_SAMPLES_ReSTIR; i++) {
        Reservoir r = reservoirIn[FragIdx + i * width * height];
        vec3 contrib = directLight(
            gBufferInfo.position, r.out_sample, r.emission, gBufferInfo.normal, gBufferInfo.albedo
        );
        color += contrib * r.W;
    }

    out_color.xyz = color / float(N_SAMPLES_ReSTIR);
}
