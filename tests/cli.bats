#!/usr/bin/env bats

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_workspace
}

teardown() {
  teardown_workspace
}

@test "help exposes the non-interactive commands" {
  run "$PROJECT_ROOT/bin/aegiscope" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"aegiscope recon"* ]]
  [[ "$output" == *"aegiscope report"* ]]
  [[ "$output" == *"aegiscope ddos"* ]]
}

@test "out-of-scope targets are rejected before a tool runs" {
  run "$PROJECT_ROOT/bin/aegiscope" ports --target 192.0.2.10 --profile quick-tcp --authorized
  [ "$status" -eq 1 ]
  [[ "$output" == *"not allowed by scope file"* ]]
}

@test "quick-tcp uses normal host discovery" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target 127.0.0.1 --profile quick-tcp --request-rate 25 --authorized
  [ "$status" -eq 0 ]
  grep -Fx -- '--top-ports' "$MOCK_LOG"
  grep -Fx -- '1000' "$MOCK_LOG"
  grep -Fx -- '--max-rate' "$MOCK_LOG"
  ! grep -Fx -- '-Pn' "$MOCK_LOG"
  manifest="$(find "$AEGISCOPE_RESULTS_ROOT" -name manifest.json -print -quit)"
  grep -q '"status": "completed"' "$manifest"
  grep -q '"commands": \["nmap ' "$manifest"
  python - "$manifest" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["schema_version"] == "2.0"
assert data["authorization"]["assertion"] == "explicit-cli-assertion"
assert data["executions"][0]["exit_code"] == 0
assert data["executions"][0]["started_at"]
assert any(item["path"] == "scope-snapshot.txt" and len(item["sha256"]) == 64 for item in data["evidence"])
PY
}

@test "skip-host-discovery explicitly adds Pn" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --profile firewall-map --skip-host-discovery --authorized
  [ "$status" -eq 0 ]
  grep -Fx -- '-sA' "$MOCK_LOG"
  grep -Fx -- '-Pn' "$MOCK_LOG"
  ! grep -Fx -- '-sV' "$MOCK_LOG"
}

@test "request rate cannot exceed the configured ceiling" {
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --request-rate 101 --authorized
  [ "$status" -eq 1 ]
  [[ "$output" == *"exceeds the configured ceiling"* ]]
}

@test "ffuf receives calibration rate time recursion headers and output controls" {
  mock_ffuf
  run "$PROJECT_ROOT/bin/aegiscope" web --target https://localhost --mode dir --request-rate 20 --max-time 90 --recursion-depth 1 --output-format csv --header 'Authorization: Bearer test' --authorized
  [ "$status" -eq 0 ]
  grep -Fx -- '-ac' "$MOCK_LOG"
  grep -Fx -- '-rate' "$MOCK_LOG"
  grep -Fx -- '20' "$MOCK_LOG"
  grep -Fx -- '-maxtime' "$MOCK_LOG"
  grep -Fx -- '-recursion-depth' "$MOCK_LOG"
  grep -Fx -- 'csv' "$MOCK_LOG"
  manifest="$(find "$AEGISCOPE_RESULTS_ROOT" -name manifest.json -print -quit)"
  grep -q 'Authorization:' "$manifest"
  grep -q 'REDACTED' "$manifest"
  ! grep -q 'Bearer test' "$manifest"
}

@test "VHost mode uses Gobuster append-domain and rate delay" {
  mock_gobuster
  run "$PROJECT_ROOT/bin/aegiscope" web --target https://localhost --mode vhost --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  grep -Fx -- 'vhost' "$MOCK_LOG"
  grep -Fx -- '--append-domain' "$MOCK_LOG"
  grep -Fx -- '--delay' "$MOCK_LOG"
  grep -Fx -- '100ms' "$MOCK_LOG"
}

@test "wildcard scope permits a matching subdomain" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target app.lab.example.com --profile quick-tcp --authorized
  [ "$status" -eq 0 ]
}

