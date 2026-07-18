#!/usr/bin/env bash
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
printf 'Legacy entry point: use aegiscope recon --target URL --stage STAGE.\n' >&2
exec "${BASEDIR}/aegiscope" recon "$@"
