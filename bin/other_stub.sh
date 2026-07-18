#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(cd "$(dirname "$0")" && pwd)"
printf 'Legacy entry point: opening IronCrypt Aegiscope.\n' >&2
exec "${BASEDIR}/aegiscope" "$@"
