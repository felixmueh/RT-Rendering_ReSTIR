cmake_minimum_required(VERSION 3.16.0 FATAL_ERROR)

project(RCGI C CXX)

set(CMAKE_CXX_STANDARD 17)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/glf)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})


foreach (num RANGE 1 4)
    add_subdirectory(${CMAKE_SOURCE_DIR}/Assignments/Assignment${num})
endforeach ()
