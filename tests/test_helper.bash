setup_workspace() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TEST_WORK="$(mktemp -d)"
  MOCK_BIN="${TEST_WORK}/bin"
  MOCK_LOG="${TEST_WORK}/mock.log"
  mkdir -p "$MOCK_BIN" "${TEST_WORK}/results"
  printf 'localhost\n127.0.0.1\nlab.example.com\n*.lab.example.com\n' >"${TEST_WORK}/scope.txt"
  export PROJECT_ROOT TEST_WORK MOCK_BIN MOCK_LOG
  export PATH="${MOCK_BIN}:${PATH}"
  export AEGISCOPE_RESULTS_ROOT="${TEST_WORK}/results"
  export AEGISCOPE_SCOPE_FILE="${TEST_WORK}/scope.txt"
  export AEGISCOPE_MAX_RATE=100
}

teardown_workspace() {
  rm -rf "$TEST_WORK"
}

mock_nmap() {
  cat >"${MOCK_BIN}/nmap" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'Nmap mock 1.0'; exit 0; fi
printf '%s\n' "$@" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-oA" ]]; then
    touch "${2}.nmap" "${2}.gnmap" "${2}.xml"
    break
  fi
  shift
done
EOF
  chmod +x "${MOCK_BIN}/nmap"
}

mock_ffuf() {
  cat >"${MOCK_BIN}/ffuf" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'ffuf mock 1.0'; exit 0; fi
printf '%s\n' "$@" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-o" ]]; then touch "$2"; break; fi
  shift
done
EOF
  chmod +x "${MOCK_BIN}/ffuf"
}

mock_gobuster() {
  cat >"${MOCK_BIN}/gobuster" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'gobuster mock 1.0'; exit 0; fi
printf '%s\n' "$@" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-o" ]]; then touch "$2"; break; fi
  shift
done
EOF
  chmod +x "${MOCK_BIN}/gobuster"
}

mock_subfinder_pipeline() {
  cat >"${MOCK_BIN}/subfinder" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'subfinder mock 1.0'; exit 0; fi
printf 'subfinder:%s\n' "$*" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-o" ]]; then
    printf '{"host":"app.lab.example.com","source":"crtsh"}\n' >"$2"
    printf '{"host":"outside.example.net","source":"crtsh"}\n' >>"$2"
    break
  fi
  shift
done
EOF
  cat >"${MOCK_BIN}/jq" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'jq mock 1.0'; exit 0; fi
printf 'app.lab.example.com\noutside.example.net\n'
EOF
  cat >"${MOCK_BIN}/httpx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'httpx mock 1.0'; exit 0; fi
printf 'httpx:%s\n' "$*" >>"$MOCK_LOG"
output=''
while (($#)); do
  if [[ "$1" == "-o" ]]; then output="$2"; break; fi
  shift
done
payload='{"url":"https://app.lab.example.com","status_code":200,"title":"Lab"}'
if [[ -n "$output" ]]; then printf '%s\n' "$payload" >"$output"; else printf '%s\n' "$payload"; fi
EOF
  chmod +x "${MOCK_BIN}/subfinder" "${MOCK_BIN}/jq" "${MOCK_BIN}/httpx"
}

mock_curl() {
  cat >"${MOCK_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'curl mock 1.0'; exit 0; fi
printf 'curl:%s\n' "$*" >>"$MOCK_LOG"
headers=''
output=''
options=0
write_out=''
while (($#)); do
  case "$1" in
    --dump-header) headers="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --request) [[ "$2" == OPTIONS ]] && options=1; shift 2 ;;
    --write-out) write_out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -n "$headers" ]]; then
  if ((options == 1)); then
    printf 'HTTP/1.1 204 No Content\r\nAllow: GET, HEAD, OPTIONS\r\n\r\n' >"$headers"
  else
    printf 'HTTP/1.1 301 Moved\r\nLocation: https://localhost/home\r\n\r\nHTTP/2 200\r\nServer: mockd\r\nSet-Cookie: session=test; Secure; HttpOnly\r\nStrict-Transport-Security: max-age=31536000\r\nX-Content-Type-Options: nosniff\r\n\r\n' >"$headers"
  fi
fi
if [[ -n "$output" && "$output" != /dev/null ]]; then
  mkdir -p "$(dirname "$output")"
  printf '<html><a href="/login">Login</a><form action="/submit"><input name="user"></form></html>\n' >"$output"
fi
if [[ -n "$write_out" ]]; then
  printf 'final_url=https://localhost\nstatus=301\nremote_ip=127.0.0.1\ntls_verify=0\nredirects_followed=0\n'
fi
EOF
  chmod +x "${MOCK_BIN}/curl"
}

mock_httpx_capture() {
  cat >"${MOCK_BIN}/httpx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'httpx mock 1.0'; exit 0; fi
printf 'httpx:%s\n' "$*" >>"$MOCK_LOG"
printf '{"url":"https://localhost","status_code":200,"title":"Lab","tech":["nginx"]}\n'
EOF
  chmod +x "${MOCK_BIN}/httpx"
}

