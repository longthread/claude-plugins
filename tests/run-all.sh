#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$here"/test-*.sh; do
  bash "$t" || rc=1
done
exit "$rc"
