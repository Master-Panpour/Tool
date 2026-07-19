#!/usr/bin/env bash

# shellcheck source=plugins.sh
source "${AEGISCOPE_ROOT}/lib/plugins.sh"

workspace_python() {
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import sqlite3' >/dev/null 2>&1; then
    printf '%s' python3
  elif command -v python >/dev/null 2>&1 && python -c 'import sqlite3' >/dev/null 2>&1; then
    printf '%s' python
  else
    return 1
  fi
}

workspace_exec() {
  local python
  python="$(workspace_python)" || die "Python 3 is required for asset workspace operations"
  "$python" "${AEGISCOPE_ROOT}/lib/workspace.py" --db "$AEGISCOPE_ASSET_DB" "$@"
}

workspace_ingest_manifest() {
  local manifest="$1" python
  python="$(workspace_python)" || return 1
  "$python" "${AEGISCOPE_ROOT}/lib/workspace.py" --db "$AEGISCOPE_ASSET_DB" ingest --manifest "$manifest" >/dev/null
}

assets_usage() {
  cat <<'EOF'
Usage:
  aegiscope assets init
  aegiscope assets ingest [--manifest FILE]
  aegiscope assets list [--kind KIND|--port N|--technology NAME] [--match TEXT] [--json]
  aegiscope assets graph VALUE [--format text|dot]
  aegiscope assets diff [--baseline RUN_ID --current RUN_ID|--since 7d] [--json]
  aegiscope assets dashboard [--output FILE]
EOF
}

