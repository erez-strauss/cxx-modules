# Locate libc++'s modules.json for *this* Clang, before project() probes
# `import std;`. Ubuntu often ships a JSON whose relative source-path
# becomes the missing /lib/share/libc++/v1/std.cppm. We:
#   1. ask the selected clang++ for its version and resource-dir
#   2. prefer paths for that LLVM (llvm-<major>, prefix/share/libc++)
#   3. accept a JSON only if every source-path exists
#   4. otherwise write ${CMAKE_BINARY_DIR}/.generated-libcxx.modules.json
#      with absolute paths to that Clang's std.cppm
#
# Override: -DCMAKE_CXX_STDLIB_MODULES_JSON=... or -DLIBCXX_STD_CPPM=...
# Include from StdlibLane.cmake when TARGET_STDLIB is libc++.

if(NOT TALLY_LIBCXX_MODULES_JSON_INCLUDED)
set(TALLY_LIBCXX_MODULES_JSON_INCLUDED TRUE)

function(_tally_realpath in_path out_var)
  if(EXISTS "${in_path}")
    get_filename_component(_rp "${in_path}" REALPATH)
    set(${out_var} "${_rp}" PARENT_SCOPE)
  else()
    set(${out_var} "${in_path}" PARENT_SCOPE)
  endif()
endfunction()

function(_tally_json_sources_exist json_file)
  set(_ok TRUE)
  if(NOT EXISTS "${json_file}")
    set(_ok FALSE)
  else()
    file(READ "${json_file}" _contents)
    string(JSON _n ERROR_VARIABLE _err LENGTH "${_contents}" modules)
    if(_err OR _n STREQUAL "" OR _n EQUAL 0)
      set(_ok FALSE)
    else()
      math(EXPR _last "${_n} - 1")
      _tally_realpath("${json_file}" _json_real)
      get_filename_component(_json_dir "${_json_real}" DIRECTORY)
      foreach(_i RANGE 0 ${_last})
        string(JSON _rel GET "${_contents}" modules ${_i} source-path)
        if(IS_ABSOLUTE "${_rel}")
          set(_abs "${_rel}")
        else()
          get_filename_component(_abs "${_json_dir}/${_rel}" ABSOLUTE)
        endif()
        _tally_realpath("${_abs}" _abs)
        if(NOT EXISTS "${_abs}")
          set(_ok FALSE)
        endif()
      endforeach()
    endif()
  endif()
  set(_TALLY_JSON_OK "${_ok}" PARENT_SCOPE)
endfunction()

function(_tally_write_libcxx_modules_json std_cppm)
  get_filename_component(_v1 "${std_cppm}" DIRECTORY)
  set(_compat "${_v1}/std.compat.cppm")
  if(CMAKE_BINARY_DIR)
    set(_out "${CMAKE_BINARY_DIR}/.generated-libcxx.modules.json")
  else()
    set(_out "${CMAKE_CURRENT_SOURCE_DIR}/.generated-libcxx.modules.json")
  endif()
  file(WRITE "${_out}"
"{
  \"version\": 1,
  \"revision\": 1,
  \"modules\": [
    {
      \"logical-name\": \"std\",
      \"source-path\": \"${std_cppm}\",
      \"is-std-library\": true,
      \"local-arguments\": {
        \"system-include-directories\": [\"${_v1}\"]
      }
    },
    {
      \"logical-name\": \"std.compat\",
      \"source-path\": \"${_compat}\",
      \"is-std-library\": true,
      \"local-arguments\": {
        \"system-include-directories\": [\"${_v1}\"]
      }
    }
  ]
}
")
  set(CMAKE_CXX_STDLIB_MODULES_JSON "${_out}" CACHE FILEPATH
    "libc++ modules metadata" FORCE)
  message(STATUS "libc++ modules JSON (generated for this Clang): ${_out}")
  message(STATUS "  std.cppm: ${std_cppm}")
endfunction()

