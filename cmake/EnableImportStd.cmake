# Enable CMake's experimental `import std;` support.
# Include this file BEFORE the first project() call.
#
# The UUID is a CMake compatibility gate: it changes when the experimental
# behavior changes. Values below cover CMake 3.30 through 4.4.

if(CMAKE_VERSION VERSION_LESS "3.30")
  message(FATAL_ERROR "import std requires CMake 3.30 or newer (this is ${CMAKE_VERSION})")
endif()

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

set(CMAKE_CXX_MODULE_STD ON)

# Freeze the dialect before project(). CMake 4.2 (and some 4.3 import-std
# paths) create the synthetic `std` target during compiler detection and
# lock its flags then. The default is gnu++NN. Our TUs use -std=c++NN.
# Clang refuses that BMI: "GNU extensions was enabled in precompiled file
# ... but is currently disabled". GCC accepts the mismatch. Setting both
# here makes every CMake emit one dialect for std and for our TUs.
if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 26)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF CACHE BOOL
  "ISO C++ (-std=c++NN), not GNU extensions (-std=gnu++NN). Mixed dialects break Clang import std."
  FORCE)

# TARGET_STDLIB=default | libstdc++ | libc++. Clang -stdlib= flags, the
# reserved-module-identifier warning, and the matching modules.json.
# gcc-libstdcxx / clang-libstdcxx / clang-libcxx presets include this path.
include("${CMAKE_CURRENT_LIST_DIR}/StdlibLane.cmake")
