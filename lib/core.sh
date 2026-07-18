#!/usr/bin/env bash

AEGISCOPE_NAME="IronCrypt Aegiscope"
AEGISCOPE_VERSION="0.4.0"
AEGISCOPE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AEGISCOPE_RESULTS_ROOT="${AEGISCOPE_RESULTS_ROOT:-${AEGISCOPE_ROOT}/results}"
AEGISCOPE_SCOPE_FILE="${AEGISCOPE_SCOPE_FILE:-${AEGISCOPE_ROOT}/config/authorized_scope.txt}"
AEGISCOPE_WORKSPACE_ROOT="${AEGISCOPE_WORKSPACE_ROOT:-${AEGISCOPE_RESULTS_ROOT}/workspace}"
AEGISCOPE_ASSET_DB="${AEGISCOPE_ASSET_DB:-${AEGISCOPE_WORKSPACE_ROOT}/assets.db}"
AEGISCOPE_CACHE_ROOT="${AEGISCOPE_CACHE_ROOT:-${AEGISCOPE_WORKSPACE_ROOT}/cache}"
AEGISCOPE_AUTH_ROOT="${AEGISCOPE_AUTH_ROOT:-${AEGISCOPE_WORKSPACE_ROOT}/auth}"
AEGISCOPE_PLUGIN_ROOT="${AEGISCOPE_PLUGIN_ROOT:-${AEGISCOPE_ROOT}/plugins}"
AEGISCOPE_BANNER_STYLE="${AEGISCOPE_BANNER_STYLE:-classic}"
AEGISCOPE_MAX_RATE="${AEGISCOPE_MAX_RATE:-100}"
AEGISCOPE_MAX_LOAD_DURATION="${AEGISCOPE_MAX_LOAD_DURATION:-60}"
AEGISCOPE_MAX_LOAD_CONCURRENCY="${AEGISCOPE_MAX_LOAD_CONCURRENCY:-20}"
AEGISCOPE_MAX_LOAD_REQUESTS="${AEGISCOPE_MAX_LOAD_REQUESTS:-1000}"
AEGISCOPE_MAX_REQUEST_BODY_BYTES="${AEGISCOPE_MAX_REQUEST_BODY_BYTES:-1048576}"
AEGISCOPE_MAX_RECURSION_DEPTH="${AEGISCOPE_MAX_RECURSION_DEPTH:-5}"

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

ui_banner_classic() {
  printf '%s%s╔════════════════════════════════════════════════════════════╗%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
  printf '%s%s║                IRONCRYPT AEGISCOPE                        ║%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '%s%s║      Reconnaissance • Assets • Evidence • Validation      ║%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
  printf '%s%s╚════════════════════════════════════════════════════════════╝%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
}

ui_banner_shield() {
  printf '%s%s                 /\\\n' "$C_BOLD" "$C_MAGENTA"
  printf '                /IC\\        %sIRONCRYPT%s\n' "$C_CYAN" "$C_MAGENTA"
  printf '               /____\\          │\n'
  printf '               \\    /          ▼\n'
  printf '                \\__/       %sAEGISCOPE%s\n' "$C_CYAN" "$C_MAGENTA"
  printf '             ASSET INTELLIGENCE%s\n' "$C_RESET"
}

ui_banner_minimal() {
  printf '%s%s[ IRONCRYPT ]%s %s→%s %s%sAEGISCOPE%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET" "$C_YELLOW" "$C_RESET" "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '%sAuthorized reconnaissance workspace • v%s%s\n' "$C_BLUE" "$AEGISCOPE_VERSION" "$C_RESET"
}

ui_banner() {
  case "$AEGISCOPE_BANNER_STYLE" in
    classic) ui_banner_classic ;;
    shield) ui_banner_shield ;;
    minimal) ui_banner_minimal ;;
    *) ui_banner_classic ;;
  esac
}

ui_set_banner_style() {
  AEGISCOPE_BANNER_STYLE="$1"
}

