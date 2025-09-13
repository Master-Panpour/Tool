#!/usr/bin/env bash
# ironcrypt.sh - main launcher for IronCrypt
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

# ANSI color variables
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[1;31m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"

# Determine script base directory
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

# Print banner
print_banner() {
  clear
  printf "${RED}${BOLD}=====================================\n"
  printf "   IronCrypt — Recon CLI Tool\n"
  printf "=====================================\n${RESET}"
  printf "${CYAN}Port scanning & Web enumeration — organized, student lab tool${RESET}\n\n"
}

# Main menu options
options=(
  "Target Recon"
  "Port Scanning Options"
  "Web Enumeration Options"
  "DDOS (coming soon)"
  "XSS automation (coming soon)"
  "Exit"
)

# Main menu loop
while true; do
  print_banner
  PS3="${MAGENTA}Select an option (1-${#options[@]}): ${RESET}"
  select opt in "${options[@]}"; do
    case "$REPLY" in
      1)
        clear
        printf "${GREEN}Launching: Target Recon...${RESET}\n"
        sleep 1
        bash "$BASEDIR/target_recon/recon_menu.sh"
        break
        ;;
      2)
        clear
        printf "${GREEN}Opening Port Scanning Options...${RESET}\n"
        sleep 1
        bash "$BASEDIR/portscans/scan_menu.sh"
        break
        ;;
      3)
        clear
        printf "${GREEN}Opening Web Enumeration Options...${RESET}\n"
        sleep 1
        bash "$BASEDIR/web_enum/web_menu.sh"
        break
        ;;
      4)
        clear
        printf "${MAGENTA}DDOS feature: coming soon (placeholder)${RESET}\n"
        sleep 1
        break
        ;;
      5)
        clear
        printf "${MAGENTA}XSS automation: coming soon (placeholder)${RESET}\n"
        sleep 1
        break
        ;;
      6)
        clear
        printf "${CYAN}Goodbye from IronCrypt.${RESET}\n"
        exit 0
        ;;
      *)
        printf "${MAGENTA}Invalid option. Choose 1-${#options[@]}.${RESET}\n"
        sleep 1
        break
        ;;
    esac
  done
done
