#!/usr/bin/env bash

plugin_validate_name() {
  [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] || die "invalid plugin name: $1"
}

plugin_path() {
  local name="$1"
  plugin_validate_name "$name"
  printf '%s/%s.sh' "$AEGISCOPE_PLUGIN_ROOT" "$name"
}

plugin_load() {
  local name="$1" path
  path="$(plugin_path "$name")"
  [[ -f "$path" ]] || die "plugin not found: $name"
  unset -f aegis_plugin_check aegis_plugin_build_command aegis_plugin_execute aegis_plugin_normalize aegis_plugin_artifacts 2>/dev/null || true
  unset AEGIS_PLUGIN_NAME AEGIS_PLUGIN_DESCRIPTION AEGIS_PLUGIN_COMMAND
  # shellcheck disable=SC1090
  source "$path"
  [[ "${AEGIS_PLUGIN_NAME:-}" == "$name" ]] || die "plugin identity mismatch in $path"
  local function
  for function in aegis_plugin_check aegis_plugin_build_command aegis_plugin_execute aegis_plugin_normalize aegis_plugin_artifacts; do
    declare -F "$function" >/dev/null 2>&1 || die "plugin $name does not implement $function"
  done
}

plugins_usage() {
  cat <<'EOF'
Usage:
  aegiscope plugins list
  aegiscope plugins doctor
  aegiscope plugins run --name NAME --target URL|HOST [--request-rate N] [--authorized]

Plugins implement check, build-command, execute, normalize and artifact hooks.
Only install and run locally reviewed plugin files.
EOF
}

plugins_command() {
  local action="${1:-list}" name="" target="" request_rate="$AEGISCOPE_MAX_RATE" authorized=0 path status=0 artifact resolved display started completed execution_status=0
  [[ $# -eq 0 ]] || shift
  case "$action" in
    list)
      mkdir -p "$AEGISCOPE_PLUGIN_ROOT"
      for path in "$AEGISCOPE_PLUGIN_ROOT"/*.sh; do
        [[ -f "$path" ]] || continue
        name="$(basename "$path" .sh)"
        plugin_load "$name"
        printf '%-20s %s\n' "$AEGIS_PLUGIN_NAME" "${AEGIS_PLUGIN_DESCRIPTION:-No description}"
      done
      ;;
    doctor)
      mkdir -p "$AEGISCOPE_PLUGIN_ROOT"
      for path in "$AEGISCOPE_PLUGIN_ROOT"/*.sh; do
        [[ -f "$path" ]] || continue
        name="$(basename "$path" .sh)"
        plugin_load "$name"
        if aegis_plugin_check >/dev/null 2>&1; then
          printf '%sready%s   %s\n' "$C_GREEN" "$C_RESET" "$name"
        else
          printf '%smissing%s %s\n' "$C_YELLOW" "$C_RESET" "$name"
          status=1
        fi
      done
      return "$status"
      ;;
    run)
      while (($#)); do
        case "$1" in
          --name)
            name="$2"
            shift 2
            ;;
          --target)
            target="$2"
            shift 2
            ;;
          --request-rate | --rate)
            request_rate="$2"
            shift 2
            ;;
          --scope-file)
            # Read by core authorization functions.
            # shellcheck disable=SC2034
            AEGISCOPE_SCOPE_FILE="$2"
            shift 2
            ;;
          --authorized)
            authorized=1
            shift
            ;;
          -h | --help)
            plugins_usage
            return 0
            ;;
          *) die "unknown plugins run option: $1" ;;
        esac
      done
      [[ -n "$name" && -n "$target" ]] || die "plugins run requires --name and --target"
      validate_rate "$request_rate"
      authorize_target "$target" "$authorized"
      plugin_load "$name"
      aegis_plugin_check || die "plugin dependency check failed: $name"
      create_run "$target" "plugin-${name}"
      AEGIS_PLUGIN_COMMAND=()
      aegis_plugin_build_command "$target" "$RUN_DIR" "$request_rate"
      if ((${#AEGIS_PLUGIN_COMMAND[@]} == 0)); then
        warn "plugin $name produced an empty command"
        write_manifest 1
        return 1
      fi
      display="$(sensitive_command_string "${AEGIS_PLUGIN_COMMAND[@]}")"
      RUN_COMMANDS+=("$display")
      started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      aegis_plugin_execute "$target" "$RUN_DIR" "$request_rate" || execution_status=$?
      completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      record_execution "$display" "" "$started" "$completed" "$execution_status"
      ((execution_status == 0)) || status=$execution_status
      aegis_plugin_normalize "$target" "$RUN_DIR" || status=$?
      while IFS= read -r artifact; do
        [[ -n "$artifact" && -e "$artifact" ]] || continue
        resolved="$(cd "$(dirname "$artifact")" && pwd)/$(basename "$artifact")"
        if [[ "$resolved" == "$RUN_DIR"/* ]]; then
          add_artifact "$resolved"
        else
          warn "plugin $name returned an artifact outside its run directory: $artifact"
          ((status == 0)) && status=1
        fi
      done < <(aegis_plugin_artifacts "$target" "$RUN_DIR")
      write_manifest "$status"
      return "$status"
      ;;
    -h | --help) plugins_usage ;;
    *) die "unknown plugins action: $action" ;;
  esac
}
