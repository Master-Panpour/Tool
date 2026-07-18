#!/usr/bin/env bash
# shellcheck disable=SC2034

AEGIS_PLUGIN_NAME="http-head"
AEGIS_PLUGIN_DESCRIPTION="Capture normalized HTTP response headers with curl"
declare -a AEGIS_PLUGIN_COMMAND=()

aegis_plugin_check() {
  command -v curl >/dev/null 2>&1
}

aegis_plugin_build_command() {
  local target="$1" run_dir="$2"
  AEGIS_PLUGIN_COMMAND=(curl --silent --show-error --connect-timeout 10 --max-time 30 --dump-header "${run_dir}/http-head.headers" --output /dev/null --url "$target")
}

aegis_plugin_execute() {
  "${AEGIS_PLUGIN_COMMAND[@]}"
}

aegis_plugin_normalize() {
  local _target="$1" run_dir="$2"
  awk 'BEGIN { IGNORECASE=1 } /^[A-Za-z0-9-]+:/ { key=tolower($1); sub(/:$/, "", key); value=$0; sub(/^[^:]+:[[:space:]]*/, "", value); print key "=" value }' \
    "${run_dir}/http-head.headers" >"${run_dir}/http-head.normalized.txt"
}

aegis_plugin_artifacts() {
  local _target="$1" run_dir="$2"
  printf '%s\n' "${run_dir}/http-head.headers" "${run_dir}/http-head.normalized.txt"
}
