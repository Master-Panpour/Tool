#!/usr/bin/env bash
# scan_menu.sh - select which port scan types to run

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASEDIR" || exit 1

echo "[IronCrypt][PortScans] Select scan types (you may select more than one, but only one TCP scan type):"

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

# to collect choices
declare -a SELECTED
PS3="Enter choice numbers separated by space (e.g. 1 2 7): "

# Show menu
select opt in "${scan_options[@]}"; do
  if [ "$REPLY" == "${#scan_options[@]}" ]; then
    # Back
    exit 0
  elif [[ " ${scan_options[*]} " == *"$opt"* ]]; then
    SELECTED+=("$opt")
    echo "Added: $opt"
  else
    echo "Invalid choice: $REPLY"
  fi
  echo "Current selection: ${SELECTED[*]}"
  read -rp "Select more or press Enter to run with current selection: " more
  if [ -z "$more" ]; then
    break
  fi
  echo "Continue selecting..."
done

# Now run port scans with run_port_scans.sh
"$BASEDIR/run_port_scans.sh" "${SELECTED[@]}"
