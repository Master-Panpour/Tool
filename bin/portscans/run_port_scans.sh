#!/usr/bin/env bash
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
printf 'Legacy entry point: use aegiscope ports --target HOST --profile PROFILE.\n' >&2
exec "${BASEDIR}/aegiscope" ports "$@"
