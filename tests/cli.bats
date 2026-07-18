#!/usr/bin/env bats

load test_helper

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
  run "$PROJECT_ROOT/bin/aegiscope" web --target lab.example.com --mode subdomains --request-rate 15 --authorized
  [ "$status" -eq 0 ]
  grep -q 'subfinder:.*-oJ.*-cs' "$MOCK_LOG"
  grep -q 'httpx:.*-rl 15.*-tech-detect.*-json' "$MOCK_LOG"
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [ -s "$run_dir/subdomains.jsonl" ]
  [ -s "$run_dir/subdomains.txt" ]
  [ -s "$run_dir/httpx.jsonl" ]
}

@test "HTTP mode produces redirect cookie security-header and advertised-method analysis" {
  mock_curl
  run "$PROJECT_ROOT/bin/aegiscope" web --target https://localhost --mode http --authorized
  [ "$status" -eq 0 ]
  analysis="$(find "$AEGISCOPE_RESULTS_ROOT" -name http-analysis.txt -print -quit)"
  grep -q 'redirects=1' "$analysis"
  grep -q 'session=test' "$analysis"
  grep -q 'Strict-Transport-Security: present' "$analysis"
  grep -q 'Content-Security-Policy: missing' "$analysis"
  grep -q 'GET, HEAD, OPTIONS' "$analysis"
}

@test "TLS mode prefers testssl and preserves JSON and HTML artifacts" {
  mock_testssl
  run "$PROJECT_ROOT/bin/aegiscope" web --target https://localhost --mode tls --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [ -s "$run_dir/testssl.json" ]
  [ -s "$run_dir/testssl.html" ]
  grep -q 'testssl:.*localhost:443' "$MOCK_LOG"
}

@test "OWASP all-stage recon creates ordered evidence directories" {
  mock_curl
  run "$PROJECT_ROOT/bin/aegiscope" recon --target https://localhost --stage all --request-rate 10 --authorized
  [ "$status" -eq 0 ]
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [ -d "$run_dir/01-server-fingerprint" ]
  [ -d "$run_dir/02-metafiles" ]
  [ -d "$run_dir/03-applications" ]
  [ -d "$run_dir/04-entry-points" ]
  [ -d "$run_dir/05-execution-paths" ]
  [ -d "$run_dir/06-architecture" ]
  grep -q '"operation": "recon-all"' "$run_dir/manifest.json"
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
  grep -q 'IronCrypt Aegiscope report' "$report"
  grep -q 'ports-quick-tcp' "$report"
}

@test "forced color renders the extensive category menu" {
  run bash -c "printf '0\\n' | AEGISCOPE_FORCE_COLOR=1 '$PROJECT_ROOT/bin/aegiscope'"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[36m'* ]]
  [[ "$output" == *"Reconnaissance — network, intelligence and OWASP stages"* ]]
  [[ "$output" == *"DDoS / load resilience"* ]]
  [[ "$output" == *"Application security"* ]]
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
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -print -quit)"
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
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [ -s "$run_dir/hey-results.csv" ]
  grep -q '"operation": "load-hey"' "$run_dir/manifest.json"
}

@test "bounded load supports authenticated methods bodies and service thresholds" {
  mock_hey
  run "$PROJECT_ROOT/bin/aegiscope" ddos --target https://localhost/api --duration 2 --request-rate 4 --concurrency 2 --engine hey --method POST --header 'Authorization: Bearer test-secret' --body '{"probe":true}' --max-error-rate 1 --p95-ms 100 --authorized
  [ "$status" -eq 0 ]
  grep -q 'hey:.*-m POST.*-H Authorization: Bearer test-secret.*-d {"probe":true}' "$MOCK_LOG"
  run_dir="$(find "$AEGISCOPE_RESULTS_ROOT" -mindepth 1 -maxdepth 1 -type d -print -quit)"
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
