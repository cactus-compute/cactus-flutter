cmake_minimum_required(VERSION 3.10.2)

project("cactus")

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(cactus_static STATIC IMPORTED)
set_target_properties(cactus_static PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/lib/${ANDROID_ABI}/libcactus.a)

add_library(cactus SHARED
    cactus_jni.cpp
)

# Set compilation flags to match the static library
target_compile_options(cactus PRIVATE
    -fno-limit-debug-info
    -fdata-sections
    -ffunction-sections
)

# Link libraries
target_link_libraries(cactus
    cactus_static
    android
    log
)

# Include directories
target_include_directories(cactus PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)
