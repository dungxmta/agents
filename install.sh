#!/usr/bin/env bash
# First run on a new machine: same as `bin/agent sync`.
exec "$(cd "$(dirname "$0")" && pwd)/bin/agent" sync "$@"
