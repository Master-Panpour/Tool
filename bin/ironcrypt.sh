#!/usr/bin/env bash
# ironcrypt.sh - main launcher for IronCrypt (uses a banner function instead of goto)

# single-line comment: ANSI color variables for styling
RESET="\033[0m"         # reset colors
BOLD="\033[1m"          # bold text
RED="\033[1;31m"        # bright red (banner)
CYAN="\033[1;36m"       # cyan (subtitle)
GREEN="\033[1;32m"      # green (action/info)
YELLOW="\033[1;33m"     # yellow (prompts)
MAGENTA="\033[1;35m"    # magenta (secondary)

# single-line comment: determine script base directory
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

# single-line comment: function to print the banner + subtitle (acts like your 'goto' target)
print_banner() {
  clear                                            # single-line comment: clear terminal before banner
  printf "${RED}${BOLD}=====================================\n"
  printf "   IronCrypt — Recon CLI Tool\n"
  printf "=====================================\n${RESET}"
  printf "${CYAN}Port scanning & Web enumeration — organized, student lab tool${RESET}\n\n"
}

# single-line comment: call banner initially to show UI
print_banner

# single-line comment: PS3 prompt shown by select (colored)
PS3="${YELLOW}Select an option (1-6): ${RESET}"

# single-line comment: menu options include Target Recon as 1
options=(
  "Target Recon"
  "Port Scanning Options"
  "Web Enumeration Options"
  "DDOS (coming soon)"
  "XSS automation (coming soon)"
  "Exit"
)

# single-line comment: present menu and handle choices
select opt in "${options[@]}"; do
  case "$REPLY" in
    1)
      clear
      printf "${GREEN}Launching: Target Recon...${RESET}\n"
      # single-line comment: call target recon script (create it at bin/target_recon.sh)
      "$BASEDIR/target_recon/recon_menu.sh"
      break
      ;;
    2)
      clear
      printf "${GREEN}Opening Port Scanning Options...${RESET}\n"
      # single-line comment: call portscans submenu
      "$BASEDIR/portscans/scan_menu.sh"
      break
      ;;
    3)
      clear
      printf "${GREEN}Opening Web Enumeration Options...${RESET}\n"
      # single-line comment: call web enumeration submenu
      "$BASEDIR/web_enum/web_menu.sh"
      break
      ;;
    4)
      clear
      printf "${MAGENTA}DDOS feature: coming soon (intentionally not implemented).${RESET}\n"
      "$BASEDIR/ddos_stub.sh"
      break
      ;;
    5)
      clear
      printf "${MAGENTA}XSS automation: coming soon (placeholder).${RESET}\n"
      "$BASEDIR/xss_stub.sh"
      break
      ;;
    6)
      clear
      printf "${CYAN}Goodbye from IronCrypt.${RESET}\n"
      exit 0
      ;;
    *)
      # single-line comment: invalid selection - show short message, pause, then reprint banner using function
      printf "${YELLOW}Invalid option. Choose a number between 1 and ${#options[@]}.${RESET}\n"
      sleep 1
      print_banner
      ;;
  esac
done