assets_command() {
  local action="${1:-list}" manifest="" output="${AEGISCOPE_WORKSPACE_ROOT}/dashboard.html" positional=0
  local -a forwarded=()
  [[ $# -eq 0 ]] || shift
  case "$action" in
    init)
      (($# == 0)) || die "unknown assets init option: $1"
      workspace_exec init
      ;;
    ingest)
      while (($#)); do
        case "$1" in
          --manifest)
            require_option_argument "$@"
            manifest="$2"
            shift 2
            ;;
          *) die "unknown assets ingest option: $1" ;;
        esac
      done
      if [[ -n "$manifest" ]]; then
        workspace_exec ingest --manifest "$manifest"
      else
        while IFS= read -r manifest; do workspace_exec ingest --manifest "$manifest"; done < <(find "$AEGISCOPE_RESULTS_ROOT" -name manifest.json -type f -print 2>/dev/null | sort)
      fi
      ;;
    list)
      forwarded=("$@")
      while (($#)); do
        case "$1" in
          --kind | --match | --port | --technology | --limit)
            require_option_argument "$@"
            shift 2
            ;;
          --json) shift ;;
          *) die "unknown assets list option: $1" ;;
        esac
      done
      workspace_exec assets "${forwarded[@]}"
      ;;
    graph)
      forwarded=("$@")
      while (($#)); do
        case "$1" in
          --asset | --format)
            require_option_argument "$@"
            shift 2
            ;;
          --*) die "unknown assets graph option: $1" ;;
          *)
            ((positional++)) || true
            ((positional <= 1)) || die "assets graph accepts only one positional asset"
            shift
            ;;
        esac
      done
      workspace_exec graph "${forwarded[@]}"
      ;;
    diff)
      forwarded=("$@")
      while (($#)); do
        case "$1" in
          --baseline | --current | --since)
            require_option_argument "$@"
            shift 2
            ;;
          --json) shift ;;
          *) die "unknown assets diff option: $1" ;;
        esac
      done
      workspace_exec diff "${forwarded[@]}"
      ;;
    dashboard)
      if [[ "${1:-}" == "--output" ]]; then
        require_option_argument "$@"
        output="$2"
        shift 2
      fi
      (($# == 0)) || die "unknown assets dashboard option: $1"
      workspace_exec dashboard --output "$output"
      ;;
    -h | --help)
      (($# == 0)) || die "unknown assets option: $1"
      assets_usage
      ;;
    *) die "unknown assets action: $action" ;;
  esac
}

auth_usage() {
  cat <<'EOF'
Usage:
  aegiscope auth add --name NAME --from-file HEADERS_FILE
  aegiscope auth list
  aegiscope auth show --name NAME
  aegiscope auth remove --name NAME

Header values are stored in a mode-0600 local profile and never printed by
the list/show commands. Prefer a protected input file over command arguments.
EOF
}

auth_profile_path() {
  local name="$1"
  [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || die "invalid auth profile name: $name"
  printf '%s/%s.headers' "$AEGISCOPE_AUTH_ROOT" "$name"
}

auth_load_headers() {
  local name="$1" destination_name="$2" path line
  local -n destination="$destination_name"
  path="$(auth_profile_path "$name")"
  [[ -f "$path" ]] || die "auth profile not found: $name"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    validate_header "$line"
    destination+=("$line")
  done <"$path"
}

auth_command() {
  local action="${1:-list}" name="" input="" path line
  [[ $# -eq 0 ]] || shift
  case "$action" in
    add)
      while (($#)); do
        case "$1" in
          --name)
            require_option_argument "$@"
            name="$2"
            shift 2
            ;;
          --from-file)
            require_option_argument "$@"
            input="$2"
            shift 2
            ;;
          *) die "unknown auth add option: $1" ;;
        esac
      done
      [[ -n "$name" && -f "$input" ]] || die "auth add requires --name and an existing --from-file"
      path="$(auth_profile_path "$name")"
      while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        validate_header "$line"
      done <"$input"
      mkdir -p "$AEGISCOPE_AUTH_ROOT"
      umask 077
      cp "$input" "$path"
      chmod 600 "$path" 2>/dev/null || true
      info "Stored auth profile: $name"
      ;;
    list)
      (($# == 0)) || die "unknown auth list option: $1"
      mkdir -p "$AEGISCOPE_AUTH_ROOT"
      for path in "$AEGISCOPE_AUTH_ROOT"/*.headers; do
        [[ -f "$path" ]] && basename "$path" .headers
      done
      ;;
    show)
      [[ "${1:-}" == "--name" && $# -eq 2 ]] || die "auth show requires exactly --name NAME"
      path="$(auth_profile_path "$2")"
      [[ -f "$path" ]] || die "auth profile not found: $2"
      while IFS= read -r line; do
        [[ "$line" == *:* ]] && printf '%s: [REDACTED]\n' "${line%%:*}"
      done <"$path"
      ;;
    remove)
      [[ "${1:-}" == "--name" && $# -eq 2 ]] || die "auth remove requires exactly --name NAME"
      path="$(auth_profile_path "$2")"
      [[ -f "$path" ]] || die "auth profile not found: $2"
      rm -f -- "$path"
      info "Removed auth profile: $2"
      ;;
    -h | --help)
      (($# == 0)) || die "unknown auth option: $1"
      auth_usage
      ;;
    *) die "unknown auth action: $action" ;;
  esac
}

pipeline_usage() {
  cat <<EOF
Usage: aegiscope pipeline --target DOMAIN|URL [options]

Options:
  --phase passive|verify|active|all  Default: all
  --resume RUN_DIRECTORY            Continue incomplete checkpoints
  --cache-ttl SECONDS               Default: 86400; 0 disables cache
  --auth-profile NAME               Protected header profile
  --provider-rate-limits SPEC       Subfinder provider=rate/s limits
  --request-rate N                  Global ceiling passed to integrations
  --scope-file FILE
  --authorized

Pipeline: Subfinder -> dnsx -> Naabu -> Nmap -> httpx -> Katana
EOF
}

cache_file_fresh() {
  local path="$1" ttl="$2" modified now
  [[ -f "$path" && "$ttl" =~ ^[0-9]+$ && "$ttl" -gt 0 ]] || return 1
  modified="$(stat -c %Y "$path" 2>/dev/null || stat -f %m "$path" 2>/dev/null || printf 0)"
  now="$(date +%s)"
  ((now - modified <= ttl))
}

pipeline_mark() {
  local state_dir="$1" step="$2" status="$3" source="${4:-execution}" old stamp checkpoint_tmp
  stamp="$(date -u +%Y%m%dT%H%M%SZ)_${RANDOM}"
  mkdir -p "${state_dir}/history"
  for old in "${state_dir}/${step}.completed.json" "${state_dir}/${step}.failed.json" "${state_dir}/${step}.skipped.json"; do
    [[ -f "$old" ]] || continue
    mv "$old" "${state_dir}/history/$(basename "${old%.json}").${stamp}.json"
  done
  checkpoint_tmp="${state_dir}/.${step}.${status}.${BASHPID:-$$}.${RANDOM}.tmp"
  printf '{"step":"%s","status":"%s","source":"%s","at":"%s"}\n' "$step" "$status" "$source" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$checkpoint_tmp"
  mv "$checkpoint_tmp" "${state_dir}/${step}.${status}.json"
}

pipeline_run_tool() {
  local step="$1" tool="$2" artifact="$3" state_dir="$4" cache_dir="$5" cache_ttl="$6" cache_tmp tool_status=0
  shift 6
  if [[ -f "${state_dir}/${step}.completed.json" && -e "$artifact" ]]; then
    info "Checkpoint: $step already completed"
    add_artifact "$artifact"
    return 0
  fi
  if cache_file_fresh "${cache_dir}/${step}.cache" "$cache_ttl"; then
    cp "${cache_dir}/${step}.cache" "$artifact"
    add_artifact "$artifact"
    pipeline_mark "$state_dir" "$step" completed cache
    info "Cache hit: $step"
    return 0
  fi
  if ! command -v "$tool" >/dev/null 2>&1; then
    warn "$tool is not installed; required pipeline step $step was skipped"
    pipeline_mark "$state_dir" "$step" skipped dependency-missing
    return 127
  fi
  info "Pipeline step: $step"
  if [[ "$tool" == naabu ]]; then
    run_logged_timed "$AEGISCOPE_NAABU_TIMEOUT" "$artifact" "$@" || tool_status=$?
  else
    run_logged "$artifact" "$@" || tool_status=$?
  fi
  if ((tool_status == 0)); then
    pipeline_mark "$state_dir" "$step" completed execution
    if [[ -f "$artifact" && "$cache_ttl" -gt 0 ]]; then
      mkdir -p "$cache_dir"
      cache_tmp="${cache_dir}/.${step}.${BASHPID:-$$}.${RANDOM}.tmp"
      if cp "$artifact" "$cache_tmp"; then
        mv "$cache_tmp" "${cache_dir}/${step}.cache" || warn "unable to publish cache entry for $step"
      else
        warn "unable to stage cache entry for $step"
      fi
    fi
    return 0
  fi
  pipeline_mark "$state_dir" "$step" failed execution
  warn "Pipeline step $step ($tool) failed with exit code $tool_status"
  return 1
}

extract_jsonl_field() {
  local input="$1" output="$2" expression="$3"
  if command -v jq >/dev/null 2>&1; then
    jq -r "$expression // empty" "$input" 2>/dev/null | sort -u >"$output"
  else
    sed -nE 's/.*"(host|input|url)":"([^"]+)".*/\2/p' "$input" | sort -u >"$output"
  fi
}

filter_scoped_hosts() {
  local input="$1" output="$2" host
  : >"$output"
  while IFS= read -r host; do
    [[ -n "$host" ]] || continue
    host="$(normalize_scope_target "$host")"
    scope_allows "$host" && printf '%s\n' "$host" >>"$output"
  done <"$input"
  sort -u "$output" -o "$output"
}

pipeline_command() {
  local target="" phase=all resume="" cache_ttl=86400 request_rate="$AEGISCOPE_MAX_RATE" authorized=0 auth_profile="" provider_rate_limits="" host safe_target state_dir cache_dir status=0 ports=""
  local pipeline_dir subfinder_json subfinder_hosts hosts scoped_hosts dnsx_json resolved_hosts naabu_json nmap_prefix httpx_json urls katana_json plan policy header planned_target python resume_stamp
  local -a headers=() cmd=()
  while (($#)); do
    case "$1" in
      --target)
        require_option_argument "$@"
        target="$2"
        shift 2
        ;;
      --phase)
        require_option_argument "$@"
        phase="${2,,}"
        shift 2
        ;;
      --resume)
        require_option_argument "$@"
        resume="$2"
        shift 2
        ;;
      --cache-ttl)
        require_option_argument "$@"
        cache_ttl="$2"
        shift 2
        ;;
      --auth-profile)
        require_option_argument "$@"
        auth_profile="$2"
        shift 2
        ;;
      --provider-rate-limits)
        require_option_argument "$@"
        provider_rate_limits="$2"
        shift 2
        ;;
      --request-rate | --rate)
        require_option_argument "$@"
        request_rate="$2"
        shift 2
        ;;
      --scope-file)
        require_option_argument "$@"
        AEGISCOPE_SCOPE_FILE="$2"
        shift 2
        ;;
      --authorized)
        authorized=1
        shift
        ;;
      -h | --help)
        (($# == 1)) || die "unknown pipeline option: $2"
        pipeline_usage
        return 0
        ;;
      *) die "unknown pipeline option: $1" ;;
    esac
  done
  [[ -n "$target" ]] || die "pipeline requires --target, including when resuming"
  case "$phase" in passive | verify | active | all) ;; *) die "unknown pipeline phase: $phase" ;; esac
  [[ "$cache_ttl" =~ ^[0-9]+$ ]] || die "cache TTL must be a non-negative integer"
  [[ -z "$provider_rate_limits" || "$provider_rate_limits" =~ ^[A-Za-z0-9_.-]+=[0-9]+(/[smh])?(,[A-Za-z0-9_.-]+=[0-9]+(/[smh])?)*$ ]] || die "invalid per-provider rate-limit specification"
  validate_rate "$request_rate"
  authorize_target "$target" "$authorized"
  [[ -z "$auth_profile" ]] || auth_load_headers "$auth_profile" headers
  host="$(normalize_scope_target "$target")"
  safe_target="$(sanitize_name "$host")"
  if [[ -n "$resume" ]]; then
    [[ -d "$resume" && -f "$resume/pipeline-plan.json" ]] || die "resume directory is not a pipeline run: $resume"
    python="$(workspace_python)" || die "Python 3 is required to validate pipeline resume metadata"
    planned_target="$("$python" -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("target", ""))' "$resume/pipeline-plan.json")" || die "unable to read pipeline resume metadata"
    [[ "$(normalize_scope_target "$planned_target")" == "$host" ]] || die "resume target does not match the original pipeline target"
    resume_stamp="$(date -u +%Y%m%dT%H%M%SZ)_${RANDOM}"
    mkdir -p "${resume}/history"
    [[ ! -f "${resume}/manifest.json" ]] || cp "${resume}/manifest.json" "${resume}/history/manifest-${resume_stamp}.json"
    cp "${resume}/pipeline-plan.json" "${resume}/history/pipeline-plan-${resume_stamp}.json"
    # Shared run globals are consumed by core manifest/logging functions.
    # shellcheck disable=SC2034
    RUN_DIR="$(cd "$resume" && pwd)"
    # shellcheck disable=SC2034
    RUN_TARGET="$target"
    # shellcheck disable=SC2034
    RUN_SCOPE_KEY="$host"
    # shellcheck disable=SC2034
    RUN_OPERATION="pipeline-${phase}-resume"
    # shellcheck disable=SC2034
    RUN_STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    # shellcheck disable=SC2034
    RUN_COMMANDS=()
    # shellcheck disable=SC2034
    RUN_ARTIFACTS=()
    # shellcheck disable=SC2034
    RUN_EXECUTION_COMMANDS=()
    # shellcheck disable=SC2034
    RUN_EXECUTION_ARTIFACTS=()
    # shellcheck disable=SC2034
    RUN_EXECUTION_STARTED=()
    # shellcheck disable=SC2034
    RUN_EXECUTION_COMPLETED=()
    # shellcheck disable=SC2034
    RUN_EXECUTION_EXIT_CODES=()
    info "Resuming run directory: $RUN_DIR"
  else
    create_run "$target" "pipeline-${phase}"
  fi
  pipeline_dir="${RUN_DIR}/pipeline"
  state_dir="${RUN_DIR}/.state"
  cache_dir="${AEGISCOPE_CACHE_ROOT}/${safe_target}/$(sanitize_name "${auth_profile:-anonymous}")"
  mkdir -p "$pipeline_dir" "$state_dir" "$cache_dir"
  subfinder_json="${pipeline_dir}/subfinder.jsonl"
  subfinder_hosts="${pipeline_dir}/subfinder-hosts.txt"
  hosts="${pipeline_dir}/hosts.txt"
  scoped_hosts="${pipeline_dir}/scoped-hosts.txt"
  dnsx_json="${pipeline_dir}/dnsx.jsonl"
  resolved_hosts="${pipeline_dir}/resolved-hosts.txt"
  naabu_json="${pipeline_dir}/naabu.jsonl"
  nmap_prefix="${pipeline_dir}/nmap"
  httpx_json="${pipeline_dir}/httpx.jsonl"
  urls="${pipeline_dir}/urls.txt"
  katana_json="${pipeline_dir}/katana.jsonl"
  if [[ -n "$resume" ]]; then
    plan="${RUN_DIR}/pipeline-resume-plan-${resume_stamp}.json"
    policy="${RUN_DIR}/pipeline-resume-policy-${resume_stamp}.json"
  else
    plan="${RUN_DIR}/pipeline-plan.json"
    policy="${RUN_DIR}/pipeline-policy.json"
  fi
  printf '{"target":"%s","phase":"%s","request_rate":%d,"cache_ttl":%d,"auth_profile":"%s","provider_rate_limits":"%s"}\n' "$(json_escape "$target")" "$phase" "$request_rate" "$cache_ttl" "$(json_escape "$auth_profile")" "$(json_escape "$provider_rate_limits")" >"$plan"
  printf '%s\n' '{"passive":{"tools":["subfinder"],"network_contact":"third-party sources","state_change":false,"cost":1},"verify":{"tools":["dnsx","httpx"],"network_contact":"target verification","state_change":false,"cost":2},"active":{"tools":["naabu","nmap","katana"],"network_contact":"direct active probing","state_change":false,"cost":3},"scheduler":{"mode":"global-rate-ceiling","parallel_stages":false}}' >"$policy"
  add_artifact "$plan"
  add_artifact "$policy"
  printf '%s\n' "$host" >"$hosts"

  if [[ "$phase" == passive || "$phase" == all ]]; then
    cmd=(subfinder -d "$host" -silent -oJ -cs -rl "$request_rate" -disable-update-check -no-color -o "$subfinder_json")
    [[ -z "$provider_rate_limits" ]] || cmd+=(-rls "$provider_rate_limits")
    pipeline_run_tool subfinder subfinder "$subfinder_json" "$state_dir" "$cache_dir" "$cache_ttl" "${cmd[@]}" || status=$?
    : >"$subfinder_hosts"
    [[ ! -s "$subfinder_json" ]] || extract_jsonl_field "$subfinder_json" "$subfinder_hosts" '.host // .input'
    record_subfinder_coverage "$subfinder_hosts" "${pipeline_dir}/subfinder-coverage.json"
    cp "$subfinder_hosts" "$hosts"
    add_artifact "$subfinder_hosts"
    printf '%s\n' "$host" >>"$hosts"
    sort -u "$hosts" -o "$hosts"
  fi
  filter_scoped_hosts "$hosts" "$scoped_hosts"
  add_artifact "$hosts"
  add_artifact "$scoped_hosts"

  if [[ "$phase" == verify || "$phase" == active || "$phase" == all ]]; then
    pipeline_run_tool dnsx dnsx "$dnsx_json" "$state_dir" "$cache_dir" "$cache_ttl" \
      dnsx -l "$scoped_hosts" -a -aaaa -cname -json -rl "$request_rate" -disable-update-check -no-color -no-stdin -o "$dnsx_json" || status=$?
    if [[ -s "$dnsx_json" ]]; then
      extract_jsonl_field "$dnsx_json" "$resolved_hosts" '.host // .input'
      filter_scoped_hosts "$resolved_hosts" "${resolved_hosts}.scoped"
      mv "${resolved_hosts}.scoped" "$resolved_hosts"
    else
      cp "$scoped_hosts" "$resolved_hosts"
    fi
    add_artifact "$resolved_hosts"
  else
    cp "$scoped_hosts" "$resolved_hosts"
  fi

  if [[ "$phase" == active || "$phase" == all ]]; then
    pipeline_run_tool naabu naabu "$naabu_json" "$state_dir" "$cache_dir" "$cache_ttl" \
      naabu -list "$resolved_hosts" -silent -json -top-ports 1000 -rate "$request_rate" -timeout 3000 -disable-update-check -no-color -no-stdin -o "$naabu_json" || status=$?
    if [[ -s "$naabu_json" && -x "$(command -v jq 2>/dev/null || true)" ]]; then
      ports="$(jq -r '.port // empty' "$naabu_json" 2>/dev/null | sort -nu | paste -sd, -)"
    fi
    cmd=(nmap -sT -sV --max-rate "$request_rate")
    [[ -z "$ports" ]] && cmd+=(--top-ports 1000) || cmd+=(-p "$ports")
    cmd+=(-oA "$nmap_prefix" -iL "$resolved_hosts")
    pipeline_run_tool nmap nmap "${nmap_prefix}.xml" "$state_dir" "$cache_dir" "$cache_ttl" "${cmd[@]}" || status=$?
  fi

  if [[ "$phase" == verify || "$phase" == active || "$phase" == all ]]; then
    prepare_httpx_command cmd -l "$resolved_hosts" -silent -json -status-code -title -tech-detect -web-server -ip -cname -asn -cdn -rl "$request_rate" -o "$httpx_json"
    for header in "${headers[@]}"; do cmd+=(-H "$header"); done
    pipeline_run_tool httpx httpx "$httpx_json" "$state_dir" "$cache_dir" "$cache_ttl" "${cmd[@]}" || status=$?
    if [[ -s "$httpx_json" ]]; then
      extract_jsonl_field "$httpx_json" "$urls" '.url'
    else
      sed 's#^#https://#' "$resolved_hosts" >"$urls"
    fi
    add_artifact "$urls"
  fi

  if [[ "$phase" == active || "$phase" == all ]]; then
    cmd=(katana -list "$urls" -silent -jsonl -depth 3 -js-crawl -known-files all -crawl-duration 2m -fs fqdn -rate-limit "$request_rate" -disable-update-check -no-color -o "$katana_json")
    for header in "${headers[@]}"; do cmd+=(-H "$header"); done
    pipeline_run_tool katana katana "$katana_json" "$state_dir" "$cache_dir" "$cache_ttl" "${cmd[@]}" || status=$?
  fi
  collect_new_artifacts
  write_manifest "$status"
  return "$status"
}

