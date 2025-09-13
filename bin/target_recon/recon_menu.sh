#!/usr/bin/env bash
# target_recon.sh - Target reconnaissance menu for IronCrypt (fixed: no immediate calls)

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

# single-line comment: ANSI color variables
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[1;31m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"

# single-line comment: determine directory of this script so other scripts are found reliably
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

# single-line comment: function to print the banner (acts like a goto target)
print_banner() {
  clear
  printf "${RED}${BOLD}=====================================\n"
  printf "   IronCrypt — Target Recon Menu\n"
  printf "=====================================\n${RESET}"
  printf "${CYAN}Choose a recon action (tools will prompt before running).${RESET}\n\n"
}

# single-line comment: list of recon options
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

# single-line comment: show banner then present menu
print_banner
PS3="${YELLOW}Select (1-${#options[@]}): ${RESET}"
select opt in "${options[@]}"; do
  case "$REPLY" in
    1)
      clear
      printf "${GREEN}Running: IP / Host basic info...${RESET}\n"
      "$BASEDIR/recon_tools.sh" ipinfo
      break
      ;;
    2)
      clear
      printf "${GREEN}Running: DNS lookups (dig)...${RESET}\n"
      "$BASEDIR/recon_tools.sh" dig
      break
      ;;
    3)
      clear
      printf "${GREEN}Running: whois...${RESET}\n"
      "$BASEDIR/recon_tools.sh" whois
      break
      ;;
    4)
      clear
      printf "${GREEN}Running: HTTP headers...${RESET}\n"
      "$BASEDIR/recon_tools.sh" headers
      break
      ;;
    5)
      clear
      printf "${GREEN}Running: SSL/TLS cert info...${RESET}\n"
      "$BASEDIR/recon_tools.sh" ssl
      break
      ;;
    6)
      clear
      printf "${GREEN}Running: ping...${RESET}\n"
      "$BASEDIR/recon_tools.sh" ping
      break
      ;;
    7)
      clear
      printf "${GREEN}Running: traceroute...${RESET}\n"
      "$BASEDIR/recon_tools.sh" traceroute
      break
      ;;
    8)
      clear
      printf "${GREEN}Running: quick nmap...${RESET}\n"
      "$BASEDIR/recon_tools.sh" nmap_quick
      break
      ;;
    9)
      clear
      printf "${MAGENTA}Shodan (optional)...${RESET}\n"
      "$BASEDIR/recon_tools.sh" shodan
      break
      ;;
    10)
      clear
      printf "${CYAN}Returning to main menu...${RESET}\n"
      sleep 1
      exit 0
      ;;
    *)
      printf "${YELLOW}Invalid choice. Choose 1-${#options[@]}.${RESET}\n"
      sleep 1
      print_banner
      ;;
  esac
done
