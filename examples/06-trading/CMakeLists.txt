cmake_minimum_required(VERSION 4.0)

if(NOT CMAKE_EXPERIMENTAL_CXX_IMPORT_STD)
  if(CMAKE_VERSION VERSION_GREATER_EQUAL "4.4")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "f35a9ac6-8463-4d38-8eec-5d6008153e7d")
  elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.3")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "451f2fe2-a8a2-47c3-bc32-94786d8fc91b")
  elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.0.3")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
  elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "a9e1cf81-9932-4810-974b-6eccaf14e457")
  else()
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
  endif()
endif()

# -stdlib= is Clang-only (GCC errors on it). ApplyStdlibFlags adds
# -stdlib=libstdc++ / -stdlib=libc++ only for Clang, and strips a leftover
# -DCMAKE_CXX_FLAGS="-stdlib=…" so a later GCC configure of this tree works.
include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/ApplyStdlibFlags.cmake")

if(TARGET_STDLIB STREQUAL "libc++" OR _TALLY_WANT_LIBCXX)
  include("${CMAKE_CURRENT_SOURCE_DIR}/../00-simple-example/cmake/libcxx-modules-json.cmake")
  simple_example_use_libcxx_modules_json()
else()
  include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/LibstdcxxModulesJson.cmake")
endif()

# Same freeze as EnableImportStd / 00-simple-example: dialect before
# project() so the import-std BMI is -std=c++26, not gnu++26.
set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF CACHE BOOL
  "ISO C++ (-std=c++NN), not GNU extensions (-std=gnu++NN). Mixed dialects break Clang import std."
  FORCE)
set(CMAKE_CXX_MODULE_STD ON)

project(trading VERSION 1.0.0 LANGUAGES CXX)

set(TRADING_STD ${CMAKE_CXX_STANDARD})

option(TRADING_SHARED "Build libtrading as a shared library (.so)" OFF)
option(TRADING_PIC "Compile library .cpp with -fPIC (on automatically if SHARED)" OFF)

if(TRADING_SHARED)
  add_library(trading SHARED)
else()
  add_library(trading STATIC)
endif()

set(_pic OFF)
if(TRADING_SHARED OR TRADING_PIC)
  set(_pic ON)
endif()
set_target_properties(trading PROPERTIES POSITION_INDEPENDENT_CODE ${_pic})

# CMAKE_CXX_STANDARD is not enough for a target whose modules are exported.
# Without an explicit compile feature the *consumer* fails at generate time
# on a synthesized target it never wrote:
#   trading__trading@synth_… does not include "cxx_std_20" (or newer)
#   among its target_compile_features
target_compile_features(trading PUBLIC cxx_std_${TRADING_STD})

target_sources(trading
  PRIVATE
    src/order.cpp
    src/book.cpp
    src/blotter.cpp
  PUBLIC
    FILE_SET HEADERS
      BASE_DIRS include
      FILES
        include/trading/ticks.hpp
        include/trading/order.hpp
        include/trading/book.hpp
        include/trading/blotter.hpp
        include/trading/trading.hpp
    FILE_SET CXX_MODULES
      FILES
        modules/trading.cppm
)
set_source_files_properties(
  src/order.cpp src/book.cpp src/blotter.cpp
  PROPERTIES CXX_SCAN_FOR_MODULES OFF
)
target_compile_options(trading PRIVATE
  $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic>
)

if(TRADING_SHARED)
  message(STATUS "libtrading: SHARED .so PIC=${_pic} C++${CMAKE_CXX_STANDARD}")
else()
  message(STATUS "libtrading: STATIC .a PIC=${_pic} C++${CMAKE_CXX_STANDARD}")
endif()

add_executable(oms_legacy apps/oms-legacy.cpp)
target_link_libraries(oms_legacy PRIVATE trading)
set_target_properties(oms_legacy PROPERTIES CXX_SCAN_FOR_MODULES OFF)
target_compile_options(oms_legacy PRIVATE
  $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic>
)

add_executable(oms_modules apps/oms-modules.cpp)
target_link_libraries(oms_modules PRIVATE trading)
target_compile_options(oms_modules PRIVATE
  $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic>
)

add_executable(post_trade apps/post-trade.cpp)
target_link_libraries(post_trade PRIVATE trading)
target_compile_options(post_trade PRIVATE
  $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic>
)

set_target_properties(trading PROPERTIES
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR}
)

include(GNUInstallDirs)

if(TRADING_SHARED)
  set(_install_rpath "\$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
  set_target_properties(oms_legacy oms_modules post_trade PROPERTIES
    INSTALL_RPATH "${_install_rpath}"
  )
endif()

# Ship headers + module interface sources + the .a/.so. Consumers rebuild
# the BMI; do not install .pcm / .gcm.
install(TARGETS trading
  EXPORT tradingTargets
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  FILE_SET CXX_MODULES DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/trading/src
)
install(TARGETS oms_legacy oms_modules post_trade
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

set(_cmake_pkg ${CMAKE_INSTALL_LIBDIR}/cmake/trading)
install(EXPORT tradingTargets
  FILE tradingTargets.cmake
  NAMESPACE trading::
  DESTINATION ${_cmake_pkg}
  CXX_MODULES_DIRECTORY cxx-modules
)

include(CMakePackageConfigHelpers)
configure_package_config_file(
  cmake/tradingConfig.cmake.in
  "${CMAKE_CURRENT_BINARY_DIR}/tradingConfig.cmake"
  INSTALL_DESTINATION ${_cmake_pkg}
)
write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/tradingConfigVersion.cmake"
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion
)
install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/tradingConfig.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/tradingConfigVersion.cmake"
  DESTINATION ${_cmake_pkg}
)

if(TRADING_SHARED)
  set(_pkg_kind shared)
else()
  set(_pkg_kind static)
endif()
set(CPACK_GENERATOR "TGZ")
set(CPACK_PACKAGE_NAME "trading")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_VENDOR "CppCon 2026")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY
  "OMS + post-trade library: headers, module interface, ${_pkg_kind} lib, three apps")
set(CPACK_PACKAGE_FILE_NAME "trading-${PROJECT_VERSION}-${_pkg_kind}")
set(CPACK_VERBATIM_VARIABLES ON)
include(CPack)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/AddDepGraph.cmake")
tally_add_dep_graph()
