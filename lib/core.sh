#!/usr/bin/env bash

AEGISCOPE_NAME="IronCrypt Aegiscope"
AEGISCOPE_VERSION="0.4.2"
AEGISCOPE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AEGISCOPE_RESULTS_ROOT="${AEGISCOPE_RESULTS_ROOT:-${AEGISCOPE_ROOT}/results}"
AEGISCOPE_SCOPE_FILE="${AEGISCOPE_SCOPE_FILE:-${AEGISCOPE_ROOT}/config/authorized_scope.txt}"
AEGISCOPE_WORKSPACE_ROOT="${AEGISCOPE_WORKSPACE_ROOT:-${AEGISCOPE_RESULTS_ROOT}/workspace}"
AEGISCOPE_ASSET_DB="${AEGISCOPE_ASSET_DB:-${AEGISCOPE_WORKSPACE_ROOT}/assets.db}"
AEGISCOPE_CACHE_ROOT="${AEGISCOPE_CACHE_ROOT:-${AEGISCOPE_WORKSPACE_ROOT}/cache}"
AEGISCOPE_AUTH_ROOT="${AEGISCOPE_AUTH_ROOT:-${AEGISCOPE_WORKSPACE_ROOT}/auth}"
AEGISCOPE_PLUGIN_ROOT="${AEGISCOPE_PLUGIN_ROOT:-${AEGISCOPE_ROOT}/plugins}"
AEGISCOPE_BANNER_STYLE="${AEGISCOPE_BANNER_STYLE:-permanent}"
AEGISCOPE_MAX_RATE="${AEGISCOPE_MAX_RATE:-100}"
AEGISCOPE_MAX_LOAD_DURATION="${AEGISCOPE_MAX_LOAD_DURATION:-60}"
AEGISCOPE_MAX_LOAD_CONCURRENCY="${AEGISCOPE_MAX_LOAD_CONCURRENCY:-20}"
AEGISCOPE_MAX_LOAD_REQUESTS="${AEGISCOPE_MAX_LOAD_REQUESTS:-1000}"
AEGISCOPE_MAX_REQUEST_BODY_BYTES="${AEGISCOPE_MAX_REQUEST_BODY_BYTES:-1048576}"
AEGISCOPE_MAX_RECURSION_DEPTH="${AEGISCOPE_MAX_RECURSION_DEPTH:-5}"
AEGISCOPE_COMMAND_TIMEOUT="${AEGISCOPE_COMMAND_TIMEOUT:-900}"
AEGISCOPE_VERSION_TIMEOUT="${AEGISCOPE_VERSION_TIMEOUT:-10}"
AEGISCOPE_WHOIS_TIMEOUT="${AEGISCOPE_WHOIS_TIMEOUT:-30}"
AEGISCOPE_NAABU_TIMEOUT="${AEGISCOPE_NAABU_TIMEOUT:-900}"
AEGISCOPE_NUCLEI_TIMEOUT="${AEGISCOPE_NUCLEI_TIMEOUT:-900}"
AEGISCOPE_PROGRESS_INTERVAL="${AEGISCOPE_PROGRESS_INTERVAL:-15}"
AEGISCOPE_SUBFINDER_MIN_RESULTS="${AEGISCOPE_SUBFINDER_MIN_RESULTS:-2}"
AEGISCOPE_HTTPX_ALLOW_MODEL_DOWNLOAD="${AEGISCOPE_HTTPX_ALLOW_MODEL_DOWNLOAD:-0}"

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

ui_banner_permanent() {
  printf '%s%s            .-------------------------.%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
  printf '%s%s           /        IRONCRYPT          \\%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
  printf '%s%s          /   /\\              /\\     \\%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
  printf '%s%s         |   /  \\   .----.   /  \\     |%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '%s%s         |  | () | / o  o \\ | () |    |%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '%s%s         |   \\__/ |   /\\   | \\__/     |%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '%s%s         |         \\  ====  /          |%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '%s%s%s%s\n' "$C_BOLD" "$C_MAGENTA" "          \\         '----'          /" "$C_RESET"
  printf '%s%s%s%s\n' "$C_BOLD" "$C_MAGENTA" "           '--------[  IC  ]--------'" "$C_RESET"
  printf '%s%s                    \\/%s\n' "$C_BOLD" "$C_YELLOW" "$C_RESET"
  printf '%s%s                 AEGISCOPE%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '%s%s       AUTHORIZED RECONNAISSANCE SENTINEL%s\n' "$C_BOLD" "$C_BLUE" "$C_RESET"
}

