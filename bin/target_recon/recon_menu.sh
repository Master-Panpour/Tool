#!/usr/bin/env bash
# recon_menu.sh - Target Recon Menu for IronCrypt
# Copyright (C) 2025 Master_Panpour
#
# GPLv3: Free software, no warranty.

# ANSI colors
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[1;31m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"

# Directory of this script
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

# Banner
print_banner() {
  clear
  printf "${RED}${BOLD}=====================================\n"
  printf "   IronCrypt — Target Recon Menu\n"
  printf "=====================================\n${RESET}"
  printf "${CYAN}Choose a recon action (tools will prompt before running).${RESET}\n\n"
}

# Options
options=(
  "IP / Host basic info (geo, ASN)"
  "DNS lookups (dig)"
  "Whois (domain/IP ownership)"
  "HTTP headers (curl -I)"
  "SSL/TLS cert info (openssl)"
  "Ping"
  "Traceroute"
  "Quick Nmap (top ports)"
  "Shodan (requires API key - optional)"
  "Back to Main"
)

# Menu loop
while true; do
  print_banner
  PS3="${MAGENTA}Select (1-${#options[@]}): ${RESET}"
  select opt in "${options[@]}"; do
    case "$REPLY" in
      1) clear; printf "${GREEN}Running: IP / Host basic info...${RESET}\n"; sleep 1; bash "$BASEDIR/recon_tools.sh" ipinfo; read -rp "Press Enter to return to Target Recon menu..." _; break ;;
      2) clear; printf "${GREEN}Running: DNS lookups (dig)...${RESET}\n"; sleep 1; bash "$BASEDIR/recon_tools.sh" dig; read -rp "Press Enter to return to Target Recon menu..." _; break ;;
      3) clear; printf "${GREEN}Running: Whois...${RESET}\n"; sleep 1; bash "$BASEDIR/recon_tools.sh" whois; read -rp "Press Enter to return to Target Recon menu..." _; break ;;
      4) clear; printf "${GREEN}Running: HTTP headers...${RESET}\n"; sleep 1; bash "$BASEDIR/recon_tools.sh" headers; read -rp "Press Enter to return to Target Recon menu..." _; break ;;
      5) clear; printf "${GREEN}Running: SSL/TLS cert info...${RESET}\n"; sleep 1; bash "$BASEDIR/recon_tools.sh" ssl; read -rp "Press Enter to return to Target Recon menu..." _; break ;;
      6) clear; printf "${GREEN}Running: Ping...${RESET}\n"; sleep 1; bash "$BASEDIR/recon_tools.sh" ping; read -rp "Press Enter to return to Target Recon menu..." _; break ;;
      7) clear; printf "${GREEN}Running: Traceroute...${RESET}\n"; sleep 1; bash "$BASEDIR/recon_tools.sh" traceroute; read -rp "Press Enter to return to Target Recon menu..." _; break ;;
      8) clear; printf "${GREEN}Running: Quick Nmap scan...${RESET}\n"; sleep 1; bash "$BASEDIR/recon_tools.sh" nmap_quick; read -rp "Press Enter to return to Target Recon menu..." _; break ;;
      9) clear; printf "${MAGENTA}Shodan (optional)...${RESET}\n"; sleep 1; bash "$BASEDIR/recon_tools.sh" shodan; read -rp "Press Enter to return to Target Recon menu..." _; break ;;
      10) printf "${CYAN}Returning to main menu...${RESET}\n"; sleep 1; exit 0 ;;
      *) printf "${MAGENTA}Invalid choice. Choose 1-${#options[@]}.${RESET}\n"; sleep 1; break ;;
    esac
  done
done
