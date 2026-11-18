cmake_minimum_required(VERSION 3.21)

if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

project(simplicity_engine LANGUAGES C CXX)
if(NOT APPLE)
  message(FATAL_ERROR "Native builds support Apple platforms only. Use the Rust/Wasm/Tauri build for the new application direction; see README.md.")
endif()

find_program(CARGO_EXECUTABLE cargo REQUIRED)
find_program(RUSTC_EXECUTABLE rustc REQUIRED)
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  if(CMAKE_OSX_SYSROOT MATCHES "iphonesimulator")
    if(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
      set(SIMPLICITY_RUST_TARGET aarch64-apple-ios-sim)
    elseif(CMAKE_OSX_ARCHITECTURES STREQUAL "x86_64")
      set(SIMPLICITY_RUST_TARGET x86_64-apple-ios)
    else()
      message(FATAL_ERROR "Unsupported iOS Simulator architecture for the Rust core: ${CMAKE_OSX_ARCHITECTURES}")
    endif()
  elseif(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    set(SIMPLICITY_RUST_TARGET aarch64-apple-ios)
  else()
    message(FATAL_ERROR "Unsupported iOS device architecture for the Rust core: ${CMAKE_OSX_ARCHITECTURES}")
  endif()
else()
  execute_process(
    COMMAND "${RUSTC_EXECUTABLE}" -vV
    OUTPUT_VARIABLE RUSTC_VERSION_INFO
    RESULT_VARIABLE RUSTC_VERSION_RESULT
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT RUSTC_VERSION_RESULT EQUAL 0)
    message(FATAL_ERROR "Unable to determine the Rust host target using rustc -vV")
  endif()
  string(REGEX MATCH "host: ([^\r\n]+)" RUSTC_HOST_MATCH "${RUSTC_VERSION_INFO}")
  if(NOT RUSTC_HOST_MATCH)
    message(FATAL_ERROR "Unable to parse the Rust host target from rustc -vV")
  endif()
  set(SIMPLICITY_RUST_TARGET "${CMAKE_MATCH_1}")
endif()

if(DEFINED ENV{CARGO_TARGET_DIR} AND NOT "$ENV{CARGO_TARGET_DIR}" STREQUAL "")
  get_filename_component(SIMPLICITY_CARGO_TARGET_DIR "$ENV{CARGO_TARGET_DIR}" ABSOLUTE BASE_DIR "${CMAKE_SOURCE_DIR}")
else()
  set(SIMPLICITY_CARGO_TARGET_DIR "${CMAKE_SOURCE_DIR}/target")
endif()
set(SIMPLICITY_RUST_ARCHIVE_DIR "${SIMPLICITY_CARGO_TARGET_DIR}/${SIMPLICITY_RUST_TARGET}")
set(SIMPLICITY_RUST_DEBUG_ARCHIVE "${SIMPLICITY_RUST_ARCHIVE_DIR}/debug/libsimplicity_core.a")
set(SIMPLICITY_RUST_RELEASE_ARCHIVE "${SIMPLICITY_RUST_ARCHIVE_DIR}/release/libsimplicity_core.a")
add_custom_target(simplicity_core_rust_build
  COMMAND "${CARGO_EXECUTABLE}" build --locked --package simplicity-core
          --target "${SIMPLICITY_RUST_TARGET}"
          --profile "$<IF:$<CONFIG:Release>,release,dev>"
  BYPRODUCTS "${SIMPLICITY_RUST_DEBUG_ARCHIVE}" "${SIMPLICITY_RUST_RELEASE_ARCHIVE}"
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  COMMENT "Building the shared Rust core for ${SIMPLICITY_RUST_TARGET}"
  VERBATIM)
add_library(simplicity_core_rust STATIC IMPORTED GLOBAL)
set_target_properties(simplicity_core_rust PROPERTIES
  IMPORTED_CONFIGURATIONS "DEBUG;RELEASE;RELWITHDEBINFO;MINSIZEREL"
  IMPORTED_LOCATION_DEBUG "${SIMPLICITY_RUST_DEBUG_ARCHIVE}"
  IMPORTED_LOCATION_RELEASE "${SIMPLICITY_RUST_RELEASE_ARCHIVE}"
  IMPORTED_LOCATION_RELWITHDEBINFO "${SIMPLICITY_RUST_RELEASE_ARCHIVE}"
  IMPORTED_LOCATION_MINSIZEREL "${SIMPLICITY_RUST_RELEASE_ARCHIVE}")
add_dependencies(simplicity_core_rust simplicity_core_rust_build)

# Resolve the target toolchain before deciding which OS languages to enable.
if(APPLE)
  enable_language(OBJCXX)
  set(CMAKE_OBJCXX_STANDARD 17)
  set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(SIMPLICITY_ENGINE_APP_TARGET hello_pixel)

set(
  SIMPLICITY_ENGINE_IOS_BUNDLE_IDENTIFIER
  "dev.simplicityengine.hello-pixel"
  CACHE STRING
  "Bundle identifier used for iOS simulator/device app builds")

include(FetchContent)

set(SDL_TEST OFF CACHE BOOL "Disable SDL tests" FORCE)
set(SDL_SHARED OFF CACHE BOOL "Disable SDL shared library" FORCE)
set(SDL_STATIC ON CACHE BOOL "Build SDL static library" FORCE)

FetchContent_Declare(
  SDL3
  URL https://github.com/libsdl-org/SDL/releases/download/release-3.2.8/SDL3-3.2.8.tar.gz
  URL_HASH SHA256=13388fabb361de768ecdf2b65e52bb27d1054cae6ccb6942ba926e378e00db03
)
FetchContent_MakeAvailable(SDL3)

option(SIMPLICITY_MENU_DEMO "Use Menu Studio as the platform app" OFF)
set(SIMPLICITY_APP_SOURCE src/main.cpp)
if(SIMPLICITY_MENU_DEMO)
  set(SIMPLICITY_APP_SOURCE demos/menu_demo.cpp)
endif()

add_library(simplicity_menu_model src/menu/menu.cpp)
target_include_directories(simplicity_menu_model PUBLIC include)
target_link_libraries(simplicity_menu_model PUBLIC simplicity_core_rust)
set_target_properties(simplicity_menu_model PROPERTIES POSITION_INDEPENDENT_CODE ON)
add_library(simplicity_menu src/menu/menu_touch.cpp)
target_link_libraries(simplicity_menu PUBLIC simplicity_menu_model SDL3::SDL3)
set_target_properties(simplicity_menu PROPERTIES POSITION_INDEPENDENT_CODE ON)
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  target_sources(simplicity_menu PRIVATE src/menu/menu_mobile.cpp)
elseif(APPLE)
  target_sources(simplicity_menu PRIVATE src/menu/menu_macos.mm)
  target_compile_options(simplicity_menu PRIVATE "$<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>")
  target_link_libraries(simplicity_menu PRIVATE "-framework AppKit")
endif()

add_executable(${SIMPLICITY_ENGINE_APP_TARGET} ${SIMPLICITY_APP_SOURCE})

target_link_libraries(${SIMPLICITY_ENGINE_APP_TARGET} PRIVATE SDL3::SDL3)
if(SIMPLICITY_MENU_DEMO)
  target_link_libraries(${SIMPLICITY_ENGINE_APP_TARGET} PRIVATE simplicity_menu)
endif()
if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  add_executable(menu_demo demos/menu_demo.cpp)
  target_link_libraries(menu_demo PRIVATE simplicity_menu)
  if(APPLE)
    set_target_properties(menu_demo PROPERTIES MACOSX_BUNDLE TRUE
      MACOSX_BUNDLE_GUI_IDENTIFIER "dev.simplicityengine.menu-demo"
      MACOSX_BUNDLE_BUNDLE_NAME "Menu Studio")
  endif()
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  set_target_properties(
    ${SIMPLICITY_ENGINE_APP_TARGET} PROPERTIES
      MACOSX_BUNDLE TRUE
      XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE "YES"
      XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${SIMPLICITY_ENGINE_IOS_BUNDLE_IDENTIFIER}"
      XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1"
      XCODE_ATTRIBUTE_INFOPLIST_KEY_CFBundleDisplayName "Hello Pixel"
      XCODE_ATTRIBUTE_INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents "YES"
      XCODE_ATTRIBUTE_INFOPLIST_KEY_UISupportedInterfaceOrientations "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight")
endif()

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  add_executable(smoke_sdl_init tests/smoke_sdl_init.cpp)

  target_link_libraries(smoke_sdl_init PRIVATE SDL3::SDL3)
endif()

if(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  enable_language(OBJCXX)
  add_executable(macos_bookmark_probe probes/macos/bookmark_probe.mm)
  target_compile_options(macos_bookmark_probe PRIVATE -fobjc-arc)
  target_compile_definitions(
    macos_bookmark_probe PRIVATE
      SIMPLICITY_ENGINE_SOURCE_DIR="${CMAKE_SOURCE_DIR}")
  target_link_libraries(macos_bookmark_probe PRIVATE "-framework AppKit" "-framework Foundation")
endif()

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  enable_testing()
  add_executable(test_menu tests/test_menu.cpp)
  target_link_libraries(test_menu PRIVATE simplicity_menu)
  add_test(NAME test_menu COMMAND test_menu)
  set_tests_properties(test_menu PROPERTIES LABELS "menu;smoke")
  if(TARGET menu_demo)
    add_test(NAME menu_demo_smoke COMMAND menu_demo --self-test)
    set_tests_properties(menu_demo_smoke PROPERTIES ENVIRONMENT "SDL_VIDEODRIVER=dummy;SDL_RENDER_DRIVER=software" LABELS "menu;smoke")
  endif()
  add_test(NAME smoke_sdl_init COMMAND smoke_sdl_init)
  set_tests_properties(smoke_sdl_init PROPERTIES LABELS smoke)
endif()