@test "Subfinder results feed structured httpx enrichment" {
  mock_subfinder_pipeline
  run "$PROJECT_ROOT/bin/aegiscope" web --target lab.example.com --mode subdomains --request-rate 15 --provider-rate-limits 'crtsh=2/s' --authorized
  [ "$status" -eq 0 ]
  grep -q 'subfinder:.*-oJ.*-cs' "$MOCK_LOG"
  grep -q 'subfinder:.*-rls crtsh=2/s' "$MOCK_LOG"
  grep -q 'httpx:.*-rl 15.*-tech-detect.*-json' "$MOCK_LOG"
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*web-subdomains' -print -quit)"
  [ -s "$run_dir/subdomains.jsonl" ]
  [ -s "$run_dir/subdomains.txt" ]
  grep -Fx 'outside.example.net' "$run_dir/subdomains.txt"
  ! grep -Fx 'outside.example.net' "$run_dir/subdomains-scoped.txt"
  grep -Fx 'app.lab.example.com' "$run_dir/subdomains-scoped.txt"
  [ -s "$run_dir/httpx.jsonl" ]
}

@test "HTTP mode produces redirect cookie security-header and advertised-method analysis" {
  mock_curl
  run "$PROJECT_ROOT/bin/aegiscope" web --target https://localhost --mode http --authorized
  [ "$status" -eq 0 ]
  analysis="$(find "$AEGISCOPE_RESULTS_ROOT" -name http-analysis.txt -print -quit)"
  grep -q 'redirects_followed=0' "$analysis"
  grep -q 'not automatically followed across scope boundaries' "$analysis"
  grep -q 'session=test' "$analysis"
  grep -q 'Strict-Transport-Security: present' "$analysis"
  grep -q 'Content-Security-Policy: missing' "$analysis"
  grep -q 'GET, HEAD, OPTIONS' "$analysis"
  ! grep -q 'curl:.*--location' "$MOCK_LOG"
}

@test "HTTP analysis uses protected authentication headers and redacts its manifest" {
  mock_curl
  printf 'Authorization: Bearer http-secret\n' >"${TEST_WORK}/http-headers.txt"
  run "$PROJECT_ROOT/bin/aegiscope" auth add --name webapp --from-file "${TEST_WORK}/http-headers.txt"
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/bin/aegiscope" web --target https://localhost --mode http --auth-profile webapp --authorized
  [ "$status" -eq 0 ]
  grep -q 'curl:.*-H Authorization: Bearer http-secret' "$MOCK_LOG"
  manifest="$(find "$AEGISCOPE_RESULTS_ROOT" -name manifest.json -print -quit)"
  grep -q 'Authorization:.*REDACTED' "$manifest"
  ! grep -q 'http-secret' "$manifest"
}

@test "HTTP headers with control characters are rejected before execution" {
  mock_curl
  run "$PROJECT_ROOT/bin/aegiscope" web --target https://localhost --mode http --header $'X-Test: safe\rInjected: no' --authorized
  [ "$status" -eq 1 ]
  [[ "$output" == *"control character"* ]]
  [ ! -s "$MOCK_LOG" ]
}

@test "TLS mode prefers testssl and preserves JSON and HTML artifacts" {
  mock_testssl
  run "$PROJECT_ROOT/bin/aegiscope" web --target https://localhost --mode tls --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*web-tls' -print -quit)"
  [ -s "$run_dir/testssl.json" ]
  [ -s "$run_dir/testssl.html" ]
  grep -q 'testssl:.*localhost:443' "$MOCK_LOG"
}

@test "OWASP all-stage recon creates ordered evidence directories" {
  mock_curl
  mock_httpx_capture
  run "$PROJECT_ROOT/bin/aegiscope" recon --target https://localhost --stage all --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*recon-all' -print -quit)"
  [ -d "$run_dir/01-server-fingerprint" ]
  [ -d "$run_dir/02-metafiles" ]
  [ -d "$run_dir/03-applications" ]
  [ -d "$run_dir/04-entry-points" ]
  [ -d "$run_dir/05-execution-paths" ]
  [ -d "$run_dir/06-architecture" ]
  grep -q '"operation": "recon-all"' "$run_dir/manifest.json"
}

