cmake_minimum_required(VERSION 3.20)

project(vkmt-ci-cmake-smoke VERSION 1.0 LANGUAGES C)

include(CTest)

add_executable(vkmt-ci-cmake-smoke smoke.c)
target_compile_features(vkmt-ci-cmake-smoke PRIVATE c_std_11)

if (CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(vkmt-ci-cmake-smoke PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

if (BUILD_TESTING)
    add_test(NAME vkmt-ci-cmake-smoke COMMAND vkmt-ci-cmake-smoke)
endif()
