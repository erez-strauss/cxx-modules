#!/usr/bin/env bash
# Hand-written Clang + libc++ build. PCM names must match the module names.
set -euo pipefail
cd "$(dirname "$0")"
VERBOSE=1
function run(){ if (( $VERBOSE )); then echo "run: $*"; fi ; "$@"; }
./clean.sh

STD_CPPM="${STD_CPPM:-}"
if [[ -z "${STD_CPPM}" ]]; then
  for f in \
      /usr/share/libc++/v1/std.cppm \
      /usr/lib/llvm-*/share/libc++/v1/std.cppm \
      /usr/lib64/llvm*/share/libc++/v1/std.cppm; do
    [[ -f "${f}" ]] && STD_CPPM="${f}" && break
  done
fi
[[ -n "${STD_CPPM}" ]] || { echo "could not find libc++ std.cppm" >&2; exit 1; }
STD_COMPAT_CPPM="${STD_CPPM%/*}/std.compat.cppm"

CXXFLAGS=(-std=c++26 -stdlib=libc++ -O2 -Wall -Wextra -Wpedantic)

run clang++ "${CXXFLAGS[@]}" -Wno-reserved-module-identifier -x c++-module \
  -fmodule-output=std.pcm -c -o std.o "${STD_CPPM}"
run clang++ "${CXXFLAGS[@]}" -Wno-reserved-module-identifier -x c++-module \
  -fprebuilt-module-path=. -fmodule-output=std.compat.pcm -c -o std.compat.o \
  "${STD_COMPAT_CPPM}"

run clang++ "${CXXFLAGS[@]}" -fprebuilt-module-path=. -fmodule-output=mym1.pcm \
  -c -o mym1.o mym1.cppm
run clang++ "${CXXFLAGS[@]}" -fprebuilt-module-path=. -c -o myu1.o myu1.cpp
run clang++ "${CXXFLAGS[@]}" -stdlib=libc++ -o myu1 myu1.o mym1.o std.o std.compat.o

run ./myu1
run ldd ./myu1
