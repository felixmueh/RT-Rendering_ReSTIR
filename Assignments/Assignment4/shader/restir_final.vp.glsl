#version 450

layout(location=0) in vec2 in_position;
layout(location=1) in vec2 in_texcoord;

// Pass any relevant data to the fragment shader:
out vec2 v_texcoord;

void main()
{
    v_texcoord = in_texcoord;

    // A simple pass-through that places the quad over the entire screen
    gl_Position = vec4(in_position, 0.0, 1.0);
}
