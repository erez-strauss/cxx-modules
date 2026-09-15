#!/usr/bin/env bash
# Module-owned ABI: tally::Account@tally::credit
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec "$(cd "${here}/../.." && pwd)/scripts/nm-symbols.sh" --demo 02-module "$@"
