#!/usr/bin/env bash
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-http}"
shift || true
case "$mode" in headers) mode=http ;; ssl) mode=tls ;; cms) mode=http ;; esac
printf 'Legacy entry point: use aegiscope web --target URL --mode %s.\n' "$mode" >&2
exec "${BASEDIR}/aegiscope" web --mode "$mode" "$@"