resume_command() {
  local run_dir="${1:-}"
  [[ -n "$run_dir" ]] || die "resume requires a pipeline run directory"
  shift
  pipeline_command --resume "$run_dir" "$@"
}

retry_command() {
  local run_dir="${1:-}"
  [[ -n "$run_dir" ]] || die "retry requires a pipeline run directory"
  shift
  if [[ "${1:-}" == "--failed-only" ]]; then shift; fi
  # A missing completion checkpoint is the retry contract. Bypass cached output
  # so the failed/incomplete tool is actually executed again.
  pipeline_command --resume "$run_dir" "$@" --cache-ttl 0
}

validate_usage() {
  cat <<'EOF'
Usage: aegiscope validate --target URL|HOST [options]

Options:
  --severity LIST          Default: medium,high,critical
  --tags LIST              Optional template tags
  --auth-profile NAME     Protected header profile
  --templates PATH        Pin to a reviewed template file/directory
  --template-sha256 HEX   Require an exact template content fingerprint
  --include-intrusive     Explicitly allow fuzz/headless templates; DoS/code stay excluded
  --request-rate N
  --scope-file FILE
  --authorized

Unsigned or signature-mismatched templates are always disabled.
EOF
}

validate_command() {
  local target="" severity="medium,high,critical" tags="" auth_profile="" templates="" expected_digest="" template_digest="installed-default" request_rate="$AEGISCOPE_MAX_RATE" authorized=0 intrusive=0 status=0 output header policy evidence_dir finding_count=0
  local -a headers=() cmd
  while (($#)); do
    case "$1" in
      --target)
        require_option_argument "$@"
        target="$2"
        shift 2
        ;;
      --severity)
        require_option_argument "$@"
        severity="$2"
        shift 2
        ;;
      --tags)
        require_option_argument "$@"
        tags="$2"
        shift 2
        ;;
      --auth-profile)
        require_option_argument "$@"
        auth_profile="$2"
        shift 2
        ;;
      --templates)
        require_option_argument "$@"
        templates="$2"
        shift 2
        ;;
      --template-sha256)
        require_option_argument "$@"
        expected_digest="${2,,}"
        shift 2
        ;;
      --include-intrusive)
        intrusive=1
        shift
        ;;
      --request-rate | --rate)
        require_option_argument "$@"
        request_rate="$2"
        shift 2
        ;;
      --scope-file)
        require_option_argument "$@"
        AEGISCOPE_SCOPE_FILE="$2"
        shift 2
        ;;
      --authorized)
        authorized=1
        shift
        ;;
      -h | --help)
        (($# == 1)) || die "unknown validate option: $2"
        validate_usage
        return 0
        ;;
      *) die "unknown validate option: $1" ;;
    esac
  done
  [[ -n "$target" ]] || die "validate requires --target"
  [[ "$severity" =~ ^[A-Za-z]+(,[A-Za-z]+)*$ ]] || die "severity must be a comma-separated list of names"
  [[ -z "$tags" || "$tags" =~ ^[A-Za-z0-9_.-]+(,[A-Za-z0-9_.-]+)*$ ]] || die "tags must be a comma-separated list of names"
  [[ -z "$expected_digest" || "$expected_digest" =~ ^[a-f0-9]{64}$ ]] || die "template SHA-256 must contain exactly 64 hexadecimal characters"
  validate_rate "$request_rate"
  authorize_target "$target" "$authorized"
  require_cmd nuclei
  [[ -z "$auth_profile" ]] || auth_load_headers "$auth_profile" headers
  if [[ -n "$templates" ]]; then
    [[ -e "$templates" ]] || die "Nuclei template path not found: $templates"
    template_digest="$(workspace_exec fingerprint --path "$templates")"
    if [[ -n "$expected_digest" && "$template_digest" != "$expected_digest" ]]; then
      die "Nuclei template fingerprint mismatch"
    fi
  fi
  create_run "$target" nuclei-validate
  output="${RUN_DIR}/nuclei.jsonl"
  evidence_dir="${RUN_DIR}/nuclei-evidence"
  policy="${RUN_DIR}/nuclei-policy.json"
  run_logged_capture_timed "$AEGISCOPE_VERSION_TIMEOUT" "${RUN_DIR}/nuclei-template-version.txt" nuclei -templates-version -disable-update-check -no-color || true
  add_artifact "${RUN_DIR}/nuclei-template-version.txt"
  cmd=(nuclei -u "$target" -silent -jsonl -o "$output" -severity "$severity" -rl "$request_rate" -timeout 10 -hang-monitor -stats -stats-interval "$AEGISCOPE_PROGRESS_INTERVAL" -no-color -no-stdin -disable-unsigned-templates -disable-update-check -disable-redirects -no-interactsh -store-resp -store-resp-dir "$evidence_dir")
  [[ -z "$templates" ]] || cmd+=(-templates "$templates")
  [[ -z "$tags" ]] || cmd+=(-tags "$tags")
  if ((intrusive == 1)); then
    cmd+=(-exclude-tags "dos,code")
  else
    cmd+=(-exclude-tags "dos,code,fuzz,headless")
  fi
  for header in "${headers[@]}"; do cmd+=(-H "$header"); done
  printf '{"severity":"%s","tags":"%s","unsigned_templates":"disabled","update_check":"disabled","intrusive":%s,"excluded":"%s","template_path":"%s","template_sha256":"%s"}\n' \
    "$(json_escape "$severity")" "$(json_escape "$tags")" "$([[ "$intrusive" == 1 ]] && printf true || printf false)" "$([[ "$intrusive" == 1 ]] && printf 'dos,code' || printf 'dos,code,fuzz,headless')" "$(json_escape "$templates")" "$template_digest" >"$policy"
  add_artifact "$policy"
  run_logged_sensitive_timed "$AEGISCOPE_NUCLEI_TIMEOUT" "$output" "${cmd[@]}" || status=$?
  [[ ! -f "$output" ]] || finding_count="$(wc -l <"$output" | tr -d '[:space:]')"
  [[ "$finding_count" =~ ^[0-9]+$ ]] || finding_count=0
  printf '{"findings":%d,"exit_code":%d,"empty_success":%s}\n' "$finding_count" "$status" "$([[ "$status" == 0 && "$finding_count" == 0 ]] && printf true || printf false)" >"${RUN_DIR}/nuclei-coverage.json"
  add_artifact "${RUN_DIR}/nuclei-coverage.json"
  if ((status != 0)); then
    warn "Nuclei validation failed with exit code $status; review the execution record and template evidence"
  elif ((finding_count == 0)); then
    warn "Nuclei completed successfully but produced no findings; verify template and target coverage"
  fi
  collect_new_artifacts
  write_manifest "$status"
  return "$status"
}

