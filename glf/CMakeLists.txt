cmake_minimum_required(VERSION 3.16.0 FATAL_ERROR)
project(GLF)

find_package(OpenGL REQUIRED)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/external)

set(SOURCES
        "envmap.cpp"
        "framebufferObject.cpp"
        "glErrorUtil.cpp"
        "glew.cpp"
        "glm.cpp"
        "guifont.cpp"
        "helpers.cpp"
        "IMWrapper.cpp"
        "lens.cpp"
        "OpenGLText.cpp"
        "render.cpp"
        "renderbuffer.cpp"
        "rgbe.cpp"
        "stdafx.cpp"
        "texture.cpp"
        "texturemanager.cpp"
        "tiny_obj_loader.cpp"
        "trackball.cpp"
        "tweakBarGLSLUniforms.cpp"
)

add_library(${PROJECT_NAME} ${SOURCES})
target_include_directories(${PROJECT_NAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${GLFW_INCLUDE} ${AntTweakBar_INCLUDE})
target_link_libraries(${PROJECT_NAME} PUBLIC glfw OpenGL::GL OpenGL::GLU AntTweakBar)

find_package(OpenMP)
if(OpenMP_CXX_FOUND)
    target_link_libraries(${PROJECT_NAME} PUBLIC OpenMP::OpenMP_CXX)
endif()