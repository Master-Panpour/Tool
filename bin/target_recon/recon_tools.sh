#!/usr/bin/env bash
# recon_tools.sh - implementations for target reconnaissance tasks
# Copyright (C) 2025 Master_Panpour
# GPLv3: Free software, no warranty

# Colors
RESET="\033[0m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"

# Check required command exists
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "${RED}Error:${RESET} required command '$1' not found.\n"
    exit 2
  fi
}

# Prompt yes/no
confirm() {
  read -rp "$(printf "${YELLOW}%s [y/N]: ${RESET}" "$1")" ans
  case "$ans" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# Prompt for target
get_target() {
  read -rp "Enter target (IP or hostname) [default: 127.0.0.1]: " TARGET
  TARGET=${TARGET:-127.0.0.1}
  echo "$TARGET"
}

# Pause helper
pause() {
  read -rp "$(printf "${CYAN}Press Enter to return to menu...${RESET}")" _
}

# Actions
do_ipinfo() {
  TARGET="$(get_target)"
  printf "${CYAN}Looking up IP info for: %s${RESET}\n" "$TARGET"
  if command -v curl >/dev/null 2>&1; then
    if confirm "Use ipinfo.io (may require token)?"; then
      if [ -n "$IPINFO_TOKEN" ]; then
        curl -s "https://ipinfo.io/${TARGET}/json?token=${IPINFO_TOKEN}" | jq .
      else
        echo "${YELLOW}No IPINFO_TOKEN set; using ipapi.co fallback...${RESET}"
        curl -s "https://ipapi.co/${TARGET}/json/" | jq .
      fi
    else
      curl -s "https://ipapi.co/${TARGET}/json/" | jq .
    fi
  else
    printf "${RED}curl not found. Install curl to use IP lookup.${RESET}\n"
  fi
  pause
}

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
  pause
}

do_whois() {
  TARGET="$(get_target)"
  require_cmd whois
  printf "${CYAN}whois lookup for %s:${RESET}\n" "$TARGET"
  whois "$TARGET"
  pause
}

do_headers() {
  read -rp "Enter URL (include http(s)://) [default: http://127.0.0.1:8080]: " URL
  URL=${URL:-http://127.0.0.1:8080}
  require_cmd curl
  printf "${CYAN}Fetching headers for %s${RESET}\n" "$URL"
  curl -I -L --max-redirs 5 --silent --show-error "$URL"
  pause
}

do_ssl() {
  read -rp "Enter host (no protocol, port optional e.g. example.com:443) [default: example.com:443]: " HOST
  HOST=${HOST:-example.com:443}
  require_cmd openssl
  printf "${CYAN}Fetching certificate for %s${RESET}\n" "$HOST"
  echo | openssl s_client -connect "$HOST" -servername "${HOST%%:*}" 2>/dev/null | openssl x509 -noout -text
  pause
}

do_ping() {
  TARGET="$(get_target)"
  require_cmd ping
  printf "${CYAN}Pinging %s (5 packets)${RESET}\n" "$TARGET"
  ping -c 5 "$TARGET"
  pause
}

do_traceroute() {
  TARGET="$(get_target)"
  if command -v traceroute >/dev/null 2>&1; then
    printf "${CYAN}Running traceroute to %s${RESET}\n" "$TARGET"
    traceroute "$TARGET"
  elif command -v tracepath >/dev/null 2>&1; then
    printf "${CYAN}Running tracepath to %s${RESET}\n" "$TARGET"
    tracepath "$TARGET"
  else
    printf "${RED}traceroute/tracepath not found. Install traceroute package.${RESET}\n"
  fi
  pause
}

do_nmap_quick() {
  TARGET="$(get_target)"
  require_cmd nmap
  printf "${CYAN}Running quick nmap scan (top 1000 ports + service detect) on %s${RESET}\n" "$TARGET"
  nmap -Pn -sT --top-ports 1000 -sV "$TARGET"
  pause
}

do_shodan() {
  if ! command -v shodan >/dev/null 2>&1; then
    printf "${YELLOW}Shodan CLI not found. Install via 'pip install --user shodan'.${RESET}\n"
    pause
    return
  fi
  read -rp "Enter target IP or hostname for Shodan lookup: " TARGET
  TARGET=${TARGET:-127.0.0.1}
  if [ -z "$SHODAN_API_KEY" ]; then
    echo "${YELLOW}No SHODAN_API_KEY env var set. You can export it or run 'shodan init <APIKEY>'.${RESET}"
  fi
  printf "${CYAN}If you have Shodan CLI configured, this will run: shodan host %s${RESET}\n" "$TARGET"
  if confirm "Proceed with Shodan host lookup (requires configured CLI)?"; then
    shodan host "$TARGET"
  else
    echo "Skipping Shodan."
  fi
  pause
}

# Dispatch based on first argument
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
