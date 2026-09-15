#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./clean.sh

cmake --preset gcc-libstdcxx -Wno-dev
cmake --build build/gcc-libstdcxx
cmake --preset gcc-libstdcxx-shared -Wno-dev
cmake --build build/gcc-libstdcxx-shared
cmake --preset clang-libstdcxx -Wno-dev
cmake --build build/clang-libstdcxx
cmake --preset clang-libcxx -Wno-dev
cmake --build build/clang-libcxx

for d in gcc-libstdcxx gcc-libstdcxx-shared clang-libstdcxx clang-libcxx; do
  echo "=== ${d} ==="
  "build/${d}/oms_legacy"
  "build/${d}/oms_modules"
  "build/${d}/post_trade"
  ls -l "build/${d}/libtrading."* 2>/dev/null || ls -l "build/${d}/"libtrading*
done

echo "=== symbols (global vs @trading) ==="
./nm-symbols.sh
