# -stdlib= is a Clang driver flag. GCC rejects it:
#   g++: error: unrecognized command-line option '-stdlib=libc++'
# Apply it only for Clang, and only the value that matches the lane:
#   TARGET_STDLIB=libstdc++  →  -stdlib=libstdc++
#   TARGET_STDLIB=libc++     →  -stdlib=libc++
# A leftover -DCMAKE_CXX_FLAGS="-stdlib=…" must not leak into a GCC configure.
# Include before project(). Also included from StdlibLane.cmake.

# Not include_guard(GLOBAL): that command keys off the current list file.
# When this body is inlined into CMakeLists.txt (Compiler Explorer), a
# second guard would skip project() and CMake would report an empty Ninja
# version. A named flag is safe in both include() and inlined form.
if(NOT TALLY_APPLY_STDLIB_FLAGS_INCLUDED)
set(TALLY_APPLY_STDLIB_FLAGS_INCLUDED TRUE)

set(TARGET_STDLIB "default" CACHE STRING "default | libc++ | libstdc++")
set_property(CACHE TARGET_STDLIB PROPERTY STRINGS default libc++ libstdc++)

set(_tally_cxx "${CMAKE_CXX_COMPILER}")
if(_tally_cxx STREQUAL "" AND DEFINED ENV{CXX})
  set(_tally_cxx "$ENV{CXX}")
endif()

set(_TALLY_CLANG FALSE)
if(_tally_cxx MATCHES "[cC]lang")
  set(_TALLY_CLANG TRUE)
elseif(NOT _tally_cxx STREQUAL "")
  if(NOT IS_ABSOLUTE "${_tally_cxx}")
    find_program(_tally_cxx_abs NAMES "${_tally_cxx}")
    if(_tally_cxx_abs)
      set(_tally_cxx "${_tally_cxx_abs}")
    endif()
    unset(_tally_cxx_abs)
  endif()
  execute_process(
    COMMAND "${_tally_cxx}" --version
    OUTPUT_VARIABLE _tally_ver
    ERROR_VARIABLE _tally_ver_err
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
  if(_tally_ver MATCHES "[cC]lang" OR _tally_ver_err MATCHES "[cC]lang")
    set(_TALLY_CLANG TRUE)
  endif()
  unset(_tally_ver)
  unset(_tally_ver_err)
endif()

set(_TALLY_WANT_LIBCXX FALSE)
if(TARGET_STDLIB STREQUAL "libc++")
  set(_TALLY_WANT_LIBCXX TRUE)
elseif(TARGET_STDLIB STREQUAL "default"
    AND (_TALLY_CLANG)
    AND (CMAKE_CXX_FLAGS MATCHES "-stdlib=libc\\+\\+"
      OR CMAKE_CXX_FLAGS_INIT MATCHES "-stdlib=libc\\+\\+"))
  set(_TALLY_WANT_LIBCXX TRUE)
endif()

macro(_tally_remove_stdlib _var)
  if(DEFINED ${_var})
    string(REGEX REPLACE "(^| )-stdlib=(libc\\+\\+|libstdc\\+\\+)" "" ${_var} "${${_var}}")
    string(REGEX REPLACE "  +" " " ${_var} "${${_var}}")
    string(STRIP "${${_var}}" ${_var})
  endif()
endmacro()

set(_tally_had_stdlib FALSE)
foreach(_tally_v
    CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_INIT
    CMAKE_EXE_LINKER_FLAGS CMAKE_EXE_LINKER_FLAGS_INIT
    CMAKE_SHARED_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS_INIT
    CMAKE_MODULE_LINKER_FLAGS CMAKE_MODULE_LINKER_FLAGS_INIT)
  if(DEFINED ${_tally_v} AND "${${_tally_v}}" MATCHES "-stdlib=")
    set(_tally_had_stdlib TRUE)
  endif()
  _tally_remove_stdlib(${_tally_v})
endforeach()

if(NOT _TALLY_CLANG)
  if(TARGET_STDLIB STREQUAL "libc++")
    message(FATAL_ERROR
      "TARGET_STDLIB=libc++ requires Clang. "
      "Pass -DCMAKE_CXX_COMPILER=clang++ or use cmake/clang-libcxx.cmake.")
  endif()
  if(_tally_had_stdlib)
    message(STATUS
      "Dropped -stdlib=* from flags (GCC does not accept it; Clang-only)")
  endif()
else()
  if(_TALLY_WANT_LIBCXX)
    set(_tally_stdlib "libc++")
  elseif(TARGET_STDLIB STREQUAL "libstdc++")
    set(_tally_stdlib "libstdc++")
  else()
    set(_tally_stdlib "")
  endif()
  if(NOT _tally_stdlib STREQUAL "")
    string(APPEND CMAKE_CXX_FLAGS " -stdlib=${_tally_stdlib}")
    string(APPEND CMAKE_CXX_FLAGS_INIT " -stdlib=${_tally_stdlib}")
    string(APPEND CMAKE_EXE_LINKER_FLAGS " -stdlib=${_tally_stdlib}")
    string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT " -stdlib=${_tally_stdlib}")
    string(APPEND CMAKE_SHARED_LINKER_FLAGS " -stdlib=${_tally_stdlib}")
    string(APPEND CMAKE_SHARED_LINKER_FLAGS_INIT " -stdlib=${_tally_stdlib}")
    string(APPEND CMAKE_MODULE_LINKER_FLAGS " -stdlib=${_tally_stdlib}")
    string(APPEND CMAKE_MODULE_LINKER_FLAGS_INIT " -stdlib=${_tally_stdlib}")
  endif()
  unset(_tally_stdlib)

  # bits/std.cc and libc++ std.cppm contain `export module std;`.
  # Clang warns that `std` is a reserved module name; silence it globally so
  # CMake's synthetic import-std target is covered.
  string(FIND "${CMAKE_CXX_FLAGS}" "-Wno-reserved-module-identifier" _tally_warn)
  if(_tally_warn EQUAL -1)
    string(APPEND CMAKE_CXX_FLAGS " -Wno-reserved-module-identifier")
  endif()
  unset(_tally_warn)
endif()

# -DCMAKE_CXX_FLAGS=… is a cache entry. FORCE so a leftover -stdlib=libc++
# cannot come back during project() / a later GCC configure of this tree.
foreach(_tally_v CMAKE_CXX_FLAGS CMAKE_EXE_LINKER_FLAGS
    CMAKE_SHARED_LINKER_FLAGS CMAKE_MODULE_LINKER_FLAGS)
  if(DEFINED CACHE{${_tally_v}})
    set(${_tally_v} "${${_tally_v}}" CACHE STRING
      "Flags used by the CXX ${_tally_v}" FORCE)
  endif()
endforeach()

unset(_tally_cxx)
unset(_tally_had_stdlib)
unset(_tally_v)

endif() # TALLY_APPLY_STDLIB_FLAGS_INCLUDED
