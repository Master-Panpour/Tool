#!/usr/bin/env bash

AEGISCOPE_NAME="IronCrypt Aegiscope"
AEGISCOPE_VERSION="0.2.0"
AEGISCOPE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AEGISCOPE_RESULTS_ROOT="${AEGISCOPE_RESULTS_ROOT:-${AEGISCOPE_ROOT}/results}"
AEGISCOPE_SCOPE_FILE="${AEGISCOPE_SCOPE_FILE:-${AEGISCOPE_ROOT}/config/authorized_scope.txt}"
AEGISCOPE_MAX_RATE="${AEGISCOPE_MAX_RATE:-100}"
AEGISCOPE_MAX_LOAD_DURATION="${AEGISCOPE_MAX_LOAD_DURATION:-60}"
AEGISCOPE_MAX_LOAD_CONCURRENCY="${AEGISCOPE_MAX_LOAD_CONCURRENCY:-20}"
AEGISCOPE_MAX_LOAD_REQUESTS="${AEGISCOPE_MAX_LOAD_REQUESTS:-1000}"

if [[ "${AEGISCOPE_FORCE_COLOR:-0}" == "1" || (-t 1 && -z "${NO_COLOR:-}") ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_MAGENTA=$'\033[35m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""
  C_BOLD=""
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_MAGENTA=""
  C_CYAN=""
fi

ui_banner() {
  printf '%s%s╔════════════════════════════════════════════════════════════╗%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
  printf '%s%s║                IRONCRYPT AEGISCOPE                        ║%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '%s%s║       Authorized Reconnaissance & Resilience Suite        ║%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
  printf '%s%s╚════════════════════════════════════════════════════════════╝%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
}

ui_section() {
  printf '\n%s%s%s%s\n' "$C_BOLD" "$C_BLUE" "$1" "$C_RESET"
}

ui_option() {
  printf '  %s%s%s%s  %s\n' "$C_BOLD" "$C_CYAN" "$1" "$C_RESET" "$2"
}

ui_prompt() {
  printf '%s%s›%s %s' "$C_BOLD" "$C_YELLOW" "$C_RESET" "$1"
}

ui_caution() {
  printf '%s%sCaution:%s %s\n' "$C_BOLD" "$C_YELLOW" "$C_RESET" 'Operate only within applicable law, written authorization, and the configured scope.'
}

die() {
  printf '%s%sError:%s %s\n' "$C_BOLD" "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}

warn() {
  printf '%s%sWarning:%s %s\n' "$C_BOLD" "$C_YELLOW" "$C_RESET" "$*" >&2
}

info() {
  printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

validate_rate() {
  local rate="$1"
  is_positive_integer "$rate" || die "request rate must be a positive integer"
  ((rate <= AEGISCOPE_MAX_RATE)) || die "request rate ${rate} exceeds the configured ceiling ${AEGISCOPE_MAX_RATE}"
}

sanitize_name() {
  local value="$1"
  value="${value//[^a-zA-Z0-9._-]/_}"
  value="${value#.}"
  value="${value:0:100}"
  [[ -n "$value" ]] || value="target"
  printf '%s' "$value"
}

extract_url_host() {
  local url="$1" authority host
  [[ "$url" =~ ^https?:// ]] || return 1
  authority="${url#*://}"
  authority="${authority%%/*}"
  authority="${authority%%\?*}"
  authority="${authority%%\#*}"
  [[ "$authority" != *"@"* ]] || return 1
  if [[ "$authority" == \[*\]* ]]; then
    host="${authority#\[}"
    host="${host%%\]*}"
  else
    host="${authority%%:*}"
  fi
  [[ -n "$host" ]] || return 1
  printf '%s' "${host,,}"
}

extract_url_port() {
  local url="$1" authority scheme port
  scheme="${url%%://*}"
  authority="${url#*://}"
  authority="${authority%%/*}"
  authority="${authority%%\?*}"
  authority="${authority%%\#*}"
  if [[ "$authority" == \[*\]:* ]]; then
    port="${authority##*:}"
  elif [[ "$authority" != \[*\]* && "$authority" == *:* ]]; then
    port="${authority##*:}"
  elif [[ "$scheme" == "https" ]]; then
    port="443"
  else
    port="80"
  fi
  [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)) || return 1
  printf '%s' "$port"
}

normalize_scope_target() {
  local target="$1"
  if [[ "$target" =~ ^https?:// ]]; then
    extract_url_host "$target"
  else
    if [[ "$target" == \[*\] ]]; then
      target="${target#\[}"
      target="${target%%\]*}"
    fi
    printf '%s' "${target,,}"
  fi
}

validate_target() {
  local target="$1" normalized
  [[ -n "$target" ]] || die "target cannot be empty"
  [[ "$target" != -* ]] || die "target cannot begin with '-'"
  [[ "$target" != *$'\n'* && "$target" != *$'\r'* && "$target" != *$'\t'* ]] || die "target contains control characters"
  if [[ "$target" =~ ^https?:// ]]; then
    extract_url_host "$target" >/dev/null || die "invalid HTTP(S) URL: $target"
    extract_url_port "$target" >/dev/null || die "invalid URL port: $target"
  else
    normalized="$(normalize_scope_target "$target")"
    [[ "$normalized" =~ ^[a-z0-9._:-]+$ ]] || die "invalid hostname or IP address: $target"
  fi
}

ipv4_to_int() {
  local ip="$1" a b c d
  IFS=. read -r a b c d <<<"$ip"
  [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ && "$c" =~ ^[0-9]+$ && "$d" =~ ^[0-9]+$ ]] || return 1
  ((a <= 255 && b <= 255 && c <= 255 && d <= 255)) || return 1
  printf '%u' "$(((a << 24) | (b << 16) | (c << 8) | d))"
}

ipv4_in_cidr() {
  local ip="$1" cidr="$2" network prefix ip_int net_int mask
  network="${cidr%/*}"
  prefix="${cidr#*/}"
  [[ "$prefix" =~ ^[0-9]+$ ]] && ((prefix >= 0 && prefix <= 32)) || return 1
  ip_int="$(ipv4_to_int "$ip")" || return 1
  net_int="$(ipv4_to_int "$network")" || return 1
  if ((prefix == 0)); then
    mask=0
  else
    mask=$(((0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF))
  fi
  (((ip_int & mask) == (net_int & mask)))
}

scope_allows() {
  local target="$1" entry normalized
  normalized="$(normalize_scope_target "$target")"
  [[ -f "$AEGISCOPE_SCOPE_FILE" ]] || return 1
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    entry="${entry%%#*}"
    entry="${entry//[[:space:]]/}"
    [[ -n "$entry" ]] || continue
    entry="${entry,,}"
    if [[ "$entry" == "$normalized" ]]; then
      return 0
    fi
    if [[ "$entry" == \*.* && "$normalized" == *"${entry#\*}" ]]; then
      return 0
    fi
    if [[ "$entry" == */* ]] && ipv4_in_cidr "$normalized" "$entry"; then
      return 0
    fi
  done <"$AEGISCOPE_SCOPE_FILE"
  return 1
}

authorize_target() {
  local target="$1" authorized="$2" answer normalized
  validate_target "$target"
  normalized="$(normalize_scope_target "$target")"
  scope_allows "$target" || die "target '${normalized}' is not allowed by scope file ${AEGISCOPE_SCOPE_FILE}"
  if [[ "$authorized" == "1" ]]; then
    return 0
  fi
  [[ -t 0 ]] || die "non-interactive network operations require --authorized"
  printf "Target '%s' is in scope. Type 'I AM AUTHORIZED' to continue: " "$normalized"
  read -r answer
  [[ "$answer" == "I AM AUTHORIZED" ]] || die "authorization was not confirmed"
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

command_string() {
  local arg output=""
  for arg in "$@"; do
    printf -v arg '%q' "$arg"
    output+="${output:+ }${arg}"
  done
  printf '%s' "$output"
}

tool_version() {
  local tool="$1" output
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'not installed'
    return
  fi
  output="$($tool --version 2>&1 | head -n 1 || true)"
  [[ -n "$output" ]] || output="installed"
  printf '%s' "$output"
}

declare -a RUN_COMMANDS=()
declare -a RUN_ARTIFACTS=()
RUN_DIR=""
RUN_STARTED=""
RUN_TARGET=""
RUN_OPERATION=""
RUN_SCOPE_KEY=""

create_run() {
  local target="$1" operation="$2" run_id safe_target
  RUN_STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  run_id="$(date -u +%Y%m%dT%H%M%SZ)_${BASHPID:-$$}_${RANDOM}"
  safe_target="$(sanitize_name "$(normalize_scope_target "$target")")"
  RUN_DIR="${AEGISCOPE_RESULTS_ROOT}/${run_id}_${safe_target}_${operation}"
  RUN_TARGET="$target"
  RUN_SCOPE_KEY="$(normalize_scope_target "$target")"
  RUN_OPERATION="$operation"
  RUN_COMMANDS=()
  RUN_ARTIFACTS=()
  mkdir -p "$RUN_DIR"
  info "Run directory: $RUN_DIR"
}

add_artifact() {
  local path="$1"
  RUN_ARTIFACTS+=("${path#"$RUN_DIR"/}")
}

run_logged() {
  local artifact="$1"
  shift
  RUN_COMMANDS+=("$(command_string "$@")")
  "$@"
  local status=$?
  if [[ -n "$artifact" && -e "$artifact" ]]; then
    add_artifact "$artifact"
  fi
  return "$status"
}

run_logged_capture() {
  local artifact="$1"
  shift
  RUN_COMMANDS+=("$(command_string "$@")")
  "$@" >"$artifact" 2>&1
  local status=$?
  add_artifact "$artifact"
  return "$status"
}

sensitive_command_string() {
  local -a display=("$@")
  local index previous
  for index in "${!display[@]}"; do
    previous=""
    ((index > 0)) && previous="${display[$((index - 1))]}"
    if [[ "$previous" == "-H" || "$previous" == "--header" ]]; then
      case "${display[$index],,}" in
        authorization:* | cookie:* | proxy-authorization:*) display[$index]="${display[$index]%%:*}: [REDACTED]" ;;
      esac
    elif [[ "$previous" == "-d" || "$previous" == "--data" || "$previous" == "--data-raw" || "$previous" == "--data-binary" ]]; then
      display[$index]="[REDACTED REQUEST BODY]"
    elif [[ "$previous" == "-e" ]]; then
      case "${display[$index]}" in
        BODY=* | HEADERS_JSON=*) display[$index]="${display[$index]%%=*}=[REDACTED]" ;;
      esac
    fi
  done
  command_string "${display[@]}"
}

run_logged_sensitive() {
  local artifact="$1"
  shift
  local -a actual=("$@")
  RUN_COMMANDS+=("$(sensitive_command_string "${actual[@]}")")
  "${actual[@]}"
  local status=$?
  if [[ -n "$artifact" && -e "$artifact" ]]; then
    add_artifact "$artifact"
  fi
  return "$status"
}

run_logged_sensitive_capture() {
  local artifact="$1"
  shift
  local -a actual=("$@")
  RUN_COMMANDS+=("$(sensitive_command_string "${actual[@]}")")
  "${actual[@]}" >"$artifact" 2>&1
  local status=$?
  add_artifact "$artifact"
  return "$status"
}

write_manifest() {
  local exit_code="$1" status completed index tool first
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if ((exit_code == 0)); then status="completed"; else status="failed"; fi
  {
    printf '{\n'
    printf '  "product": "%s",\n' "$(json_escape "$AEGISCOPE_NAME")"
    printf '  "version": "%s",\n' "$AEGISCOPE_VERSION"
    printf '  "operation": "%s",\n' "$(json_escape "$RUN_OPERATION")"
    printf '  "target": "%s",\n' "$(json_escape "$RUN_TARGET")"
    printf '  "scope_key": "%s",\n' "$(json_escape "$RUN_SCOPE_KEY")"
    printf '  "scope_file": "%s",\n' "$(json_escape "$AEGISCOPE_SCOPE_FILE")"
    printf '  "started_at": "%s",\n' "$RUN_STARTED"
    printf '  "completed_at": "%s",\n' "$completed"
    printf '  "status": "%s",\n' "$status"
    printf '  "exit_code": %d,\n' "$exit_code"
    printf '  "commands": ['
    for index in "${!RUN_COMMANDS[@]}"; do
      ((index > 0)) && printf ', '
      printf '"%s"' "$(json_escape "${RUN_COMMANDS[$index]}")"
    done
    printf '],\n'
    printf '  "tool_versions": {'
    first=1
    for tool in nmap curl openssl ffuf gobuster subfinder httpx testssl.sh whatweb dig whois shodan hey k6; do
      ((first == 0)) && printf ', '
      first=0
      printf '"%s": "%s"' "$tool" "$(json_escape "$(tool_version "$tool")")"
    done
    printf '},\n'
    printf '  "artifacts": ['
    for index in "${!RUN_ARTIFACTS[@]}"; do
      ((index > 0)) && printf ', '
      printf '"%s"' "$(json_escape "${RUN_ARTIFACTS[$index]}")"
    done
    printf ']\n}\n'
  } >"${RUN_DIR}/manifest.json"
  info "Manifest: ${RUN_DIR}/manifest.json"
}

latest_run_dir() {
  local -a runs=()
  [[ -d "$AEGISCOPE_RESULTS_ROOT" ]] || return 1
  mapfile -t runs < <(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -print | sort)
  ((${#runs[@]} > 0)) || return 1
  printf '%s' "${runs[$((${#runs[@]} - 1))]}"
}
