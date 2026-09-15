#!/usr/bin/env bash
# Header ABI: tally::Account::credit  (no @tally)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
exec "$(cd "${here}/../.." && pwd)/scripts/nm-symbols.sh" --demo 01-headers "$@"
