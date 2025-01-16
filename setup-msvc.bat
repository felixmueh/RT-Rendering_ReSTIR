@echo off
REM Step 1: Create build directory if it doesn't exist
if not exist build (
    mkdir build
)

REM Step 2: Navigate to build directory and run CMake
cd build
cmake ..

REM Step 3: Open the solution file in Visual Studio
start "" "RCGI.sln"

REM Step 4: Open the shader folder in VS Code
cd ..
start code Assignments\Assignment4\shader
