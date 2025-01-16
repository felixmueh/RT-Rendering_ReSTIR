//
// Created by Bene on 12/09/2024.
//

#ifndef OPENGL_DEBUG_H
#define OPENGL_DEBUG_H
#include <GL/glew.h>  // or your appropriate OpenGL loader
#include <iostream>
#include <sstream>

// Debug callback function
void GLAPIENTRY openglDebugCallback(GLenum source, GLenum type, GLuint id, GLenum severity,
                                    GLsizei length, const GLchar* message, const void* userParam) {
    std::stringstream sstream;
    sstream << "OpenGL Debug Message: " << message << std::endl;

    // Optional: You can customize this to print more detailed info
    switch (source) {
        case GL_DEBUG_SOURCE_API:
            sstream << "Source: API";
            break;
        case GL_DEBUG_SOURCE_WINDOW_SYSTEM:
            sstream << "Source: Window System";
            break;
        case GL_DEBUG_SOURCE_SHADER_COMPILER:
            sstream << "Source: Shader Compiler";
            break;
        case GL_DEBUG_SOURCE_THIRD_PARTY:
            sstream << "Source: Third Party";
            break;
        case GL_DEBUG_SOURCE_APPLICATION:
            sstream << "Source: Application";
            break;
        case GL_DEBUG_SOURCE_OTHER:
            sstream << "Source: Other";
            break;
    }

    sstream << ", Type: ";
    switch (type) {
        case GL_DEBUG_TYPE_ERROR:
            sstream << "Error";
            break;
        case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR:
            sstream << "Deprecated Behavior";
            break;
        case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:
            sstream << "Undefined Behavior";
            break;
        case GL_DEBUG_TYPE_PORTABILITY:
            sstream << "Portability Issue";
            break;
        case GL_DEBUG_TYPE_PERFORMANCE:
            sstream << "Performance Issue";
            break;
        case GL_DEBUG_TYPE_MARKER:
            sstream << "Command Stream Annotation";
            break;
        case GL_DEBUG_TYPE_PUSH_GROUP:
            sstream << "Group Pushed";
            break;
        case GL_DEBUG_TYPE_POP_GROUP:
            sstream << "Group Popped";
            break;
        case GL_DEBUG_TYPE_OTHER:
            sstream << "Other";
            break;
    }

    sstream << ", Severity: ";
    switch (severity) {
        case GL_DEBUG_SEVERITY_HIGH:
            sstream << "High";
            break;
        case GL_DEBUG_SEVERITY_MEDIUM:
            sstream << "Medium";
            break;
        case GL_DEBUG_SEVERITY_LOW:
            sstream << "Low";
            break;
        case GL_DEBUG_SEVERITY_NOTIFICATION:
            sstream << "Notification";
            return;
    }
    std::cerr << sstream.str() << std::endl;
}

// Function to initialize the debug callback
void initializeOpenGLDebugCallback() {
    glEnable(GL_DEBUG_OUTPUT);               // Enable the debug output
    glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);   // Make sure the output is synchronous (helps in debugging)
    glDebugMessageCallback(openglDebugCallback, nullptr);  // Register the callback
    glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, nullptr, GL_TRUE);  // Enable all messages
}

#endif //OPENGL_DEBUG_H
