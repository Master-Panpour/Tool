#!/usr/bin/env bash
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
read -rp 'Authorized target URL/domain: ' target
printf 'Modes: dir, vhost, subdomains, http, tls, all\n'
read -rp 'Mode [http]: ' mode
exec "${BASEDIR}/aegiscope" web --target "$target" --mode "${mode:-http}"
