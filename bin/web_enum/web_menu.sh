#!/usr/bin/env bash
# web_menu.sh - Web Enumeration Menu for IronCrypt (optimized + pause)
# Copyright (C) 2025 Master_Panpour
#
# GPLv3: Free software, no warranty.

# ANSI color variables
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

# Banner function
print_banner() {
  clear
  printf "${RED}${BOLD}=====================================\n"
  printf "   IronCrypt — Web Enumeration Menu\n"
  printf "=====================================\n${RESET}"
  printf "${CYAN}Choose your enumeration category (safe defaults for labs)${RESET}\n\n"
}

# Web enumeration options
web_options=(
  "Directory brute-force (gobuster/dirb)"
  "Subdomain enumeration (sublist3r/assetfinder)"
  "HTTP headers (curl -I)"
  "CMS detection (whatweb/wappalyzer)"
  "Virtual hosts enumeration (coming soon)"
  "SSL/TLS info"
  "Back to Main"
)

# Menu loop
while true; do
  print_banner
  PS3="${YELLOW}Select (1-${#web_options[@]}): ${RESET}"
  select opt in "${web_options[@]}"; do
    case "$REPLY" in
      1)
        clear
        printf "${GREEN}Starting: Directory brute-force...${RESET}\n"
        sleep 1
        bash "$BASEDIR/run_web_enum.sh" "dir"
        echo
        read -rp "Press Enter to return to Web Enumeration menu..." _
        break
        ;;
      2)
        clear
        printf "${GREEN}Starting: Subdomain enumeration...${RESET}\n"
        sleep 1
        bash "$BASEDIR/run_web_enum.sh" "subdomains"
        echo
        read -rp "Press Enter to return to Web Enumeration menu..." _
        break
        ;;
      3)
        clear
        printf "${GREEN}Starting: HTTP headers analysis...${RESET}\n"
        sleep 1
        bash "$BASEDIR/run_web_enum.sh" "headers"
        echo
        read -rp "Press Enter to return to Web Enumeration menu..." _
        break
        ;;
      4)
        clear
        printf "${GREEN}Starting: CMS detection...${RESET}\n"
        sleep 1
        bash "$BASEDIR/run_web_enum.sh" "cms"
        echo
        read -rp "Press Enter to return to Web Enumeration menu..." _
        break
        ;;
      5)
        clear
        printf "${MAGENTA}Virtual hosts enumeration: Coming soon.${RESET}\n"
        sleep 1
        read -rp "Press Enter to return to Web Enumeration menu..." _
        break
        ;;
      6)
        clear
        printf "${GREEN}Starting: SSL/TLS info...${RESET}\n"
        sleep 1
        bash "$BASEDIR/run_web_enum.sh" "ssl"
        echo
        read -rp "Press Enter to return to Web Enumeration menu..." _
        break
        ;;
      7)
        printf "${CYAN}Returning to main menu...${RESET}\n"
        sleep 1
        exit 0
        ;;
      *)
        printf "${YELLOW}Invalid choice. Choose 1-${#web_options[@]}.${RESET}\n"
        sleep 1
        break
        ;;
    esac
  done
done