function(_tally_clang_layout compiler)
  set(_compiler "${compiler}")
  if(_compiler STREQUAL "")
    set(_compiler "clang++")
  endif()
  if(NOT IS_ABSOLUTE "${_compiler}")
    find_program(_compiler_abs NAMES "${_compiler}" clang++ clang++-22 clang++-21 clang++-20 clang++-19 clang++-18)
    if(_compiler_abs)
      set(_compiler "${_compiler_abs}")
    endif()
  endif()

  set(_major "")
  set(_prefix "")
  execute_process(
    COMMAND "${_compiler}" -dumpversion
    OUTPUT_VARIABLE _ver
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
  if(_ver MATCHES "^([0-9]+)")
    set(_major "${CMAKE_MATCH_1}")
  endif()

  execute_process(
    COMMAND "${_compiler}" -print-resource-dir
    OUTPUT_VARIABLE _resdir
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
  # resource-dir: <prefix>/lib/clang/<ver> or <prefix>/lib64/clang/<ver>
  if(_resdir)
    get_filename_component(_resdir "${_resdir}" ABSOLUTE)
    get_filename_component(_clang_dir "${_resdir}" DIRECTORY)
    get_filename_component(_lib_dir "${_clang_dir}" DIRECTORY)
    get_filename_component(_prefix "${_lib_dir}" DIRECTORY)
  endif()

  execute_process(
    COMMAND "${_compiler}" -stdlib=libc++ -print-file-name=libc++.modules.json
    OUTPUT_VARIABLE _printed
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
  if(_printed STREQUAL "libc++.modules.json" OR NOT EXISTS "${_printed}")
    set(_printed "")
  else()
    get_filename_component(_printed "${_printed}" REALPATH)
  endif()

  set(_TALLY_CLANG "${_compiler}" PARENT_SCOPE)
  set(_TALLY_CLANG_MAJOR "${_major}" PARENT_SCOPE)
  set(_TALLY_CLANG_PREFIX "${_prefix}" PARENT_SCOPE)
  set(_TALLY_PRINTED_JSON "${_printed}" PARENT_SCOPE)
endfunction()

function(tally_use_libcxx_modules_json)
  if(LIBCXX_STD_CPPM AND EXISTS "${LIBCXX_STD_CPPM}")
    _tally_write_libcxx_modules_json("${LIBCXX_STD_CPPM}")
    return()
  endif()

  if(CMAKE_CXX_STDLIB_MODULES_JSON)
    _tally_json_sources_exist("${CMAKE_CXX_STDLIB_MODULES_JSON}")
    if(_TALLY_JSON_OK)
      message(STATUS "libc++ modules JSON: ${CMAKE_CXX_STDLIB_MODULES_JSON}")
      return()
    endif()
    message(STATUS
      "Ignoring CMAKE_CXX_STDLIB_MODULES_JSON=${CMAKE_CXX_STDLIB_MODULES_JSON} "
      "(module sources missing)")
    unset(CMAKE_CXX_STDLIB_MODULES_JSON CACHE)
    unset(CMAKE_CXX_STDLIB_MODULES_JSON)
  endif()

  _tally_clang_layout("${CMAKE_CXX_COMPILER}")
  set(_major "${_TALLY_CLANG_MAJOR}")
  set(_prefix "${_TALLY_CLANG_PREFIX}")
  message(STATUS
    "libc++ import std: clang=${_TALLY_CLANG} "
    "version=${_major} prefix=${_prefix}")

  set(_json_candidates "")
  if(_TALLY_PRINTED_JSON)
    list(APPEND _json_candidates "${_TALLY_PRINTED_JSON}")
  endif()
  if(_prefix)
    list(APPEND _json_candidates
      "${_prefix}/lib/libc++.modules.json"
      "${_prefix}/lib64/libc++.modules.json"
    )
  endif()
  if(_major)
    list(APPEND _json_candidates
      "/usr/lib/llvm-${_major}/lib/libc++.modules.json"
      "/usr/lib/llvm-${_major}/lib64/libc++.modules.json"
    )
  endif()
  list(APPEND _json_candidates
    "/usr/lib64/libc++.modules.json"
    "/usr/lib/libc++.modules.json"
  )
  list(REMOVE_DUPLICATES _json_candidates)

  foreach(_json IN LISTS _json_candidates)
    _tally_json_sources_exist("${_json}")
    if(_TALLY_JSON_OK)
      set(CMAKE_CXX_STDLIB_MODULES_JSON "${_json}" CACHE FILEPATH
        "libc++ modules metadata" FORCE)
      message(STATUS "libc++ modules JSON: ${CMAKE_CXX_STDLIB_MODULES_JSON}")
      return()
    endif()
  endforeach()

  set(_std_candidates "")
  if(_prefix)
    list(APPEND _std_candidates "${_prefix}/share/libc++/v1/std.cppm")
  endif()
  if(_major)
    list(APPEND _std_candidates
      "/usr/lib/llvm-${_major}/share/libc++/v1/std.cppm"
    )
  endif()
  list(APPEND _std_candidates "/usr/share/libc++/v1/std.cppm")
  list(REMOVE_DUPLICATES _std_candidates)

  set(_std "")
  foreach(_f IN LISTS _std_candidates)
    if(EXISTS "${_f}")
      _tally_realpath("${_f}" _std)
      break()
    endif()
  endforeach()

  if(_std STREQUAL "")
    message(WARNING
      "Could not find libc++ std.cppm for Clang ${_major}. "
      "Install libc++-${_major}-dev (Debian/Ubuntu) or libcxx, "
      "or pass -DLIBCXX_STD_CPPM=/path/to/std.cppm")
    return()
  endif()

  _tally_write_libcxx_modules_json("${_std}")
endfunction()

endif() # TALLY_LIBCXX_MODULES_JSON_INCLUDED
