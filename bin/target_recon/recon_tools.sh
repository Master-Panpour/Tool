#!/usr/bin/env bash
# recon_tools.sh - implementations for target reconnaissance tasks

   #!/bin/bash
   # Copyright (C) 2025 Master_Panpour
   #
   # This program is free software: you can redistribute it and/or modify
   # it under the terms of the GNU General Public License as published by
   # the Free Software Foundation, either version 3 of the License, or
   # (at your option) any later version.
   #
   # This program is distributed in the hope that it will be useful,
   # but WITHOUT ANY WARRANTY; without even the implied warranty of
   # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   # GNU General Public License for more details.
   #
   # You should have received a copy of the GNU General Public License
   # along with this program.  If not, see <https://www.gnu.org/licenses/>.

# single-line comment: color variables
RESET="\033[0m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"

# single-line comment: helper to check command exists
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "${RED}Error:${RESET} required command '$1' not found. Install it first.\n"
    exit 2
  fi
}

# single-line comment: helper to prompt yes/no
confirm() {
  read -rp "$(printf "${YELLOW}%s [y/N]: ${RESET}" "$1")" ans
  case "$ans" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

# single-line comment: determine target input
get_target() {
  read -rp "Enter target (IP or hostname) [default: 127.0.0.1]: " TARGET
  TARGET=${TARGET:-127.0.0.1}
  echo "$TARGET"
}

# single-line comment: run ipinfo/ipapi geolocation and ASN info
do_ipinfo() {
  TARGET="$(get_target)"
  printf "${CYAN}Looking up IP info for: %s${RESET}\n" "$TARGET"
  if command -v curl >/dev/null 2>&1; then
    # single-line comment: try ipinfo lite endpoint first (requires token for full); safe to use ipapi as fallback
    if confirm "Use ipinfo.io (may require token) ?"; then
      # single-line comment: public queries may be rate-limited; user can set IPINFO_TOKEN env var
      if [ -n "$IPINFO_TOKEN" ]; then
        curl -s "https://ipinfo.io/${TARGET}/json?token=${IPINFO_TOKEN}" | jq .
      else
        echo "${YELLOW}No IPINFO_TOKEN set; attempting public ipapi.co fallback...${RESET}"
        curl -s "https://ipapi.co/${TARGET}/json/" | jq .
      fi
    else
      curl -s "https://ipapi.co/${TARGET}/json/" | jq .
    fi
  else
    printf "${RED}curl not found. Install curl to use IP lookup.${RESET}\n"
  fi
}

# single-line comment: DNS lookups via dig and nslookup
do_dig() {
  TARGET="$(get_target)"
  require_cmd dig
  printf "${CYAN}dig A record for %s:${RESET}\n" "$TARGET"
  dig +noall +answer A "$TARGET"
  printf "\n${CYAN}dig NS records:${RESET}\n"
  dig +noall +answer NS "$TARGET"
  printf "\n${CYAN}dig MX records:${RESET}\n"
  dig +noall +answer MX "$TARGET"
  printf "\n${CYAN}dig SOA record:${RESET}\n"
  dig +noall +answer SOA "$TARGET"
}

# single-line comment: whois lookup
do_whois() {
  TARGET="$(get_target)"
  require_cmd whois
  printf "${CYAN}whois lookup for %s:${RESET}\n" "$TARGET"
  whois "$TARGET"
}

# single-line comment: HTTP headers via curl -I
do_headers() {
  read -rp "Enter URL (include http(s)://) [default: http://127.0.0.1:8080]: " URL
  URL=${URL:-http://127.0.0.1:8080}
  require_cmd curl
  printf "${CYAN}Fetching headers for %s${RESET}\n" "$URL"
  curl -I -L --max-redirs 5 --silent --show-error "$URL"
}

# single-line comment: get SSL/TLS certificate details using openssl
do_ssl() {
  read -rp "Enter host (no protocol, port optional e.g. example.com:443) [default: example.com:443]: " HOST
  HOST=${HOST:-example.com:443}
  require_cmd openssl
  printf "${CYAN}Fetching certificate for %s${RESET}\n" "$HOST"
  # single-line comment: use s_client then parse cert with x509 for readable output
  echo | openssl s_client -connect "$HOST" -servername "${HOST%%:*}" 2>/dev/null | openssl x509 -noout -text
}

# single-line comment: ping
do_ping() {
  TARGET="$(get_target)"
  require_cmd ping
  printf "${CYAN}Pinging %s (5 packets)${RESET}\n" "$TARGET"
  # single-line comment: use -c 5 for Unix, or handle Windows via ping -n
  if ping -c 1 127.0.0.1 >/dev/null 2>&1; then
    ping -c 5 "$TARGET"
  else
    # single-line comment: fallback (likely Windows): use -n
    ping -n 5 "$TARGET"
  fi
}

# single-line comment: traceroute
do_traceroute() {
  TARGET="$(get_target)"
  # single-line comment: prefer traceroute, fallback to tracepath if available
  if command -v traceroute >/dev/null 2>&1; then
    printf "${CYAN}Running traceroute to %s${RESET}\n" "$TARGET"
    traceroute "$TARGET"
  elif command -v tracepath >/dev/null 2>&1; then
    printf "${CYAN}Running tracepath to %s${RESET}\n" "$TARGET"
    tracepath "$TARGET"
  else
    printf "${RED}traceroute/tracepath not found. Install traceroute package.${RESET}\n"
  fi
}

# single-line comment: quick nmap top ports
do_nmap_quick() {
  TARGET="$(get_target)"
  require_cmd nmap
  printf "${CYAN}Running quick nmap scan (top 1000 ports + service detect) on %s${RESET}\n" "$TARGET"
  nmap -Pn -sT --top-ports 1000 -sV "$TARGET"
}

# single-line comment: shodan usage stub (requires API key & shodan CLI installed)
do_shodan() {
  if ! command -v shodan >/dev/null 2>&1; then
    printf "${YELLOW}Shodan CLI not found. To use Shodan install via 'pip install --user shodan'.${RESET}\n"
  fi
  read -rp "Enter target IP or hostname for Shodan lookup: " TARGET
  TARGET=${TARGET:-127.0.0.1}
  if [ -z "$SHODAN_API_KEY" ]; then
    echo "${YELLOW}No SHODAN_API_KEY env var set. You can export it or run 'shodan init <APIKEY>'.${RESET}"
  fi
  printf "${CYAN}If you have Shodan CLI configured, this will run: shodan host %s${RESET}\n" "$TARGET"
  if confirm "Proceed with Shodan host lookup (requires configured CLI) ?"; then
    shodan host "$TARGET"
  else
    echo "Skipping Shodan."
  fi
}

# single-line comment: dispatch based on first argument
ACTION="$1"
case "$ACTION" in
  ipinfo) do_ipinfo ;;
  dig) do_dig ;;
  whois) do_whois ;;
  headers) do_headers ;;
  ssl) do_ssl ;;
  ping) do_ping ;;
  traceroute) do_traceroute ;;
  nmap_quick) do_nmap_quick ;;
  shodan) do_shodan ;;
  *)
    printf "${YELLOW}Usage: recon_tools.sh <action>\nActions: ipinfo,dig,whois,headers,ssl,ping,traceroute,nmap_quick,shodan${RESET}\n"
    exit 1
    ;;
esac
