cmake_minimum_required(VERSION 3.21)

if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

project(simplicity_engine CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(FetchContent)

set(SDL_TEST OFF CACHE BOOL "Disable SDL tests" FORCE)
set(SDL_SHARED ON CACHE BOOL "Build SDL shared library" FORCE)

FetchContent_Declare(
  SDL3
  URL https://github.com/libsdl-org/SDL/releases/download/release-3.2.8/SDL3-3.2.8.tar.gz
)
FetchContent_MakeAvailable(SDL3)

add_executable(hello_pixel src/main.cpp)
add_executable(smoke_sdl_init tests/smoke_sdl_init.cpp)
add_executable(smoke_fast_rng tests/smoke_fast_rng.cpp)

target_link_libraries(hello_pixel PRIVATE SDL3::SDL3)
target_link_libraries(smoke_sdl_init PRIVATE SDL3::SDL3)
target_include_directories(smoke_fast_rng PRIVATE src)

enable_testing()
if(WIN32)
  add_test(
    NAME smoke_sdl_init
    COMMAND
      ${CMAKE_COMMAND} -E env "PATH=$<TARGET_FILE_DIR:SDL3::SDL3>;$ENV{PATH}"
      $<TARGET_FILE:smoke_sdl_init>)
else()
  add_test(NAME smoke_sdl_init COMMAND smoke_sdl_init)
endif()
set_tests_properties(smoke_sdl_init PROPERTIES LABELS smoke)
add_test(NAME smoke_fast_rng COMMAND smoke_fast_rng)
set_tests_properties(smoke_fast_rng PROPERTIES LABELS smoke)