ui_brand_animation() {
  [[ -t 1 && "${NO_ANIMATION:-0}" != "1" && "${CI:-}" != "true" ]] || return 0
  local frame
  for frame in 'I' 'IR' 'IRON' 'IRONCRYPT' 'IRONCRYPT  →' 'IRONCRYPT  →  AEGIS' 'IRONCRYPT  →  AEGISCOPE'; do
    printf '\033[2J\033[H%s%s%s%s\n' "$C_BOLD" "$C_MAGENTA" "$frame" "$C_RESET"
    sleep 0.07
  done
  printf '\033[2J\033[H'
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

validate_header() {
  local header="$1" name
  [[ "$header" != *$'\n'* && "$header" != *$'\r'* && "$header" != *$'\t'* ]] || die "HTTP header contains a control character"
  [[ "${#header}" -le 8192 ]] || die "HTTP header exceeds the 8192-byte limit"
  [[ "$header" == *:* ]] || die "header must use 'Name: value' format"
  name="${header%%:*}"
  [[ "$name" =~ ^[A-Za-z0-9!#\$%\&\'*+.^_\`|~-]+$ ]] || die "invalid HTTP header name: $name"
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
    RUN_AUTHORIZATION_METHOD="explicit-cli-assertion"
    return 0
  fi
  [[ -t 0 ]] || die "non-interactive network operations require --authorized"
  printf "Target '%s' is in scope. Type 'I AM AUTHORIZED' to continue: " "$normalized"
  read -r answer
  [[ "$answer" == "I AM AUTHORIZED" ]] || die "authorization was not confirmed"
  RUN_AUTHORIZATION_METHOD="interactive-phrase-confirmation"
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  value="${value//$'\b'/\\b}"
  value="${value//$'\f'/\\f}"
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
declare -a RUN_EXECUTION_COMMANDS=()
declare -a RUN_EXECUTION_ARTIFACTS=()
declare -a RUN_EXECUTION_STARTED=()
declare -a RUN_EXECUTION_COMPLETED=()
declare -a RUN_EXECUTION_EXIT_CODES=()
RUN_DIR=""
RUN_STARTED=""
RUN_TARGET=""
RUN_OPERATION=""
RUN_SCOPE_KEY=""
RUN_AUTHORIZATION_METHOD="unconfirmed"

record_execution() {
  local command="$1" artifact="$2" started="$3" completed="$4" exit_code="$5"
  RUN_EXECUTION_COMMANDS+=("$command")
  RUN_EXECUTION_ARTIFACTS+=("${artifact#"$RUN_DIR"/}")
  RUN_EXECUTION_STARTED+=("$started")
  RUN_EXECUTION_COMPLETED+=("$completed")
  RUN_EXECUTION_EXIT_CODES+=("$exit_code")
}

file_sha256() {
  local path="$1" python
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$path" | awk '{print $NF}'
  elif python="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"; then
    "$python" -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$path"
  else
    printf 'unavailable'
  fi
}

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
  RUN_EXECUTION_COMMANDS=()
  RUN_EXECUTION_ARTIFACTS=()
  RUN_EXECUTION_STARTED=()
  RUN_EXECUTION_COMPLETED=()
  RUN_EXECUTION_EXIT_CODES=()
  mkdir -p "$RUN_DIR"
  if [[ -f "$AEGISCOPE_SCOPE_FILE" ]]; then
    cp "$AEGISCOPE_SCOPE_FILE" "${RUN_DIR}/scope-snapshot.txt"
    chmod 600 "${RUN_DIR}/scope-snapshot.txt" 2>/dev/null || true
    add_artifact "${RUN_DIR}/scope-snapshot.txt"
  fi
  info "Run directory: $RUN_DIR"
}

add_artifact() {
  local path="$1"
  RUN_ARTIFACTS+=("${path#"$RUN_DIR"/}")
}

run_logged() {
  local artifact="$1" started completed status display
  shift
  display="$(command_string "$@")"
  RUN_COMMANDS+=("$display")
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  "$@"
  status=$?
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  record_execution "$display" "$artifact" "$started" "$completed" "$status"
  if [[ -n "$artifact" && -e "$artifact" ]]; then
    add_artifact "$artifact"
  fi
  return "$status"
}

run_logged_capture() {
  local artifact="$1" started completed status display
  shift
  display="$(command_string "$@")"
  RUN_COMMANDS+=("$display")
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  "$@" >"$artifact" 2>&1
  status=$?
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  record_execution "$display" "$artifact" "$started" "$completed" "$status"
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
  local artifact="$1" started completed status display
  shift
  local -a actual=("$@")
  display="$(sensitive_command_string "${actual[@]}")"
  RUN_COMMANDS+=("$display")
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  "${actual[@]}"
  status=$?
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  record_execution "$display" "$artifact" "$started" "$completed" "$status"
  if [[ -n "$artifact" && -e "$artifact" ]]; then
    add_artifact "$artifact"
  fi
  return "$status"
}

run_logged_sensitive_capture() {
  local artifact="$1" started completed status display
  shift
  local -a actual=("$@")
  display="$(sensitive_command_string "${actual[@]}")"
  RUN_COMMANDS+=("$display")
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  "${actual[@]}" >"$artifact" 2>&1
  status=$?
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  record_execution "$display" "$artifact" "$started" "$completed" "$status"
  add_artifact "$artifact"
  return "$status"
}

write_manifest() {
  local exit_code="$1" status completed index tool first artifact relative size digest evidence_key manifest_tmp
  local -A seen_artifacts=()
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_tmp="${RUN_DIR}/.manifest.${BASHPID:-$$}.${RANDOM}.tmp"
  if ((exit_code == 0)); then
    status="completed"
    for index in "${RUN_EXECUTION_EXIT_CODES[@]}"; do
      if ((index != 0)); then
        status="completed_with_errors"
        break
      fi
    done
  else
    status="failed"
  fi
  {
    printf '{\n'
    printf '  "schema_version": "2.0",\n'
    printf '  "run_id": "%s",\n' "$(json_escape "$(basename "$RUN_DIR")")"
    printf '  "product": "%s",\n' "$(json_escape "$AEGISCOPE_NAME")"
    printf '  "version": "%s",\n' "$AEGISCOPE_VERSION"
    printf '  "operation": "%s",\n' "$(json_escape "$RUN_OPERATION")"
    printf '  "target": "%s",\n' "$(json_escape "$RUN_TARGET")"
    printf '  "scope_key": "%s",\n' "$(json_escape "$RUN_SCOPE_KEY")"
    printf '  "scope_file": "%s",\n' "$(json_escape "$AEGISCOPE_SCOPE_FILE")"
    printf '  "authorization": {"assertion": "%s", "scope_snapshot": "scope-snapshot.txt"},\n' "$(json_escape "$RUN_AUTHORIZATION_METHOD")"
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
    printf '  "executions": ['
    for index in "${!RUN_EXECUTION_COMMANDS[@]}"; do
      ((index > 0)) && printf ', '
      printf '{"command":"%s","artifact":"%s","started_at":"%s","completed_at":"%s","exit_code":%d}' \
        "$(json_escape "${RUN_EXECUTION_COMMANDS[$index]}")" "$(json_escape "${RUN_EXECUTION_ARTIFACTS[$index]}")" \
        "${RUN_EXECUTION_STARTED[$index]}" "${RUN_EXECUTION_COMPLETED[$index]}" "${RUN_EXECUTION_EXIT_CODES[$index]}"
    done
    printf '],\n'
    printf '  "tool_versions": {'
    first=1
    for tool in nmap curl openssl ffuf gobuster subfinder dnsx naabu httpx katana nuclei testssl.sh whatweb dig whois shodan hey k6 python3; do
      ((first == 0)) && printf ', '
      first=0
      printf '"%s": "%s"' "$tool" "$(json_escape "$(tool_version "$tool")")"
    done
    printf '},\n'
    printf '  "artifacts": ['
    first=1
    for artifact in "${RUN_ARTIFACTS[@]}"; do
      relative="${artifact#"$RUN_DIR"/}"
      [[ -z "${seen_artifacts[$relative]:-}" ]] || continue
      seen_artifacts[$relative]=1
      ((first == 0)) && printf ', '
      first=0
      printf '"%s"' "$(json_escape "$relative")"
    done
    printf '],\n'
    printf '  "evidence": ['
    first=1
    for artifact in "${RUN_ARTIFACTS[@]}"; do
      relative="${artifact#"$RUN_DIR"/}"
      [[ -f "${RUN_DIR}/${relative}" ]] || continue
      evidence_key="evidence:${relative}"
      [[ -z "${seen_artifacts[$evidence_key]:-}" ]] || continue
      seen_artifacts[$evidence_key]=1
      size="$(wc -c <"${RUN_DIR}/${relative}" | tr -d '[:space:]')"
      digest="$(file_sha256 "${RUN_DIR}/${relative}")"
      ((first == 0)) && printf ', '
      first=0
      printf '{"path":"%s","size_bytes":%d,"sha256":"%s"}' "$(json_escape "$relative")" "$size" "$(json_escape "$digest")"
    done
    printf ']\n}\n'
  } >"$manifest_tmp"
  mv "$manifest_tmp" "${RUN_DIR}/manifest.json" || die "unable to publish run manifest"
  info "Manifest: ${RUN_DIR}/manifest.json"
  if declare -F workspace_ingest_manifest >/dev/null 2>&1; then
    workspace_ingest_manifest "${RUN_DIR}/manifest.json" || warn "asset workspace ingestion failed; run 'aegiscope assets ingest' to retry"
  fi
}

latest_run_dir() {
  local manifest
  local -a runs=()
  [[ -d "$AEGISCOPE_RESULTS_ROOT" ]] || return 1
  while IFS= read -r manifest; do
    runs+=("$(dirname "$manifest")")
  done < <(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 2 -maxdepth 2 -type f -name manifest.json -print | sort)
  ((${#runs[@]} > 0)) || return 1
  printf '%s' "${runs[$((${#runs[@]} - 1))]}"
}