@test "automated recon propagates a failed required stage" {
  mock_httpx_failure
  run "$PROJECT_ROOT/bin/aegiscope" recon --target https://localhost --stage applications --request-rate 10 --authorized
  [ "$status" -eq 4 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*recon-applications' -print -quit)"
  grep -q '"status": "failed"' "$run_dir/manifest.json"
  grep -q '"exit_code":4' "$run_dir/manifest.json"
}

@test "report renders the latest manifest" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --profile quick-tcp --authorized
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/bin/aegiscope" report
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output" >&3
    false
  fi
  report="$(find "$AEGISCOPE_RESULTS_ROOT" -name report.md -print -quit)"
  [ -s "$report" ]
  grep -q 'Authorized Security Assessment' "$report"
  grep -q '## Executive summary' "$report"
  grep -q '## Engagement parameters' "$report"
  grep -q '## Evidence inventory' "$report"
  grep -q 'ports-quick-tcp' "$report"
}

@test "formal report exports Markdown HTML JSON CSV and passes strict metadata gate" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --profile quick-tcp --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*ports-quick-tcp' -print -quit)"
  printf '%s\n' '{"engagement_name":"Final asset assessment","client":"Example client","report_status":"Final","assessors":["Analyst"],"authorization_reference":"ROE-1","executive_summary":"The authorized asset inventory completed without normalized vulnerability findings.","strategic_recommendations":["Maintain exposure monitoring"],"objectives":["Inventory exposure"],"limitations":["Point in time"]}' >"${TEST_WORK}/final-profile.json"
  run "$PROJECT_ROOT/bin/aegiscope" report --run "$run_dir" --format all --profile "${TEST_WORK}/final-profile.json" --strict
  [ "$status" -eq 0 ]
  [ -s "$run_dir/report.md" ]
  [ -s "$run_dir/report.html" ]
  [ -s "$run_dir/report.json" ]
  [ -s "$run_dir/findings.csv" ]
  [ -s "$run_dir/report-quality.json" ]
  grep -q '<table>' "$run_dir/report.html"
  grep -q '"schema_version": "aegiscope-report-1.0"' "$run_dir/report.json"
  grep -q '"ready_for_final": true' "$run_dir/report-quality.json"
  head -n 1 "$run_dir/findings.csv" | grep -q 'reference_id,severity,title,affected_asset'
}

@test "strict report rejects incomplete engagement metadata" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --profile quick-tcp --authorized
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/bin/aegiscope" report --strict
  [ "$status" -eq 1 ]
  [[ "$output" == *"strict report quality gate failed"* ]]
}

@test "report quality gate detects evidence modified after manifest creation" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --profile quick-tcp --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*ports-quick-tcp' -print -quit)"
  printf 'tampered\n' >>"$run_dir/nmap.nmap"
  run "$PROJECT_ROOT/bin/aegiscope" report --run "$run_dir" --format json --profile "$PROJECT_ROOT/config/report_profile.example.json"
  [ "$status" -eq 0 ]
  grep -q '"evidence_integrity_failures": 1' "$run_dir/report-quality.json"
  grep -q '"integrity_status": "mismatch"' "$run_dir/report.json"
  grep -q '"ready_for_final": false' "$run_dir/report-quality.json"
}

