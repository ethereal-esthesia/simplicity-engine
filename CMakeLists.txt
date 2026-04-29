cmake_minimum_required(VERSION 3.21)

if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

project(simplicity_engine C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(ANDROID)
  set(SIMPLICITY_ENGINE_APP_TARGET main)
else()
  set(SIMPLICITY_ENGINE_APP_TARGET hello_pixel)
endif()

set(
  SIMPLICITY_ENGINE_IOS_BUNDLE_IDENTIFIER
  "dev.simplicityengine.hello-pixel"
  CACHE STRING
  "Bundle identifier used for iOS simulator/device app builds")
set(
  SIMPLICITY_ENGINE_IOS_DEVICE_FAMILY
  "1,2"
  CACHE STRING
  "Apple device families for iOS builds (1=iPhone, 2=iPad)")

include(FetchContent)

set(SDL_TEST OFF CACHE BOOL "Disable SDL tests" FORCE)
if(ANDROID)
  set(SDL_SHARED ON CACHE BOOL "Build SDL shared library for Android" FORCE)
  set(SDL_STATIC OFF CACHE BOOL "Disable SDL static library for Android" FORCE)
else()
  set(SDL_SHARED OFF CACHE BOOL "Disable SDL shared library for self-contained binaries" FORCE)
  set(SDL_STATIC ON CACHE BOOL "Build SDL static library for self-contained binaries" FORCE)
endif()

FetchContent_Declare(
  SDL3
  URL https://github.com/libsdl-org/SDL/releases/download/release-3.2.8/SDL3-3.2.8.tar.gz
  URL_HASH SHA256=13388fabb361de768ecdf2b65e52bb27d1054cae6ccb6942ba926e378e00db03
)
FetchContent_MakeAvailable(SDL3)

if(ANDROID)
  add_library(${SIMPLICITY_ENGINE_APP_TARGET} SHARED src/main.cpp)
else()
  add_executable(${SIMPLICITY_ENGINE_APP_TARGET} src/main.cpp)
endif()

target_link_libraries(${SIMPLICITY_ENGINE_APP_TARGET} PRIVATE SDL3::SDL3)
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  set_target_properties(
    ${SIMPLICITY_ENGINE_APP_TARGET} PROPERTIES
      MACOSX_BUNDLE TRUE
      XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE "YES"
      XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${SIMPLICITY_ENGINE_IOS_BUNDLE_IDENTIFIER}"
      XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "${SIMPLICITY_ENGINE_IOS_DEVICE_FAMILY}"
      XCODE_ATTRIBUTE_INFOPLIST_KEY_CFBundleDisplayName "Hello Pixel"
      XCODE_ATTRIBUTE_INFOPLIST_KEY_UISupportedInterfaceOrientations "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
      XCODE_ATTRIBUTE_INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight")
endif()
if(WIN32)
  set_target_properties(${SIMPLICITY_ENGINE_APP_TARGET} PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

if(NOT ANDROID)
  add_executable(smoke_sdl_init tests/smoke_sdl_init.cpp)
  add_executable(smoke_fast_rng tests/smoke_fast_rng.cpp)
  add_executable(test_fast_rng_vectors tests/test_fast_rng_vectors.cpp)

  target_link_libraries(smoke_sdl_init PRIVATE SDL3::SDL3)
  target_include_directories(smoke_fast_rng PRIVATE src)
  target_include_directories(test_fast_rng_vectors PRIVATE src)
endif()

if(APPLE AND NOT ANDROID)
  enable_language(OBJCXX)
  add_executable(macos_bookmark_probe probes/macos/bookmark_probe.mm)
  target_compile_options(macos_bookmark_probe PRIVATE -fobjc-arc)
  target_compile_definitions(
    macos_bookmark_probe PRIVATE
      SIMPLICITY_ENGINE_SOURCE_DIR="${CMAKE_SOURCE_DIR}")
  target_link_libraries(macos_bookmark_probe PRIVATE "-framework AppKit" "-framework Foundation")
endif()

if(NOT ANDROID)
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
  add_test(NAME test_fast_rng_vectors COMMAND test_fast_rng_vectors)
  set_tests_properties(test_fast_rng_vectors PROPERTIES LABELS "rng;full")
endif()
