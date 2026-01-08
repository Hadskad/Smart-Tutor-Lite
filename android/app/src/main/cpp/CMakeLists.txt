cmake_minimum_required(VERSION 3.22.1)

project(whisper LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# whisper.cpp v1.8.2 directory structure
set(WHISPER_THIRD_PARTY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party")
set(WHISPER_SRC_DIR "${WHISPER_THIRD_PARTY_DIR}/src")
set(WHISPER_INCLUDE_DIR "${WHISPER_THIRD_PARTY_DIR}/include")
set(GGML_DIR "${WHISPER_THIRD_PARTY_DIR}/ggml")

# Check if whisper.cpp source exists
set(WHISPER_CPP_SOURCE "${WHISPER_SRC_DIR}/whisper.cpp")

if(EXISTS "${WHISPER_CPP_SOURCE}")
    message(STATUS "Building whisper.cpp v1.8.2 from ${WHISPER_SRC_DIR}")
    add_definitions(-DSMART_TUTOR_HAS_WHISPER=1)

    # Enable CPU backend
    add_definitions(-DGGML_USE_CPU=1)

    # Build GGML as subdirectory
    set(GGML_STANDALONE OFF CACHE BOOL "" FORCE)
    set(GGML_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(GGML_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(GGML_METAL OFF CACHE BOOL "" FORCE)
    set(GGML_CUDA OFF CACHE BOOL "" FORCE)
    set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
    set(GGML_OPENCL OFF CACHE BOOL "" FORCE)
    add_subdirectory(${GGML_DIR} ggml_build)

    # Whisper library sources
    set(WHISPER_SOURCES
        whisper_jni.cpp
        ${WHISPER_CPP_SOURCE}
    )

    # Create whisper shared library
    add_library(whisper SHARED ${WHISPER_SOURCES})

    # Include directories
    target_include_directories(whisper PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${WHISPER_INCLUDE_DIR}
        ${WHISPER_SRC_DIR}
        ${GGML_DIR}/include
        ${GGML_DIR}/src
        ${GGML_DIR}/src/ggml-cpu
    )

    # Link against GGML
    target_link_libraries(whisper PRIVATE ggml)

    # Define WHISPER_VERSION required by v1.8.2
    target_compile_definitions(whisper PRIVATE
        WHISPER_VERSION="1.8.2"
    )

else()
    message(WARNING "whisper.cpp not found at ${WHISPER_CPP_SOURCE}. Building stub mode.")

    set(WHISPER_SOURCES whisper_jni.cpp)
    add_library(whisper SHARED ${WHISPER_SOURCES})
    target_include_directories(whisper PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
endif()

# Compiler options
target_compile_options(whisper PRIVATE
    -Wall
    -Wno-unused-parameter
    -Wno-unused-function
    -O3
)

# Release optimizations
if(NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(whisper PRIVATE
        -fvisibility=hidden
        -fvisibility-inlines-hidden
        -ffunction-sections
        -fdata-sections
    )
    target_link_options(whisper PRIVATE
        -Wl,--gc-sections
        -Wl,--exclude-libs,ALL
    )
endif()

# Link Android log library
find_library(log-lib log)
target_link_libraries(whisper PRIVATE ${log-lib} android)
