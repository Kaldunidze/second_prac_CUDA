cmake_minimum_required(VERSION 3.18)
project(Jacobi3D_Project LANGUAGES CXX CUDA)

# --- 1. Configuration & Arguments ---

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type (Debug/Release)" FORCE)
endif()

set(L 256 CACHE STRING "Size of the arrays")

# --- 2. CUDA Architectures Fix ---
# Explicitly set architectures to avoid "must be non-empty" error.
set(CMAKE_CUDA_ARCHITECTURES "60;70;80" CACHE STRING "CUDA architectures" FORCE)

# --- 3. Executable Definitions ---

# CPU Version
add_executable(adi3d_cpu adi3d_cpu.cpp)
find_package(OpenMP REQUIRED)
target_link_libraries(adi3d_cpu PRIVATE OpenMP::OpenMP_CXX)
target_compile_options(adi3d_cpu PRIVATE $<$<CONFIG:Release>:-O3> $<$<CONFIG:Debug>:-g -O0>)

# GPU Version
add_executable(adi3d_gpu adi3d_gpu.cu)
target_compile_options(adi3d_gpu PRIVATE 
    $<$<CONFIG:Release>:-O3> 
    $<$<CONFIG:Debug>:-g -G -O0>
)

# Comparison Program
add_executable(compare compare.cpp)
target_compile_options(compare PRIVATE $<$<CONFIG:Release>:-O3> $<$<CONFIG:Debug>:-g>)


# --- 4. Custom Targets ---

# Determine output filenames based on executable names
set(CPU_OUT_FILE "${CMAKE_BINARY_DIR}/adi3d_cpu_out")
set(GPU_OUT_FILE "${CMAKE_BINARY_DIR}/adi3d_gpu_out")

# Target: run_cpu
# Runs the CPU version. The program itself creates "adi3d_cpu_out" in the working dir.
add_custom_target(run_cpu
    COMMAND adi3d_cpu ${L}
    DEPENDS adi3d_cpu
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running CPU version (L=${L}) -> generating ${CPU_OUT_FILE}"
    VERBATIM
)

# Target: run_gpu
# Runs the GPU version. The program itself creates "adi3d_gpu_out".
add_custom_target(run_gpu
    COMMAND adi3d_gpu ${L}
    DEPENDS adi3d_gpu
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running GPU version (L=${L}) -> generating ${GPU_OUT_FILE}"
    VERBATIM
)

# Target: run_compare
# Runs both previous targets to generate files, then runs the compare tool.
add_custom_target(run_compare
    COMMAND compare ${L} ${CPU_OUT_FILE} ${GPU_OUT_FILE}
    DEPENDS compare
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Comparing binary outputs"
    VERBATIM
)

# Force run_compare to update the files by running the programs first
add_dependencies(run_compare run_cpu run_gpu)