#!/usr/bin/env bash
# export using: Account stays on the global module; only _ZGIW5tally is module-owned.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec "$(cd "${here}/../.." && pwd)/scripts/nm-symbols.sh" --demo 04-mixed "$@"
