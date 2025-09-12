#!/usr/bin/env bash
# ironcrypt.sh - main launcher for IronCrypt

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
clear
cat <<'BANNER'
=====================================
   IronCrypt — Recon CLI Tool
   Port scanning & Web enumeration
   Organized scan types & categories
   Other options: Coming soon
=====================================
BANNER

PS3="Select an option (1-5): "
options=(
  "Port Scanning Options"
  "Web Enumeration Options"
  "DDOS (coming soon)"
  "XSS automation (coming soon)"
  "Exit"
)

select opt in "${options[@]}"; do
  case "$REPLY" in
    1) "$BASEDIR/portscans/scan_menu.sh" ; break ;;
    2) "$BASEDIR/web_enum/web_menu.sh" ; break ;;
    3) "$BASEDIR/ddos_stub.sh" ; break ;;
    4) "$BASEDIR/xss_stub.sh" ; break ;;
    5) echo "Goodbye from IronCrypt." ; exit 0 ;;
    *) echo "Invalid option. Choose 1-5." ;;
  esac
done
