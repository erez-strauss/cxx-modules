# Wrapper so 00 / 06 CMakeLists keep calling simple_example_use_libcxx_modules_json().
include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/LibcxxModulesJson.cmake")

function(simple_example_use_libcxx_modules_json)
  tally_use_libcxx_modules_json()
endfunction()
