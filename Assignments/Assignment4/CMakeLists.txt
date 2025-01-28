cmake_minimum_required(VERSION 3.16.0 FATAL_ERROR)
project(Assignment4)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(SOURCE_FILES
    assignment4.cpp
    lightlist.cpp
    framecapture.cpp
)

set(HEADER_FILES
    lightlist.h
    cbox.h
    stb_image_write.h
    framecapture.h
)

add_executable(${PROJECT_NAME} ${SOURCE_FILES} ${HEADER_FILES})
target_link_libraries(${PROJECT_NAME} PRIVATE GLF)

# Set the Visual Studio debugger's working directory to the top-level source directory (project folder)
if(WIN32)
    set_target_properties(
        ${PROJECT_NAME} PROPERTIES
        VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    )
endif()