api_usage() {
  cat <<'EOF'
Usage: aegiscope api --target URL [options]

Options:
  --spec FILE              Parse an OpenAPI/Swagger JSON or YAML document
  --import FILE            Import OpenAPI, Postman JSON, or Burp XML
  --format auto|openapi|postman|burp
  --discover               Probe common specification locations
  --graphql                Send a harmless __typename GraphQL capability probe
  --cors                   Capture advertised methods and CORS response headers
  --auth-profile NAME      Protected header profile
  --request-rate N
  --scope-file FILE
  --authorized
EOF
}

api_command() {
  local target="" spec="" input_format=auto discover=0 graphql=0 cors=0 auth_profile="" request_rate="$AEGISCOPE_MAX_RATE" authorized=0 status=0 base_url candidate output inventory header cors_headers cors_report spec_suffix python allow_origin allow_credentials cors_assessment probe_origin="https://aegiscope.invalid"
  local -a headers=() cmd candidates=(openapi.json swagger.json api/openapi.json api/swagger.json v3/api-docs .well-known/openapi.json)
  while (($#)); do
    case "$1" in
      --target)
        require_option_argument "$@"
        target="$2"
        shift 2
        ;;
      --spec)
        require_option_argument "$@"
        spec="$2"
        shift 2
        ;;
      --import)
        require_option_argument "$@"
        spec="$2"
        shift 2
        ;;
      --format)
        require_option_argument "$@"
        input_format="${2,,}"
        shift 2
        ;;
      --discover)
        discover=1
        shift
        ;;
      --graphql)
        graphql=1
        shift
        ;;
      --cors)
        cors=1
        shift
        ;;
      --auth-profile)
        require_option_argument "$@"
        auth_profile="$2"
        shift 2
        ;;
      --request-rate | --rate)
        require_option_argument "$@"
        request_rate="$2"
        shift 2
        ;;
      --scope-file)
        require_option_argument "$@"
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
        (($# == 1)) || die "unknown api option: $2"
        api_usage
        return 0
        ;;
      *) die "unknown api option: $1" ;;
    esac
  done
  [[ -n "$target" && "$target" =~ ^https?:// ]] || die "api requires an HTTP(S) --target"
  case "$input_format" in auto | openapi | postman | burp) ;; *) die "unsupported API input format: $input_format" ;; esac
  validate_rate "$request_rate"
  authorize_target "$target" "$authorized"
  [[ -z "$auth_profile" ]] || auth_load_headers "$auth_profile" headers
  [[ -z "$spec" || -f "$spec" ]] || die "API specification not found: $spec"
  create_run "$target" api-recon
  base_url="${target%/}"
  if [[ -n "$spec" ]]; then
    spec_suffix="${spec##*.}"
    [[ "$spec_suffix" != "$spec" && "$spec_suffix" =~ ^[A-Za-z0-9]+$ ]] || spec_suffix="data"
    cp "$spec" "${RUN_DIR}/api-spec.${spec_suffix,,}"
    spec="${RUN_DIR}/api-spec.${spec_suffix,,}"
    add_artifact "$spec"
  elif ((discover == 1)); then
    require_cmd curl
    python="$(workspace_python)" || die "Python 3 is required for API specification discovery"
    for candidate in "${candidates[@]}"; do
      output="${RUN_DIR}/candidate-$(sanitize_name "$candidate").json"
      cmd=(curl --silent --show-error --connect-timeout 10 --max-time 30 --output "$output")
      for header in "${headers[@]}"; do cmd+=(-H "$header"); done
      cmd+=(--url "${base_url}/${candidate}")
      run_logged_sensitive "" "${cmd[@]}" || true
      if "$python" -c 'import json,sys; value=json.load(open(sys.argv[1], encoding="utf-8")); raise SystemExit(0 if isinstance(value,dict) and any(key in value for key in ("openapi","swagger","paths","item")) else 1)' "$output" >/dev/null 2>&1; then
        spec="$output"
        add_artifact "$output"
        break
      fi
    done
  fi
  inventory="${RUN_DIR}/api-inventory.json"
  if [[ -n "$spec" ]]; then
    workspace_exec api-parse --input "$spec" --output "$inventory" --base-url "$base_url" --format "$input_format" || status=$?
    [[ ! -f "$inventory" ]] || add_artifact "$inventory"
  else
    printf '{"title":"Unspecified API","format":"discovery","security_schemes":[],"endpoints":[]}\n' >"$inventory"
    add_artifact "$inventory"
  fi
  if ((graphql == 1)); then
    require_cmd curl
    cmd=(curl --silent --show-error --connect-timeout 10 --max-time 30 --output "${RUN_DIR}/graphql-probe.json" -H 'Content-Type: application/json')
    for header in "${headers[@]}"; do cmd+=(-H "$header"); done
    cmd+=(--data-raw '{"query":"query AegiscopeProbe { __typename }"}' --url "${base_url}/graphql")
    run_logged_sensitive "${RUN_DIR}/graphql-probe.json" "${cmd[@]}" || status=$?
  fi
  if ((cors == 1)); then
    require_cmd curl
    cors_headers="${RUN_DIR}/api-options.headers"
    cors_report="${RUN_DIR}/api-cors-analysis.txt"
    cmd=(curl --silent --show-error --connect-timeout 10 --max-time 30 --request OPTIONS --dump-header "$cors_headers" --output /dev/null -H "Origin: ${probe_origin}" -H 'Access-Control-Request-Method: GET')
    for header in "${headers[@]}"; do cmd+=(-H "$header"); done
    cmd+=(--url "$base_url")
    run_logged_sensitive "" "${cmd[@]}" || status=$?
    allow_origin="$(header_value Access-Control-Allow-Origin "$cors_headers")"
    allow_credentials="$(header_value Access-Control-Allow-Credentials "$cors_headers")"
    cors_assessment="no credentialed origin-reflection indicator observed"
    if [[ "$allow_origin" == "$probe_origin" && "${allow_credentials,,}" == true ]]; then
      cors_assessment="review: arbitrary probe origin was reflected with credentials advertised"
    elif [[ "$allow_origin" == "*" && "${allow_credentials,,}" == true ]]; then
      cors_assessment="review: wildcard origin and credentials were both advertised (browser enforcement and application behavior require validation)"
    fi
    {
      printf 'advertised_methods=%s\n' "$(header_value Allow "$cors_headers")"
      printf 'probe_origin=%s\n' "$probe_origin"
      printf 'allow_origin=%s\n' "$allow_origin"
      printf 'allow_credentials=%s\n' "$allow_credentials"
      printf 'allow_headers=%s\n' "$(header_value Access-Control-Allow-Headers "$cors_headers")"
      printf 'allow_methods=%s\n' "$(header_value Access-Control-Allow-Methods "$cors_headers")"
      printf 'assessment=%s\n' "$cors_assessment"
    } >"$cors_report"
    add_artifact "$cors_headers"
    add_artifact "$cors_report"
  fi
  collect_new_artifacts
  write_manifest "$status"
  return "$status"
}