@test "forced color renders the extensive category menu" {
  run bash -c "printf '0\\n' | AEGISCOPE_FORCE_COLOR=1 '$PROJECT_ROOT/bin/aegiscope'"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[36m'* ]]
  [[ "$output" == *"Reconnaissance — passive, verify, active and OWASP pipelines"* ]]
  [[ "$output" == *"DDoS / load resilience"* ]]
  [[ "$output" == *"Workspace & assets"* ]]
  [[ "$output" == *"Credentials & plugins"* ]]
}

@test "Gobuster DNS mode is available alongside VHost mode" {
  mock_gobuster
  run "$PROJECT_ROOT/bin/aegiscope" web --target lab.example.com --mode dns --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  grep -Fx -- 'dns' "$MOCK_LOG"
  grep -Fx -- '-d' "$MOCK_LOG"
  grep -Fx -- 'lab.example.com' "$MOCK_LOG"
}

@test "XSS audit sends only a harmless canary and records reflection analysis" {
  mock_curl
  run "$PROJECT_ROOT/bin/aegiscope" xss --target https://localhost/search --parameter query --method get --authorized
  [ "$status" -eq 0 ]
  grep -q 'curl:.*--data-urlencode query=AEGISCOPE_CANARY_' "$MOCK_LOG"
  ! grep -Eqi '<script|javascript:' "$MOCK_LOG"
  report="$(find "$AEGISCOPE_RESULTS_ROOT" -name xss-reflection-report.txt -print -quit)"
  grep -q 'parameter=query reflected=' "$report"
  grep -q 'not proof that executable XSS exists' "$report"
}

@test "XSS audit discovers form parameters and writes structured context evidence" {
  mock_curl
  run "$PROJECT_ROOT/bin/aegiscope" xss --target 'https://localhost/search?existing=value' --discover-parameters --authorized
  [ "$status" -eq 0 ]
  grep -q 'curl:.*--data-urlencode existing=AEGISCOPE_CANARY_' "$MOCK_LOG"
  grep -q 'curl:.*--data-urlencode user=AEGISCOPE_CANARY_' "$MOCK_LOG"
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*xss-reflection' -print -quit)"
  grep -Fx 'existing' "$run_dir/xss-discovered-parameters.txt"
  grep -Fx 'user' "$run_dir/xss-discovered-parameters.txt"
  [ -s "$run_dir/xss-results.jsonl" ]
  [ -e "$run_dir/xss-dom-indicators.txt" ]
}

@test "bounded load mode uses capped hey settings and writes a manifest" {
  mock_hey
  run "$PROJECT_ROOT/bin/aegiscope" load --target https://localhost --duration 5 --request-rate 10 --concurrency 2 --engine hey --authorized
  [ "$status" -eq 0 ]
  grep -q 'hey:.*-z 5s.*-q 5.*-c 2.*-o csv' "$MOCK_LOG"
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*load-hey' -print -quit)"
  [ -s "$run_dir/hey-results.csv" ]
  grep -q '"operation": "load-hey"' "$run_dir/manifest.json"
}

@test "bounded load supports authenticated methods bodies and service thresholds" {
  mock_hey
  run "$PROJECT_ROOT/bin/aegiscope" ddos --target https://localhost/api --duration 2 --request-rate 4 --concurrency 2 --engine hey --method POST --header 'Authorization: Bearer test-secret' --body '{"probe":true}' --max-error-rate 1 --p95-ms 100 --authorized
  [ "$status" -eq 0 ]
  grep -q 'hey:.*-m POST.*-H Authorization: Bearer test-secret.*-d {"probe":true}' "$MOCK_LOG"
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*load-hey' -print -quit)"
  grep -q '"passed":true' "$run_dir/load-assessment.json"
  grep -q '"method":"POST"' "$run_dir/load-plan.json"
  grep -q 'REDACTED' "$run_dir/manifest.json"
  grep -q 'REDACTED.*REQUEST.*BODY' "$run_dir/manifest.json"
  ! grep -q 'test-secret' "$run_dir/manifest.json"
  ! grep -q 'probe.*true' "$run_dir/manifest.json"
}

@test "bounded load mode rejects excessive duration and total requests" {
  run "$PROJECT_ROOT/bin/aegiscope" load --target https://localhost --duration 61 --request-rate 10 --engine curl --authorized
  [ "$status" -eq 1 ]
  [[ "$output" == *"duration exceeds hard maximum"* ]]

  run "$PROJECT_ROOT/bin/aegiscope" load --target https://localhost --duration 60 --request-rate 100 --engine curl --authorized
  [ "$status" -eq 1 ]
  [[ "$output" == *"hard request budget"* ]]
}

@test "compare generates a Markdown diff for two result runs" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --profile quick-tcp --authorized
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --profile firewall-map --authorized
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/bin/aegiscope" compare
  [ "$status" -eq 0 ]
  comparison="$(find "$AEGISCOPE_RESULTS_ROOT" -name 'comparison-to-*.md' -print -quit)"
  [ -s "$comparison" ]
  grep -q 'Manifest differences' "$comparison"
}

