cmake_minimum_required(VERSION 3.22.1)

project(whisper LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(WHISPER_THIRD_PARTY_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/third_party"
    CACHE PATH "Path to folder that contains whisper.cpp")
set(WHISPER_CPP_SOURCE "${WHISPER_THIRD_PARTY_DIR}/whisper.cpp")

set(WHISPER_SOURCES
        whisper_jni.cpp)

if(EXISTS "${WHISPER_CPP_SOURCE}")
    message(STATUS "Linking bundled whisper.cpp from ${WHISPER_CPP_SOURCE}")
    add_definitions(-DSMART_TUTOR_HAS_WHISPER=1)
    list(APPEND WHISPER_SOURCES "${WHISPER_CPP_SOURCE}")
    set(WHISPER_INCLUDE_DIRS "${WHISPER_THIRD_PARTY_DIR}")
else()
    message(WARNING "whisper.cpp not found. Native transcription will run in stub mode.")
    set(WHISPER_INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}")
endif()

add_library(whisper SHARED ${WHISPER_SOURCES})

target_include_directories(
        whisper
        PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${WHISPER_INCLUDE_DIRS})

target_compile_options(
        whisper
        PRIVATE
        -Wall
        -Werror
        -Wno-unused-parameter)

find_library(log-lib log)

target_link_libraries(whisper PRIVATE ${log-lib})

