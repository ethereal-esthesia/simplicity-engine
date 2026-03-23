cmake_minimum_required(VERSION 3.21)

if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

project(simplicity_engine C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

include(FetchContent)

set(SDL_TEST OFF CACHE BOOL "Disable SDL tests" FORCE)
set(SDL_SHARED ON CACHE BOOL "Build SDL shared library" FORCE)

FetchContent_Declare(
  SDL2
  URL https://github.com/libsdl-org/SDL/releases/download/release-2.32.8/SDL2-2.32.8.tar.gz
)
FetchContent_MakeAvailable(SDL2)

add_executable(hello_pixel src/main.c)

target_link_libraries(hello_pixel PRIVATE SDL2::SDL2)