@test "asset workspace ingests manifests and generates a portable dashboard" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --profile quick-tcp --authorized
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/bin/aegiscope" assets list --kind domain
  [ "$status" -eq 0 ]
  [[ "$output" == *"localhost"* ]]
  dashboard="${TEST_WORK}/asset-dashboard.html"
  run "$PROJECT_ROOT/bin/aegiscope" assets dashboard --output "$dashboard"
  [ "$status" -eq 0 ]
  grep -q 'IRONCRYPT.*AEGISCOPE' "$dashboard"
  grep -q 'localhost' "$dashboard"
}

@test "complete pipeline coordinates tools checkpoints cache and normalization" {
  mock_advanced_pipeline
  run "$PROJECT_ROOT/bin/aegiscope" pipeline --target lab.example.com --phase all --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  grep -q 'subfinder:.*-oJ.*-rl 10' "$MOCK_LOG"
  grep -q 'dnsx:.*-json.*-rl 10' "$MOCK_LOG"
  grep -q 'naabu:.*-top-ports 1000.*-rate 10' "$MOCK_LOG"
  grep -q 'httpx:.*-tech-detect.*-rl 10' "$MOCK_LOG"
  grep -q 'katana:.*-js-crawl.*-rate-limit 10' "$MOCK_LOG"
  grep -q 'katana:.*-fs fqdn' "$MOCK_LOG"
  grep -Fx -- '-iL' "$MOCK_LOG"
  grep -q 'resolved-hosts.txt' "$MOCK_LOG"
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*pipeline-all' -print -quit)"
  [ -f "$run_dir/.state/subfinder.completed.json" ]
  [ -f "$run_dir/.state/katana.completed.json" ]
  [ -s "$run_dir/pipeline/katana.jsonl" ]
  run "$PROJECT_ROOT/bin/aegiscope" assets list --kind technology
  [ "$status" -eq 0 ]
  [[ "$output" == *"nginx"* ]]
}

