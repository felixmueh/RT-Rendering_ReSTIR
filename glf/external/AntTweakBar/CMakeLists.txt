cmake_minimum_required(VERSION 3.0...3.20 FATAL_ERROR)

project(AntTweakBar)

set(SOURCES
        "src/LoadOGL.cpp"
        "src/LoadOGLCore.cpp"
        "src/TwBar.cpp"
        "src/TwColors.cpp"
        "src/TwEventGLFW.c"
        "src/TwFonts.cpp"
        "src/TwMgr.cpp"
        "src/TwOpenGL.cpp"
        "src/TwOpenGLCore.cpp"
        "src/TwPrecomp.cpp"
)

add_library(${PROJECT_NAME} ${SOURCES})
target_include_directories(${PROJECT_NAME} PUBLIC include/)