cmake_minimum_required(VERSION 3.16)
project(libraries)

# glfw
set(GLFW_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/GLFW/include PARENT_SCOPE)
set(GLFW_LIBRARY_TYPE STATIC CACHE STRING "" FORCE)
set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)

add_subdirectory(GLFW)
set_property(TARGET glfw PROPERTY FOLDER "external")

#AntTweakBar
set(AntTweakBar_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/AntTweakBar/include PARENT_SCOPE)

add_subdirectory(AntTweakBar)
set_property(TARGET AntTweakBar PROPERTY FOLDER "external")