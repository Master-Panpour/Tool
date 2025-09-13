#!/usr/bin/env bash
# web_menu.sh - select web enumeration categories (uses banner function + colors)

# ANSI color variables
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[1;31m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"

# determine base directory for this script
BASEDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASEDIR" || exit 1

# function to print the small banner for web enum menu
print_banner() {
  clear                                      # clear terminal before banner
  printf "${RED}${BOLD}=====================================\n"
  printf "   IronCrypt — Web Enumeration Menu\n"
  printf "=====================================\n${RESET}"
  printf "${CYAN}Choose your enumeration category (safe defaults for labs){RESET}\n\n"
}

# show banner initially
print_banner

# available web enumeration options
web_options=(
  "Directory/File enumeration"
  "Virtual hosts enumeration (coming soon)"
  "Subdomain enumeration (coming soon)"
  "HTTP headers / methods analysis"
  "SSL/TLS info"
  "Back to Main"
)

# present menu using select
PS3="${YELLOW}Select (1-6): ${RESET}"
select opt in "${web_options[@]}"; do
  case "$REPLY" in
    1)
      clear
      printf "${GREEN}Starting: Directory/File enumeration...${RESET}\n"
      # call the directory enumeration handler in run_web_enum.sh
      "$BASEDIR/run_web_enum.sh" "dir"
      break
      ;;
    2)
      clear
      printf "${MAGENTA}Virtual hosts enumeration: Coming soon.${RESET}\n"
      # placeholder: can later call a script for vhost enumeration
      break
      ;;
    3)
      clear
      printf "${MAGENTA}Subdomain enumeration: Coming soon.${RESET}\n"
      # placeholder: add subdomain tooling later (e.g., amass, subfinder)
      break
      ;;
    4)
      clear
      printf "${GREEN}Starting: HTTP headers / methods analysis...${RESET}\n"
      "$BASEDIR/run_web_enum.sh" "headers"
      break
      ;;
    5)
      clear
      printf "${GREEN}Starting: SSL/TLS info...${RESET}\n"
      "$BASEDIR/run_web_enum.sh" "ssl"
      break
      ;;
    6)
      # back to main
      print_banner
      printf "${CYAN}Returning to main menu...${RESET}\n"
      sleep 1
      exit 0
      ;;
    *)
      # invalid choice — show message, pause, and reprint banner using function
      printf "${YELLOW}Invalid choice. Choose 1-${#web_options[@]}.${RESET}\n"
      sleep 1
      print_banner
      ;;
  esac
done
