#!/usr/bin/env bash
# run_port_scans.sh - executes the selected port scan types

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

TARGET="$1"
# Actually the first argument here is the first scan option name, so better to shift
# But we expect TARGET to be provided as first positional later
# Let's parse

# First positional is target
if [ $# -lt 2 ]; then
  read -rp "Enter target IP/hostname (default: 127.0.0.1): " TARGET
  TARGET=${TARGET:-127.0.0.1}
  # The rest of arguments are scan type names
  # But our call from scan_menu.sh: args are scan options only. So we need to also include TARGET
  # For simplicity, assume args are scan options only
  SCAN_SELECTED=("${@:1}")  
else
  TARGET="$1"
  SCAN_SELECTED=("${@:2}")
fi

echo "[IronCrypt][PortScans] Target: $TARGET"
echo "[IronCrypt][PortScans] Selected scan types: ${SCAN_SELECTED[*]}"

# Check for incompatible scan types: more than one TCP scan among them?
# Define array of TCP scan types
tcp_scans_flags=(
  "TCP Connect (-sT)"
  "SYN Scan (-sS)"
  "NULL Scan (-sN)"
  "FIN Scan (-sF)"
  "Xmas Scan (-sX)"
  "ACK Scan (-sA)"
)

count_tcp=0
for opt in "${SCAN_SELECTED[@]}"; do
  for tcp in "${tcp_scans_flags[@]}"; do
    if [ "$opt" == "$tcp" ]; then
      ((count_tcp++))
    fi
  done
done

if [ "$count_tcp" -gt 1 ]; then
  echo "[!] Error: You selected more than one TCP scan type. Only one TCP scan type is allowed per run."
  exit 1
fi

# Build nmap flags
flags=()

for opt in "${SCAN_SELECTED[@]}"; do
  case "$opt" in
    "TCP Connect (-sT)") flags+=("-sT") ;;
    "SYN Scan (-sS)") flags+=("-sS") ;;
    "NULL Scan (-sN)") flags+=("-sN") ;;
    "FIN Scan (-sF)") flags+=("-sF") ;;
    "Xmas Scan (-sX)") flags+=("-sX") ;;
    "ACK Scan (-sA)") flags+=("-sA") ;;
    "UDP Scan (-sU)") flags+=("-sU") ;;
    *) echo "[!] Warning: Unknown scan option: $opt" ;;
  esac
done

# Add service version detection by default
flags+=("-sV")

# Construct output prefix
OUT_PREFIX="ironcrypt_ports_${TARGET//[:\/]/-}_$(date +%Y%m%d%H%M%S)"

echo "[IronCrypt][PortScans] Running nmap with flags: ${flags[*]} on $TARGET"
echo "[!] Ensure you have permission. Root may be required for some flags."

# Run scan
nmap -Pn "${flags[@]}" -p- -oA "$OUT_PREFIX" "$TARGET"

echo "[IronCrypt][PortScans] Scan complete. Outputs: ${OUT_PREFIX}.nmap ${OUT_PREFIX}.gnmap ${OUT_PREFIX}.xml"
