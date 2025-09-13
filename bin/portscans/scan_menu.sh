#!/usr/bin/env bash
# scan_menu.sh - select which port scan types to run (uses banner function + colors)
# Copyright (C) 2025 Master_Panpour
# GPLv3: Free software, no warranty

# Colors
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[1;31m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"

# Base directory
BASEDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASEDIR" || exit 1

# Banner
print_banner() {
  clear
  printf "${RED}${BOLD}=====================================\n"
  printf "   IronCrypt — Port Scanning Menu\n"
  printf "=====================================\n${RESET}"
  printf "${CYAN}Select scan types (multiple allowed; only one TCP scan type per run)${RESET}\n\n"
}

# Pause helper
pause() {
  read -rp "$(printf "${CYAN}Press Enter to return to menu...${RESET}")" _
}

# Scan options
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

# User selections
declare -a SELECTED=()

# Show banner initially
print_banner

# Selection loop
while true; do
  PS3="${YELLOW}Enter choice number (or ${#scan_options[@]} to go back): ${RESET}"
  select opt in "${scan_options[@]}"; do
    # Back to main
    if [ "$REPLY" -eq "${#scan_options[@]}" ]; then
      print_banner
      echo "${MAGENTA}Returning to main menu...${RESET}"
      sleep 1
      exit 0
    fi

    # Add valid selection
    if [[ -n "$opt" ]]; then
      SELECTED+=("$opt")
      echo "${GREEN}Added:${RESET} $opt"
    else
      echo "${YELLOW}Invalid choice:${RESET} $REPLY"
    fi

    # Show current selection
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

    # Allow more selection or run
    read -rp "$(printf "${YELLOW}Select more (press Enter to run with current selection): ${RESET}")" more
    if [ -z "$more" ]; then
      break
    fi

    # Reprint banner for tidy UI
    print_banner
    echo "${CYAN}Current selection: ${RESET}${SELECTED[*]}"
    echo "${MAGENTA}Continue selecting...${RESET}"
  done
  break
done

# If nothing selected
if [ "${#SELECTED[@]}" -eq 0 ]; then
  echo "${YELLOW}No scan types selected. Returning to main menu.${RESET}"
  sleep 1
  exit 0
fi

# Run scans and pause after completion
"$BASEDIR/run_port_scans.sh" "${SELECTED[@]}"
pause
