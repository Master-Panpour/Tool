#!/usr/bin/env bash
BASEDIR="$(cd "$(dirname "$0")" && pwd)"
printf 'Legacy entry point: DDoS is implemented as bounded single-source load resilience.\n' >&2
exec "${BASEDIR}/aegiscope" load "$@"
