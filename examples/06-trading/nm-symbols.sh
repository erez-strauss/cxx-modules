#!/usr/bin/env bash
# Same names in libtrading.a and libtrading.so (nm -C vs nm -DC).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec "$(cd "${here}/../.." && pwd)/scripts/nm-symbols.sh" --demo 06-trading "$@"
