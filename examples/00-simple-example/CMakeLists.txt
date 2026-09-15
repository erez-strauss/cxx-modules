cmake_minimum_required(VERSION 4.0)

# Must be set before project() so CMake wires `import std;`.
# UUID is CMake-version specific; copy EnableImportStd.cmake if you lift this demo.
if(NOT CMAKE_EXPERIMENTAL_CXX_IMPORT_STD)
  if(CMAKE_VERSION VERSION_GREATER_EQUAL "4.4")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "f35a9ac6-8463-4d38-8eec-5d6008153e7d")
  elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.3")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "451f2fe2-a8a2-47c3-bc32-94786d8fc91b")
  elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.0.3")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
  elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "a9e1cf81-9932-4810-974b-6eccaf14e457")
  elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "3.31.8")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
  else()
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "0e5b6991-d74f-4b3d-a41c-cf096e0b2508")
  endif()
endif()

# -stdlib= is Clang-only (GCC errors on it). ApplyStdlibFlags adds
# -stdlib=libstdc++ / -stdlib=libc++ only for Clang, and strips a leftover
# -DCMAKE_CXX_FLAGS="-stdlib=…" so a later GCC configure of this tree works.
include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/ApplyStdlibFlags.cmake")

# Ubuntu's libc++.modules.json often resolves std.cppm to a missing
# /lib/share/libc++/v1/std.cppm. Fix the path before project() probes import std.
if(TARGET_STDLIB STREQUAL "libc++" OR _TALLY_WANT_LIBCXX)
  include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/libcxx-modules-json.cmake")
  simple_example_use_libcxx_modules_json()
else()
  include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/LibstdcxxModulesJson.cmake")
endif()

# Dialect must be frozen before project() as well as the UUID.
# CMake 4.2 (and some 4.3 import-std paths) compile the synthetic std
# target during detection with the default gnu++. Our TUs use -std=c++26.
# Clang: "GNU extensions was enabled in precompiled file ... but is
# currently disabled". GCC accepts the mismatch. One dialect for both.
set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF CACHE BOOL
  "ISO C++ (-std=c++NN), not GNU extensions (-std=gnu++NN). Mixed dialects break Clang import std."
  FORCE)
set(CMAKE_CXX_MODULE_STD ON)

project(simple_example LANGUAGES CXX)

if(NOT "${CMAKE_CXX_STANDARD}" IN_LIST CMAKE_CXX_COMPILER_IMPORT_STD)
  message(FATAL_ERROR
    "import std is not available for C++${CMAKE_CXX_STANDARD}. "
    "CMAKE_CXX_COMPILER_IMPORT_STD=${CMAKE_CXX_COMPILER_IMPORT_STD}")
endif()
message(STATUS "C++${CMAKE_CXX_STANDARD}; import std: ${CMAKE_CXX_COMPILER_IMPORT_STD}")

add_executable(myu1 myu1.cpp)
target_sources(myu1 PRIVATE FILE_SET CXX_MODULES FILES mym1.cppm)
target_compile_options(myu1 PRIVATE
  $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic>
)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/AddDepGraph.cmake")
tally_add_dep_graph()