mock_httpx_failure() {
  cat >"${MOCK_BIN}/httpx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'httpx mock 1.0'; exit 0; fi
printf 'httpx:%s\n' "$*" >>"$MOCK_LOG"
exit 4
EOF
  chmod +x "${MOCK_BIN}/httpx"
}

mock_testssl() {
  cat >"${MOCK_BIN}/testssl.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'testssl mock 1.0'; exit 0; fi
printf 'testssl:%s\n' "$*" >>"$MOCK_LOG"
while (($#)); do
  case "$1" in
    --jsonfile) printf '{"id":"overall","severity":"OK"}\n' >"$2"; shift 2 ;;
    --htmlfile) printf '<html>OK</html>\n' >"$2"; shift 2 ;;
    *) shift ;;
  esac
done
EOF
  chmod +x "${MOCK_BIN}/testssl.sh"
}

mock_hey() {
  cat >"${MOCK_BIN}/hey" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'hey mock 1.0'; exit 0; fi
printf 'hey:%s\n' "$*" >>"$MOCK_LOG"
printf 'response-time,DNS+dialup,DNS,Request-write,Response-delay,Response-read,status-code,offset\n'
printf '0.010,0.001,0.001,0.001,0.005,0.002,200,0.010\n'
EOF
  chmod +x "${MOCK_BIN}/hey"
}

mock_advanced_pipeline() {
  mock_nmap
  cat >"${MOCK_BIN}/subfinder" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'subfinder mock 1.0'; exit 0; fi
printf 'subfinder:%s\n' "$*" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-o" ]]; then printf '{"host":"app.lab.example.com","source":"crtsh"}\n' >"$2"; break; fi
  shift
done
EOF
  cat >"${MOCK_BIN}/dnsx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'dnsx mock 1.0'; exit 0; fi
printf 'dnsx:%s\n' "$*" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-o" ]]; then printf '{"host":"app.lab.example.com","a":["127.0.0.1"]}\n' >"$2"; break; fi
  shift
done
EOF
  cat >"${MOCK_BIN}/naabu" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'naabu mock 1.0'; exit 0; fi
printf 'naabu:%s\n' "$*" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-o" ]]; then printf '{"host":"app.lab.example.com","ip":"127.0.0.1","port":443}\n' >"$2"; break; fi
  shift
done
EOF
  cat >"${MOCK_BIN}/httpx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'httpx mock 1.0'; exit 0; fi
printf 'httpx:%s\n' "$*" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-o" ]]; then printf '{"url":"https://app.lab.example.com","host":"app.lab.example.com","status_code":200,"tech":["nginx"]}\n' >"$2"; break; fi
  shift
done
EOF
  cat >"${MOCK_BIN}/katana" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'katana mock 1.0'; exit 0; fi
printf 'katana:%s\n' "$*" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-o" ]]; then printf '{"url":"https://app.lab.example.com/admin"}\n' >"$2"; break; fi
  shift
done
EOF
  cat >"${MOCK_BIN}/jq" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'jq mock 1.0'; exit 0; fi
input="${@: -1}"
case "$input" in
  *subfinder.jsonl|*dnsx.jsonl) printf 'app.lab.example.com\n' ;;
  *naabu.jsonl) printf '443\n' ;;
  *httpx.jsonl) printf 'https://app.lab.example.com\n' ;;
esac
EOF
  chmod +x "${MOCK_BIN}/subfinder" "${MOCK_BIN}/dnsx" "${MOCK_BIN}/naabu" "${MOCK_BIN}/httpx" "${MOCK_BIN}/katana" "${MOCK_BIN}/jq"
}

mock_katana_fail_once() {
  cat >"${MOCK_BIN}/katana" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'katana mock 1.0'; exit 0; fi
printf 'katana:%s\n' "$*" >>"$MOCK_LOG"
if [[ ! -f "${TEST_WORK}/katana-failed-once" ]]; then
  touch "${TEST_WORK}/katana-failed-once"
  exit 3
fi
while (($#)); do
  if [[ "$1" == "-o" ]]; then printf '{"url":"https://app.lab.example.com/admin"}\n' >"$2"; break; fi
  shift
done
EOF
  chmod +x "${MOCK_BIN}/katana"
}

mock_nuclei() {
  cat >"${MOCK_BIN}/nuclei" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo 'nuclei mock 1.0'; exit 0; fi
printf 'nuclei:%s\n' "$*" >>"$MOCK_LOG"
while (($#)); do
  if [[ "$1" == "-o" ]]; then printf '{"template-id":"exposure-test","matched-at":"https://localhost/debug","info":{"name":"Exposure","severity":"high"}}\n' >"$2"; break; fi
  shift
done
EOF
  chmod +x "${MOCK_BIN}/nuclei"
}
