cmake_minimum_required(VERSION 3.10)

project(cactus)

set(CMAKE_CXX_STANDARD 17)
set(SOURCE_DIR ${CMAKE_SOURCE_DIR}/../../../../cpp)

include_directories(${SOURCE_DIR})

set(
    SOURCE_FILES

    # FFI bindings
    ${SOURCE_DIR}/cactus_ffi.cpp
)

find_library(LOG_LIB log)

function(build_library target_name cpu_flags)
    add_library(
        ${target_name}
        SHARED
        ${SOURCE_FILES}
    )

    target_link_libraries(${target_name} ${LOG_LIB} android)

    target_compile_options(${target_name} PRIVATE -DLM_GGML_USE_CPU -DLM_GGML_USE_CPU_AARCH64 -pthread ${cpu_flags})

    if (${CMAKE_BUILD_TYPE} STREQUAL "Debug")
        target_compile_options(${target_name} PRIVATE -DCACTUS_ANDROID_ENABLE_LOGGING)
    endif ()

    target_compile_options(${target_name} PRIVATE -O3 -DNDEBUG)
    target_compile_options(${target_name} PRIVATE -fvisibility=hidden -fvisibility-inlines-hidden)
    target_compile_options(${target_name} PRIVATE -ffunction-sections -fdata-sections)

    target_link_options(${target_name} PRIVATE -Wl,--gc-sections)
    target_link_options(${target_name} PRIVATE -Wl,--exclude-libs,ALL)
    target_link_options(${target_name} PRIVATE -flto)

endfunction()

build_library("cactus" "")

if (${ANDROID_ABI} STREQUAL "arm64-v8a")
    build_library("cactus_v8" "-march=armv8-a")
    build_library("cactus_v8_2" "-march=armv8.2-a")
    build_library("cactus_v8_2_dotprod" "-march=armv8.2-a+dotprod")
    build_library("cactus_v8_2_i8mm" "-march=armv8.2-a+i8mm")
    build_library("cactus_v8_2_dotprod_i8mm" "-march=armv8.2-a+dotprod+i8mm")

elseif (${ANDROID_ABI} STREQUAL "x86_64")
    build_library("cactus_x86_64" "-march=x86-64" "-mtune=intel" "-msse4.2" "-mpopcnt")

endif ()