#!/usr/bin/env bash
# Build static .a and shared .so, then CPack TGZ (headers, .cppm, lib, three apps).
set -euo pipefail
cd "$(dirname "$0")"

for preset in gcc-libstdcxx gcc-libstdcxx-shared; do
  cmake --preset "${preset}" -Wno-dev --fresh
  cmake --build "build/${preset}"
  cmake --build "build/${preset}" --target package
done

echo "=== tarballs ==="
ls -l build/gcc-libstdcxx/trading-*.tar.gz \
      build/gcc-libstdcxx-shared/trading-*.tar.gz
