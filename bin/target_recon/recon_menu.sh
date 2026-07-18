#!/usr/bin/env bash
BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
read -rp 'Authorized target URL/domain: ' target
printf 'Stages: server, metafiles, applications, entry-points, paths, architecture, all\n'
read -rp 'Stage [all]: ' stage
exec "${BASEDIR}/aegiscope" recon --target "$target" --stage "${stage:-all}" --authorized
