#!/usr/bin/env bash
# scan_menu.sh - select which port scan types to run (uses banner function + colors)

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

# single-line comment: determine base directory for this script
BASEDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASEDIR" || exit 1

# single-line comment: function to print a small banner for the portscans menu
print_banner() {
  clear                                          # single-line comment: clear terminal before banner
  printf "${RED}${BOLD}=====================================\n"
  printf "   IronCrypt — Port Scanning Menu\n"
  printf "=====================================\n${RESET}"
  printf "${CYAN}Select scan types (you may add multiple; only one TCP scan type allowed per run)${RESET}\n\n"
}

# single-line comment: show banner initially
print_banner

# single-line comment: available scan options array
scan_options=(
  "TCP Connect (-sT)"
  "SYN Scan (-sS)"
  "NULL Scan (-sN)"
  "FIN Scan (-sF)"
  "Xmas Scan (-sX)"
  "ACK Scan (-sA)"
  "UDP Scan (-sU)"
  "Back to Main"
)

# single-line comment: collect user selections here
declare -a SELECTED=()

# single-line comment: present numbered menu using select for clarity
PS3="${YELLOW}Enter choice number (or ${#scan_options[@]} to go back): ${RESET}"
select opt in "${scan_options[@]}"; do
  # single-line comment: if user chose "Back to Main", exit menu
  if [ "$REPLY" -eq "${#scan_options[@]}" ]; then
    print_banner
    echo "${MAGENTA}Returning to main menu...${RESET}"
    sleep 1
    exit 0
  fi

  # single-line comment: validate selection and add to SELECTED array
  if [[ -n "$opt" ]]; then
    SELECTED+=("$opt")
    echo "${GREEN}Added:${RESET} $opt"
  else
    echo "${YELLOW}Invalid choice:${RESET} $REPLY"
  fi

  # single-line comment: show current selections in one line
  if [ "${#SELECTED[@]}" -gt 0 ]; then
    printf "${CYAN}Current selection:${RESET} "
    printf "%s" "${SELECTED[0]}"
    for ((i=1; i<${#SELECTED[@]}; i++)); do
      printf " ${GREEN}+${RESET} %s" "${SELECTED[i]}"
    done
    printf "\n"
  else
    echo "${CYAN}No selections yet.${RESET}"
  fi

  # single-line comment: allow user to continue selecting or press Enter to run
  read -rp "$(printf "${YELLOW}Select more (press Enter to run with current selection): ${RESET}")" more
  if [ -z "$more" ]; then
    break
  fi

  # single-line comment: reprint banner so UI stays tidy while selecting more
  print_banner
  echo "${CYAN}Current selection: ${RESET}${SELECTED[*]}"
  echo "${MAGENTA}Continue selecting...${RESET}"
done

# single-line comment: if no selections were made, inform and go back
if [ "${#SELECTED[@]}" -eq 0 ]; then
  echo "${YELLOW}No scan types selected. Returning to main menu.${RESET}"
  sleep 1
  exit 0
fi

# single-line comment: call the runner script with all selected options
"$BASEDIR/run_port_scans.sh" "${SELECTED[@]}"
