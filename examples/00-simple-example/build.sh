#!/usr/bin/env bash
# CMake path: same graph as compile-cmds.*.sh, CMake is the collator.
set -euo pipefail
cd "$(dirname "$0")"
./clean.sh

cmake --preset gcc-libstdcxx -Wno-dev
cmake --build build/gcc-libstdcxx -v

cmake --preset clang-libcxx -Wno-dev
cmake --build build/clang-libcxx -v

cmake --preset clang-libstdcxx -Wno-dev
cmake --build build/clang-libstdcxx -v

ldd build/*/myu1
build/gcc-libstdcxx/myu1
