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

void main()
{
    uint FragIdx = uint(gl_FragCoord.x + gl_FragCoord.y * width);
    Reservoir r = reservoirs[FragIdx];

    out_color.xyz = r.f * r.W;
}
