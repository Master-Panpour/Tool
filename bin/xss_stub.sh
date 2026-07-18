#!/usr/bin/env bash
BASEDIR="$(cd "$(dirname "$0")" && pwd)"
printf 'Legacy entry point: running the non-executing XSS reflection audit.\n' >&2
exec "${BASEDIR}/aegiscope" xss "$@"
