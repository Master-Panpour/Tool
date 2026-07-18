#!/usr/bin/env bash
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
read -rp 'Authorized target host/IP: ' target
printf 'Profiles: quick-tcp, full-tcp, udp-top, firewall-map, custom\n'
read -rp 'Profile [quick-tcp]: ' profile
exec "${BASEDIR}/aegiscope" ports --target "$target" --profile "${profile:-quick-tcp}" --authorized
