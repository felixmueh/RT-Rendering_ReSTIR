cmake_minimum_required(VERSION 3.16.0 FATAL_ERROR)
project(Assignment4)

add_executable(${PROJECT_NAME} "assignment4.cpp")
target_link_libraries(${PROJECT_NAME} PRIVATE GLF)

# Set the Visual Studio debugger's working directory to the top-level source directory (project folder)
if(WIN32)
    set_target_properties(
        ${PROJECT_NAME} PROPERTIES
        VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    )
endif()