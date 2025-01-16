#version 430
#extension GL_ARB_texture_multisample : enable
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_gpu_shader_int64 : require

#include "shared.h.glsl"

uniform sampler2D   tColor; 
uniform sampler2D   tPosition; 
uniform sampler2D   tNormal; 

uniform int width, height;
uniform int rendermode;

in  vec2 texcoord;
out vec4 result;

uniform float _exposure;    /*## Exposure 0.25 -4.0 10.0 0.05 */
uniform float _gamma;		/*## Gamma 1.5 0.1 3.0 0.1 */


void main(void)
{
    // use the alpha channel of the GBuffer to determine if we see the environment map or geometry
    vec4 tpos = textureLod( tPosition, texcoord.xy, 0.0 );
    bool is_env = tpos.w < 0.5;
    if(is_env) {
        // no geometry, draw skybox
        result = vec4(0);
    } else {
        result = vec4(0,0,0,1);
    }

    if (rendermode == 1) {
        // draw normal
        result.xyz = 0.5f * textureLod( tNormal, texcoord.xy, 0.0 ).xyz + vec3(0.5);
        return;
    }
    if (rendermode == 2) {
        // draw position
        result.xyz = tpos.xyz;
        return;
    }

    // we have geometry, load the fragment color and apply gamma correction
    vec3 out_color = textureLod( tColor, texcoord.xy, 0.0 ).xyz;
	out_color *= pow( 2.0, _exposure );
	out_color = pow( out_color, 1.0 / vec3( _gamma ) );
	result.xyz = out_color;
}
