# Clang + libstdc++ `import std`: CMake asks
#   clang++ -print-file-name=libstdc++.modules.json
# If Clang was not built against this GCC (system clang++ + /opt/g++-16, …)
# it echoes the bare filename and configure dies:
#   Failed to load C++ standard library modules metadata from
#   "libstdc++.modules.json": File not found
# Point CMake at GCC's JSON before project(). Include this from
# StdlibLane.cmake (via EnableImportStd.cmake) when the lane is not libc++.
# Override: -DCMAKE_CXX_STDLIB_MODULES_JSON=/abs/path
#
# No-op when the compiler is GCC, or when Clang already prints a real path.
# Do not use file-scope return(): Compiler Explorer inlines this into
# CMakeLists.txt, and return() would skip project().

if(NOT TALLY_LIBSTDCXX_MODULES_JSON_INCLUDED)
set(TALLY_LIBSTDCXX_MODULES_JSON_INCLUDED TRUE)

if(NOT CMAKE_CXX_STDLIB_MODULES_JSON OR NOT EXISTS "${CMAKE_CXX_STDLIB_MODULES_JSON}")
  set(_tally_cxx "${CMAKE_CXX_COMPILER}")
  if(_tally_cxx STREQUAL "" AND DEFINED ENV{CXX})
    set(_tally_cxx "$ENV{CXX}")
  endif()
  if(_tally_cxx MATCHES "[cC]lang")
    if(NOT IS_ABSOLUTE "${_tally_cxx}")
      find_program(_tally_cxx_abs NAMES "${_tally_cxx}" clang++ clang++-22 clang++-21 clang++-20)
      if(_tally_cxx_abs)
        set(_tally_cxx "${_tally_cxx_abs}")
      endif()
      unset(_tally_cxx_abs)
    endif()

    execute_process(
      COMMAND "${_tally_cxx}" -print-file-name=libstdc++.modules.json
      OUTPUT_VARIABLE _tally_printed
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_QUIET
    )
    if(NOT _tally_printed
        OR _tally_printed STREQUAL "libstdc++.modules.json"
        OR NOT EXISTS "${_tally_printed}")
      set(_tally_json "")
      foreach(_gxx IN ITEMS g++ g++-16 g++-15 g++-14)
        find_program(_tally_gxx_bin NAMES "${_gxx}")
        if(_tally_gxx_bin)
          execute_process(
            COMMAND "${_tally_gxx_bin}" -print-file-name=libstdc++.modules.json
            OUTPUT_VARIABLE _tally_gjson
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
          )
          if(_tally_gjson
              AND NOT _tally_gjson STREQUAL "libstdc++.modules.json"
              AND EXISTS "${_tally_gjson}")
            get_filename_component(_tally_json "${_tally_gjson}" ABSOLUTE)
            break()
          endif()
        endif()
      endforeach()
      unset(_tally_gxx_bin)
      unset(_tally_gjson)

      if(_tally_json STREQUAL "")
        file(GLOB _tally_globs
          "/usr/lib/gcc/*/*/libstdc++.modules.json"
          "/usr/lib64/gcc/*/*/libstdc++.modules.json"
          "/opt/g++*/lib/gcc/*/*/libstdc++.modules.json"
          "/opt/g++*/include/c++/*/libstdc++.modules.json"
          "/usr/include/c++/*/libstdc++.modules.json"
        )
        foreach(_f IN LISTS _tally_globs)
          if(EXISTS "${_f}")
            get_filename_component(_tally_json "${_f}" ABSOLUTE)
            break()
          endif()
        endforeach()
        unset(_tally_globs)
      endif()

      if(NOT _tally_json STREQUAL "")
        set(CMAKE_CXX_STDLIB_MODULES_JSON "${_tally_json}" CACHE FILEPATH
          "libstdc++ modules metadata (Clang could not print the path)" FORCE)
        message(STATUS "libstdc++ modules JSON (for Clang): ${CMAKE_CXX_STDLIB_MODULES_JSON}")
      else()
        message(STATUS
          "Clang did not print libstdc++.modules.json. If configure fails, pass "
          "-DCMAKE_CXX_STDLIB_MODULES_JSON=\$(g++ -print-file-name=libstdc++.modules.json) "
          "using the GCC that provides your libstdc++.")
      endif()
      unset(_tally_json)
    endif()
    unset(_tally_printed)
  endif()
  unset(_tally_cxx)
endif()

endif() # TALLY_LIBSTDCXX_MODULES_JSON_INCLUDED
