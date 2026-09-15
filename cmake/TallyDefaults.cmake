# Working language is C++26; C++23 is the minimum (`import std;` is C++23).
# Include AFTER project() so CMAKE_CXX_COMPILE_FEATURES is populated.
#
# EnableImportStd already froze CMAKE_CXX_STANDARD / EXTENSIONS before
# project() so the import-std BMI matches our TUs. Do not lower the
# standard here — Clang will reject a gnu++/c++ mix, and a 26 BMI with
# 23 TUs is the same class of bug.

if(NOT CMAKE_CXX_STANDARD)
  if("cxx_std_26" IN_LIST CMAKE_CXX_COMPILE_FEATURES)
    set(CMAKE_CXX_STANDARD 26)
  else()
    set(CMAKE_CXX_STANDARD 23)
  endif()
endif()
if(NOT DEFINED TALLY_CXX_STANDARD)
  set(TALLY_CXX_STANDARD ${CMAKE_CXX_STANDARD})
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF CACHE BOOL
  "ISO C++ (-std=c++NN), not GNU extensions (-std=gnu++NN). Mixed dialects break Clang import std."
  FORCE)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

message(STATUS "tally C++ standard: ${TALLY_CXX_STANDARD}")

function(tally_warnings target)
  target_compile_options(${target} PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic>
  )
endfunction()
