# Three compiler/stdlib lanes, applied before project():
#   TARGET_STDLIB=default     compiler default
#                             (g++ → libstdc++; Linux clang++ → usually libstdc++)
#   TARGET_STDLIB=libstdc++   Clang + libstdc++   (-stdlib=libstdc++, Clang only)
#   TARGET_STDLIB=libc++      Clang + libc++      (-stdlib=libc++, Clang only)
#
# Include from EnableImportStd.cmake (already before project()).
# JSON overrides: -DCMAKE_CXX_STDLIB_MODULES_JSON=...  or  -DLIBCXX_STD_CPPM=...
# Never share a build tree between lanes; use a preset or --fresh.

if(NOT TALLY_STDLIB_LANE_INCLUDED)
set(TALLY_STDLIB_LANE_INCLUDED TRUE)

include("${CMAKE_CURRENT_LIST_DIR}/ApplyStdlibFlags.cmake")

if(_TALLY_WANT_LIBCXX)
  include("${CMAKE_CURRENT_LIST_DIR}/LibcxxModulesJson.cmake")
  tally_use_libcxx_modules_json()
else()
  include("${CMAKE_CURRENT_LIST_DIR}/LibstdcxxModulesJson.cmake")
endif()

endif() # TALLY_STDLIB_LANE_INCLUDED