ui_brand_credits() {
  printf '%s%sIronCrypt%s • Made by %sMaster_Panpour%s & %sMaster_Demon%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
}

ui_banner() {
  case "$AEGISCOPE_BANNER_STYLE" in
    classic) ui_banner_classic ;;
    shield) ui_banner_shield ;;
    minimal) ui_banner_minimal ;;
    permanent) ui_banner_permanent ;;
    *) ui_banner_permanent ;;
  esac
  ui_brand_credits
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

terminal_safe_text() {
  local value="$1" limit="${2:-1024}" truncated=0 output="" char code index ansi_pattern
  if ((${#value} > limit)); then
    value="${value:0:limit}"
    truncated=1
  fi
  ansi_pattern=$'\033''\[[0-9;?]*[ -/]*[@-~]'
  while [[ "$value" =~ $ansi_pattern ]]; do
    value="${value/"${BASH_REMATCH[0]}"/}"
  done
  for ((index = 0; index < ${#value}; index++)); do
    char="${value:index:1}"
    case "$char" in
      $'\n' | $'\r' | $'\t') output+=' ' ;;
      *)
        printf -v code '%d' "'$char"
        ((code >= 32 && code != 127)) && output+="$char"
        ;;
    esac
  done
  printf '%s' "$output"
  ((truncated == 0)) || printf '...[truncated]'
}

die() {
  printf '%s%sError:%s %s\n' "$C_BOLD" "$C_RED" "$C_RESET" "$(terminal_safe_text "$*")" >&2
  exit 1
}

warn() {
  printf '%s%sWarning:%s %s\n' "$C_BOLD" "$C_YELLOW" "$C_RESET" "$(terminal_safe_text "$*")" >&2
}

info() {
  printf '%s%s%s\n' "$C_GREEN" "$(terminal_safe_text "$*")" "$C_RESET"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_option_argument() {
  (($# >= 2)) || die "option $1 requires a value"
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

validate_rate() {
  local rate="$1" ceiling="$AEGISCOPE_MAX_RATE"
  is_positive_integer "$ceiling" && ((${#ceiling} <= 9)) || die "AEGISCOPE_MAX_RATE must be a positive integer of at most 9 digits"
  is_positive_integer "$rate" || die "request rate must be a positive integer"
  ((${#rate} <= 9)) || die "request rate is too large"
  ((10#$rate <= 10#$ceiling)) || die "request rate ${rate} exceeds the configured ceiling ${ceiling}"
}

validate_runtime_configuration() {
  local name value
  for name in AEGISCOPE_COMMAND_TIMEOUT AEGISCOPE_VERSION_TIMEOUT AEGISCOPE_WHOIS_TIMEOUT AEGISCOPE_NAABU_TIMEOUT AEGISCOPE_NUCLEI_TIMEOUT AEGISCOPE_PROGRESS_INTERVAL; do
    value="${!name}"
    is_positive_integer "$value" && ((${#value} <= 9)) || die "$name must be a positive integer of at most 9 digits"
  done
  value="$AEGISCOPE_SUBFINDER_MIN_RESULTS"
  [[ "$value" =~ ^[0-9]+$ ]] && ((${#value} <= 9)) || die "AEGISCOPE_SUBFINDER_MIN_RESULTS must be a non-negative integer of at most 9 digits"
  [[ "$AEGISCOPE_HTTPX_ALLOW_MODEL_DOWNLOAD" == 0 || "$AEGISCOPE_HTTPX_ALLOW_MODEL_DOWNLOAD" == 1 ]] || die "AEGISCOPE_HTTPX_ALLOW_MODEL_DOWNLOAD must be 0 or 1"
  validate_rate 1
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
  local value="$1" output="" char escaped code index
  for ((index = 0; index < ${#value}; index++)); do
    char="${value:index:1}"
    case "$char" in
      '"') output+='\"' ;;
      '\') output+='\\' ;;
      $'\b') output+='\b' ;;
      $'\f') output+='\f' ;;
      $'\n') output+='\n' ;;
      $'\r') output+='\r' ;;
      $'\t') output+='\t' ;;
      *)
        printf -v code '%d' "'$char"
        if ((code < 32 || code == 127)); then
          printf -v escaped '\\u%04x' "$code"
          output+="$escaped"
        else
          output+="$char"
        fi
        ;;
    esac
  done
  printf '%s' "$output"
}

command_string() {
  local arg output=""
  for arg in "$@"; do
    printf -v arg '%q' "$arg"
    output+="${output:+ }${arg}"
  done
  printf '%s' "$output"
}

command_label() {
  local arg
  if [[ "${1:-}" == env ]]; then shift; fi
  for arg in "$@"; do
    [[ "$arg" == *=* ]] && continue
    printf '%s' "${arg##*/}"
    return
  done
  printf 'external command'
}

tool_version() {
  local tool="$1" output status=0
  local -a args=()
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'not installed'
    return
  fi
  case "$tool" in
    ffuf) args=(-V) ;;
    gobuster | k6 | openssl | shodan) args=(version) ;;
    subfinder | dnsx | naabu | httpx | katana | nuclei) args=(-version) ;;
    dig) args=(-v) ;;
    ping | tracepath) args=(-V) ;;
    hey) args=(-version) ;;
    *) args=(--version) ;;
  esac
  output="$(NO_COLOR=1 TERM=dumb execute_bounded "$AEGISCOPE_VERSION_TIMEOUT" "$tool" "${args[@]}" 2>&1)" || status=$?
  output="${output%%$'\n'*}"
  output="$(strip_ansi "$output")"
  if ((status != 0)) || [[ -z "$output" ]]; then
    output="installed (version unavailable)"
  fi
  printf '%s' "$output"
}

strip_ansi() {
  local value="$1" ansi_pattern
  ansi_pattern=$'\033''\[[0-9;?]*[ -/]*[@-~]'
  while [[ "$value" =~ $ansi_pattern ]]; do
    value="${value/"${BASH_REMATCH[0]}"/}"
  done
  terminal_safe_text "$value" 512
}

timeout_binary() {
  if command -v timeout >/dev/null 2>&1; then
    printf '%s' timeout
  elif command -v gtimeout >/dev/null 2>&1; then
    printf '%s' gtimeout
  else
    return 1
  fi
}

execute_bounded() {
  local seconds="$1" timeout_cmd
  shift
  timeout_cmd="$(timeout_binary)" || die "required command not found: timeout (GNU coreutils)"
  "$timeout_cmd" --signal=TERM --kill-after=5s "${seconds}s" "$@"
}

PROGRESS_PID=""

progress_start() {
  local label="$1" seconds="$2" interval="$AEGISCOPE_PROGRESS_INTERVAL"
  info "Starting ${label} (deadline: ${seconds}s)"
  PROGRESS_PID=""
  [[ -t 2 ]] || return 0
  (
    local elapsed=0
    while sleep "$interval"; do
      elapsed=$((elapsed + interval))
      printf '%sProgress:%s %s running for %ss (deadline %ss)\n' "$C_BLUE" "$C_RESET" "$(terminal_safe_text "$label" 128)" "$elapsed" "$seconds" >&2
    done
  ) &
  PROGRESS_PID=$!
}

progress_stop() {
  [[ -n "$PROGRESS_PID" ]] || return 0
  kill "$PROGRESS_PID" 2>/dev/null || true
  wait "$PROGRESS_PID" 2>/dev/null || true
  PROGRESS_PID=""
}

report_timeout() {
  local status="$1" label="$2" seconds="$3"
  ((status != 124 && status != 137)) || warn "$label exceeded its ${seconds}s deadline and was terminated"
}

prepare_httpx_command() {
  local destination_name="$1"
  shift
  local -n destination="$destination_name"
  local runtime_home policy="${RUN_DIR}/httpx-runtime-policy.json"
  if [[ "$AEGISCOPE_HTTPX_ALLOW_MODEL_DOWNLOAD" == 1 ]]; then
    printf '%s\n' '{"update_check":false,"stdin":false,"isolated_home":false,"classifier_model_opt_in":true}' >"$policy"
    add_artifact "$policy"
    # Assigned through a nameref supplied by the caller.
    # shellcheck disable=SC2034
    destination=(httpx -disable-update-check -no-color -no-stdin "$@")
    return
  fi
  runtime_home="${RUN_DIR}/.runtime/httpx-home"
  mkdir -p "${runtime_home}/.dit"
  printf '%s\n' 'offline-model-download-disabled' >"${runtime_home}/.dit/model.json"
  chmod 600 "${runtime_home}/.dit/model.json" 2>/dev/null || true
  printf '%s\n' '{"update_check":false,"stdin":false,"isolated_home":true,"classifier_model_opt_in":false}' >"$policy"
  add_artifact "$policy"
  # shellcheck disable=SC2034
  destination=(env HOME="$runtime_home" httpx -disable-update-check -no-color -no-stdin "$@")
}

record_subfinder_coverage() {
  local hosts_file="$1" report_file="$2" count=0 low=false
  [[ ! -f "$hosts_file" ]] || count="$(wc -l <"$hosts_file" | tr -d '[:space:]')"
  [[ "$count" =~ ^[0-9]+$ ]] || count=0
  if ((count < AEGISCOPE_SUBFINDER_MIN_RESULTS)); then
    low=true
    warn "Subfinder returned only ${count} unique host(s); passive-source coverage may be incomplete"
  fi
  printf '{"unique_hosts":%d,"warning_threshold":%d,"low_coverage":%s}\n' "$count" "$AEGISCOPE_SUBFINDER_MIN_RESULTS" "$low" >"$report_file"
  add_artifact "$report_file"
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
  run_logged_timed "$AEGISCOPE_COMMAND_TIMEOUT" "$@"
}

run_logged_timed() {
  local deadline="$1"
  shift
  local artifact="$1" started completed status display label
  shift
  display="$(command_string "$@")"
  label="$(command_label "$@")"
  RUN_COMMANDS+=("$display")
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  progress_start "$label" "$deadline"
  execute_bounded "$deadline" "$@"
  status=$?
  progress_stop
  report_timeout "$status" "$label" "$deadline"
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  record_execution "$display" "$artifact" "$started" "$completed" "$status"
  if [[ -n "$artifact" && -e "$artifact" ]]; then
    add_artifact "$artifact"
  fi
  return "$status"
}

run_logged_capture() {
  run_logged_capture_timed "$AEGISCOPE_COMMAND_TIMEOUT" "$@"
}

run_logged_capture_timed() {
  local deadline="$1"
  shift
  local artifact="$1" started completed status display label
  shift
  display="$(command_string "$@")"
  label="$(command_label "$@")"
  RUN_COMMANDS+=("$display")
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  progress_start "$label" "$deadline"
  execute_bounded "$deadline" "$@" >"$artifact" 2>&1
  status=$?
  progress_stop
  report_timeout "$status" "$label" "$deadline"
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
  run_logged_sensitive_timed "$AEGISCOPE_COMMAND_TIMEOUT" "$@"
}

run_logged_sensitive_timed() {
  local deadline="$1"
  shift
  local artifact="$1" started completed status display label
  shift
  local -a actual=("$@")
  display="$(sensitive_command_string "${actual[@]}")"
  label="$(command_label "${actual[@]}")"
  RUN_COMMANDS+=("$display")
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  progress_start "$label" "$deadline"
  execute_bounded "$deadline" "${actual[@]}"
  status=$?
  progress_stop
  report_timeout "$status" "$label" "$deadline"
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  record_execution "$display" "$artifact" "$started" "$completed" "$status"
  if [[ -n "$artifact" && -e "$artifact" ]]; then
    add_artifact "$artifact"
  fi
  return "$status"
}

run_logged_sensitive_capture() {
  run_logged_sensitive_capture_timed "$AEGISCOPE_COMMAND_TIMEOUT" "$@"
}

run_logged_sensitive_capture_timed() {
  local deadline="$1"
  shift
  local artifact="$1" started completed status display label
  shift
  local -a actual=("$@")
  display="$(sensitive_command_string "${actual[@]}")"
  label="$(command_label "${actual[@]}")"
  RUN_COMMANDS+=("$display")
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  progress_start "$label" "$deadline"
  execute_bounded "$deadline" "${actual[@]}" >"$artifact" 2>&1
  status=$?
  progress_stop
  report_timeout "$status" "$label" "$deadline"
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  record_execution "$display" "$artifact" "$started" "$completed" "$status"
  add_artifact "$artifact"
  return "$status"
}

write_manifest() {
  local exit_code="$1" status completed index tool first artifact relative size digest evidence_key manifest_tmp python
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
    for tool in bash timeout curl python3 jq sqlite3 nmap openssl ffuf gobuster subfinder sublist3r assetfinder dnsx naabu httpx katana nuclei testssl.sh testssl whatweb dig whois ping traceroute tracepath shodan hey k6; do
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
  python="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
  [[ -n "$python" ]] || die "Python 3 is required to validate the run manifest"
  if ! "$python" -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$manifest_tmp"; then
    rm -f -- "$manifest_tmp"
    die "generated manifest failed JSON validation"
  fi
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
