#!/usr/bin/env bash
# Compatibility launcher for the former project name.
BASEDIR="$(cd "$(dirname "$0")" && pwd)"
printf 'Notice: IronCrypt Recon CLI is now IronCrypt Aegiscope. Use bin/aegiscope.\n' >&2
exec "${BASEDIR}/aegiscope" "$@"
