#!/usr/bin/env bash
# web_menu.sh - select web enumeration categories

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASEDIR" || exit 1

echo "[IronCrypt][WebEnum] Choose your enumeration category:"

web_options=(
  "Directory/File enumeration"
  "Virtual hosts enumeration (coming soon)"
  "Subdomain enumeration (coming soon)"
  "HTTP headers / methods analysis"
  "SSL/TLS info"
  "Back to Main"
)

PS3="Select (1-6): "

select opt in "${web_options[@]}"; do
  case "$REPLY" in
    1) "$BASEDIR/run_web_enum.sh" "dir" ; break ;;
    2) echo "[IronCrypt][WebEnum] Virtual hosts enumeration: Coming soon."; break ;;
    3) echo "[IronCrypt][WebEnum] Subdomain enumeration: Coming soon."; break ;;
    4) "$BASEDIR/run_web_enum.sh" "headers" ; break ;;
    5) "$BASEDIR/run_web_enum.sh" "ssl" ; break ;;
    6) exit 0 ;;
    *) echo "Invalid choice. Choose 1-6." ;;
  esac
done