@test "pipeline fails when a required phase dependency is unavailable" {
  run -127 "$PROJECT_ROOT/bin/aegiscope" pipeline --target lab.example.com --phase passive --request-rate 10 --cache-ttl 0 --authorized
  [ "$status" -eq 127 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*pipeline-passive' -print -quit)"
  [ -f "$run_dir/.state/subfinder.skipped.json" ]
  grep -q '"status": "failed"' "$run_dir/manifest.json"
}

@test "pipeline resume honors completed checkpoints" {
  mock_advanced_pipeline
  run "$PROJECT_ROOT/bin/aegiscope" pipeline --target lab.example.com --phase all --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*pipeline-all' -print -quit)"
  before="$(wc -l <"$MOCK_LOG")"
  run "$PROJECT_ROOT/bin/aegiscope" resume "$run_dir" --target lab.example.com --phase all --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  after="$(wc -l <"$MOCK_LOG")"
  [ "$before" -eq "$after" ]
  [ -n "$(find "$run_dir/history" -name 'manifest-*.json' -print -quit)" ]
  [ -n "$(find "$run_dir" -name 'pipeline-resume-plan-*.json' -print -quit)" ]
}

@test "pipeline resume rejects a target different from the original plan" {
  mock_advanced_pipeline
  run "$PROJECT_ROOT/bin/aegiscope" pipeline --target lab.example.com --phase all --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*pipeline-all' -print -quit)"
  printf 'other.lab.example.com\n' >>"$AEGISCOPE_SCOPE_FILE"
  run "$PROJECT_ROOT/bin/aegiscope" resume "$run_dir" --target other.lab.example.com --phase all --request-rate 10 --authorized
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not match the original pipeline target"* ]]
}

@test "pipeline retry reruns only a step without a completed checkpoint" {
  mock_advanced_pipeline
  run "$PROJECT_ROOT/bin/aegiscope" pipeline --target lab.example.com --phase all --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*pipeline-all' -print -quit)"
  rm "$run_dir/.state/katana.completed.json"
  before="$(grep -c '^katana:' "$MOCK_LOG")"
  run "$PROJECT_ROOT/bin/aegiscope" retry "$run_dir" --failed-only --target lab.example.com --phase all --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  after="$(grep -c '^katana:' "$MOCK_LOG")"
  [ "$after" -eq "$((before + 1))" ]
}

@test "pipeline retry preserves failed checkpoint history and succeeds on recovery" {
  mock_advanced_pipeline
  mock_katana_fail_once
  run "$PROJECT_ROOT/bin/aegiscope" pipeline --target lab.example.com --phase all --request-rate 10 --cache-ttl 0 --authorized
  [ "$status" -eq 1 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*pipeline-all' -print -quit)"
  [ -f "$run_dir/.state/katana.failed.json" ]
  run "$PROJECT_ROOT/bin/aegiscope" retry "$run_dir" --failed-only --target lab.example.com --phase all --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  [ -f "$run_dir/.state/katana.completed.json" ]
  [ -n "$(find "$run_dir/.state/history" -name 'katana.failed.*.json' -print -quit)" ]
  python - "$run_dir/manifest.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["status"] == "completed"
assert any("history/manifest-" in item for item in data["artifacts"])
PY
}

@test "credential profiles hide values and integrate without command-line storage" {
  printf 'Authorization: Bearer profile-secret\nCookie: session=profile-cookie\n' >"${TEST_WORK}/headers.txt"
  run "$PROJECT_ROOT/bin/aegiscope" auth add --name staging --from-file "${TEST_WORK}/headers.txt"
  [ "$status" -eq 0 ]
  [ -f "$AEGISCOPE_RESULTS_ROOT/workspace/auth/staging.headers" ]
  run "$PROJECT_ROOT/bin/aegiscope" auth show --name staging
  [ "$status" -eq 0 ]
  [[ "$output" == *"Authorization: [REDACTED]"* ]]
  [[ "$output" != *"profile-secret"* ]]
  run "$PROJECT_ROOT/bin/aegiscope" auth list
  [[ "$output" == *"staging"* ]]
}

@test "API reconnaissance parses OpenAPI endpoints and security schemes" {
  printf '%s\n' '{"openapi":"3.0.0","info":{"title":"Lab API","version":"1"},"components":{"securitySchemes":{"bearerAuth":{"type":"http"}}},"paths":{"/users":{"get":{"parameters":[{"name":"limit","in":"query"}]},"post":{}}}}' >"${TEST_WORK}/openapi.json"
  run "$PROJECT_ROOT/bin/aegiscope" api --target https://localhost --spec "${TEST_WORK}/openapi.json" --authorized
  [ "$status" -eq 0 ]
  inventory="$(find "$AEGISCOPE_RESULTS_ROOT" -name api-inventory.json -print -quit)"
  grep -q '"path": "/users"' "$inventory"
  grep -q '"bearerAuth"' "$inventory"
  grep -q '"POST"' "$inventory"
}

@test "API reconnaissance imports Postman and records advertised methods and CORS evidence" {
  mock_curl
  printf '%s\n' '{"info":{"name":"Lab collection"},"item":[{"name":"Users","request":{"method":"GET","url":{"raw":"https://localhost/users"}}}]}' >"${TEST_WORK}/postman.json"
  run "$PROJECT_ROOT/bin/aegiscope" api --target https://localhost --import "${TEST_WORK}/postman.json" --format postman --cors --authorized
  [ "$status" -eq 0 ]
  inventory="$(find "$AEGISCOPE_RESULTS_ROOT" -name api-inventory.json -print -quit)"
  report="$(find "$AEGISCOPE_RESULTS_ROOT" -name api-cors-analysis.txt -print -quit)"
  grep -q '"format": "postman"' "$inventory"
  grep -q 'https://localhost/users' "$inventory"
  grep -q 'advertised_methods=GET, HEAD, OPTIONS' "$report"
  grep -q 'probe_origin=https://aegiscope.invalid' "$report"
  grep -q '^allow_origin=' "$report"
  grep -q '^assessment=' "$report"
}

@test "API reconnaissance auto-detects a Burp XML import after evidence copy" {
  printf '%s\n' '<items><item><url>https://localhost/api/users</url><method>GET</method></item></items>' >"${TEST_WORK}/burp.xml"
  run "$PROJECT_ROOT/bin/aegiscope" api --target https://localhost --import "${TEST_WORK}/burp.xml" --format auto --authorized
  [ "$status" -eq 0 ]
  inventory="$(find "$AEGISCOPE_RESULTS_ROOT" -name api-inventory.json -print -quit)"
  grep -q '"format": "burp"' "$inventory"
  grep -q '"path": "/api/users"' "$inventory"
}

@test "Nuclei validation enforces signed-template policy and normalizes findings" {
  mock_nuclei
  run "$PROJECT_ROOT/bin/aegiscope" validate --target https://localhost --severity high,critical --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  grep -q 'nuclei:.*-disable-unsigned-templates.*-exclude-tags dos,code,fuzz,headless' "$MOCK_LOG"
  grep -q 'nuclei:.*-disable-redirects.*-no-interactsh' "$MOCK_LOG"
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*nuclei-validate' -print -quit)"
  [ -s "$run_dir/nuclei.jsonl" ]
  python - "$AEGISCOPE_RESULTS_ROOT/workspace/assets.db" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
assert db.execute("select count(*) from findings where severity='high'").fetchone()[0] == 1
PY
}

@test "formal vulnerability report marks automated findings unvalidated" {
  mock_nuclei
  run "$PROJECT_ROOT/bin/aegiscope" validate --target https://localhost --severity high --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*nuclei-validate' -print -quit)"
  run "$PROJECT_ROOT/bin/aegiscope" report --run "$run_dir" --format all --profile "$PROJECT_ROOT/config/report_profile.example.json"
  [ "$status" -eq 0 ]
  grep -q 'AEGIS-001' "$run_dir/report.md"
  grep -q 'Unvalidated automated finding' "$run_dir/report.md"
  grep -q 'HIGH' "$run_dir/report.md"
  grep -q '"ready_for_final": false' "$run_dir/report-quality.json"
  grep -q '"automated_findings_require_validation": 1' "$run_dir/report-quality.json"
}

@test "strict vulnerability report requires and accepts a per-finding analyst disposition" {
  mock_nuclei
  run "$PROJECT_ROOT/bin/aegiscope" validate --target https://localhost --severity high --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*nuclei-validate' -print -quit)"
  printf '%s\n' '{"engagement_name":"Validated assessment","client":"Example client","report_status":"Final","assessors":["Analyst"],"authorization_reference":"ROE-1","executive_summary":"A validated information exposure requires remediation.","strategic_recommendations":["Remove public debug exposure"],"objectives":["Validate exposure"],"limitations":["Point in time"],"finding_overrides":{"exposure-test":{"status":"Confirmed","impact":"Validated information exposure","likelihood":"Likely from the external network","remediation":"Remove the exposed debug endpoint","remediation_owner":"Application Team","target_date":"2026-08-01"}}}' >"${TEST_WORK}/validated-profile.json"
  run "$PROJECT_ROOT/bin/aegiscope" report --run "$run_dir" --format all --profile "${TEST_WORK}/validated-profile.json" --strict
  [ "$status" -eq 0 ]
  grep -q 'Confirmed' "$run_dir/report.md"
  grep -q 'Application Team' "$run_dir/report.md"
  grep -q '"ready_for_final": true' "$run_dir/report-quality.json"
  grep -q '"automated_findings_require_validation": 0' "$run_dir/report-quality.json"
}

@test "Nuclei validation pins reviewed templates by content fingerprint" {
  mock_nuclei
  printf '%s\n' 'id: reviewed-template' 'info:' '  name: Reviewed' '  severity: info' >"${TEST_WORK}/reviewed.yaml"
  digest="$(python "$PROJECT_ROOT/lib/workspace.py" --db "${TEST_WORK}/fingerprint.db" fingerprint --path "${TEST_WORK}/reviewed.yaml")"
  run "$PROJECT_ROOT/bin/aegiscope" validate --target https://localhost --templates "${TEST_WORK}/reviewed.yaml" --template-sha256 "$digest" --authorized
  [ "$status" -eq 0 ]
  grep -q "template_sha256.*$digest" "$(find "$AEGISCOPE_RESULTS_ROOT" -name nuclei-policy.json -print -quit)"
  grep -q 'nuclei:.*-templates-version' "$MOCK_LOG"

  run "$PROJECT_ROOT/bin/aegiscope" validate --target https://localhost --templates "${TEST_WORK}/reviewed.yaml" --template-sha256 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --authorized
  [ "$status" -eq 1 ]
  [[ "$output" == *"template fingerprint mismatch"* ]]
}

@test "asset diff since reports newly observed inventory" {
  mock_nmap
  run "$PROJECT_ROOT/bin/aegiscope" ports --target localhost --profile quick-tcp --authorized
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/bin/aegiscope" diff --since 7d
  [ "$status" -eq 0 ]
  [[ "$output" == *"localhost"* ]]
}

@test "asset first and last seen remain correct when manifests are ingested out of order" {
  mkdir -p "${TEST_WORK}/older" "${TEST_WORK}/newer"
  printf '%s\n' '{"target":"lab.example.com","operation":"manual","started_at":"2025-01-01T00:00:00Z","completed_at":"2025-01-01T00:01:00Z","status":"completed","artifacts":[]}' >"${TEST_WORK}/older/manifest.json"
  printf '%s\n' '{"target":"lab.example.com","operation":"manual","started_at":"2026-01-01T00:00:00Z","completed_at":"2026-01-01T00:01:00Z","status":"completed","artifacts":[]}' >"${TEST_WORK}/newer/manifest.json"
  run "$PROJECT_ROOT/bin/aegiscope" assets ingest --manifest "${TEST_WORK}/newer/manifest.json"
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/bin/aegiscope" assets ingest --manifest "${TEST_WORK}/older/manifest.json"
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/bin/aegiscope" assets list --kind domain --match lab.example.com --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"first_seen": "2025-01-01T00:01:00Z"'* ]]
  [[ "$output" == *'"last_seen": "2026-01-01T00:01:00Z"'* ]]
}

@test "reviewed plugin adapter executes and records normalized artifacts" {
  mock_curl
  run "$PROJECT_ROOT/bin/aegiscope" plugins run --name http-head --target https://localhost --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -name '*plugin-http-head' -print -quit)"
  [ -s "$run_dir/http-head.headers" ]
  grep -q 'server=mockd' "$run_dir/http-head.normalized.txt"
  grep -q 'http-head.normalized.txt' "$run_dir/manifest.json"
}

@test "all header designs render permanent IronCrypt creator credits without animation" {
  run bash -c "printf '0\\n' | NO_ANIMATION=1 AEGISCOPE_FORCE_COLOR=1 AEGISCOPE_BANNER_STYLE=classic '$PROJECT_ROOT/bin/aegiscope'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Reconnaissance • Assets • Evidence • Validation"* ]]
  [[ "$output" == *"IronCrypt"*"Made by"*"Master_Panpour"*"Master_Demon"* ]]
  run bash -c "printf '0\\n' | NO_ANIMATION=1 AEGISCOPE_FORCE_COLOR=1 AEGISCOPE_BANNER_STYLE=shield '$PROJECT_ROOT/bin/aegiscope'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ASSET INTELLIGENCE"* ]]
  run bash -c "printf '0\\n' | NO_ANIMATION=1 AEGISCOPE_FORCE_COLOR=1 AEGISCOPE_BANNER_STYLE=minimal '$PROJECT_ROOT/bin/aegiscope'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[ IRONCRYPT ]"* ]]
  run bash -c "printf '0\\n' | NO_ANIMATION=1 AEGISCOPE_FORCE_COLOR=1 AEGISCOPE_BANNER_STYLE=permanent '$PROJECT_ROOT/bin/aegiscope'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AUTHORIZED RECONNAISSANCE SENTINEL"* ]]
  [[ "$output" == *"[  IC  ]"* ]]
}
