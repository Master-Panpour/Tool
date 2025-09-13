#!/usr/bin/env bash
# run_port_scans.sh - executes the selected port scan types
# Copyright (C) 2025 Master_Panpour
# GPLv3: Free software, no warranty

# Colors
RESET="\033[0m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"

# Get target
read -rp "$(printf "${CYAN}Enter target IP/hostname (default: 127.0.0.1): ${RESET}")" TARGET
TARGET=${TARGET:-127.0.0.1}

# Remaining arguments are scan types
SCAN_SELECTED=("$@")

if [ "${#SCAN_SELECTED[@]}" -eq 0 ]; then
    echo "${YELLOW}[!] No scan types selected. Exiting.${RESET}"
    exit 1
fi

echo "${CYAN}[IronCrypt][PortScans] Target: $TARGET${RESET}"
echo "${CYAN}[IronCrypt][PortScans] Selected scan types: ${SCAN_SELECTED[*]}${RESET}"

# Check incompatible TCP scans
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
    echo "${RED}[!] Error: More than one TCP scan type selected. Only one allowed per run.${RESET}"
    exit 1
fi

# Map scan options to nmap flags
declare -a flags
for opt in "${SCAN_SELECTED[@]}"; do
    case "$opt" in
        "TCP Connect (-sT)") flags+=("-sT") ;;
        "SYN Scan (-sS)") flags+=("-sS") ;;
        "NULL Scan (-sN)") flags+=("-sN") ;;
        "FIN Scan (-sF)") flags+=("-sF") ;;
        "Xmas Scan (-sX)") flags+=("-sX") ;;
        "ACK Scan (-sA)") flags+=("-sA") ;;
        "UDP Scan (-sU)") flags+=("-sU") ;;
        *) echo "${YELLOW}[!] Warning: Unknown scan option: $opt${RESET}" ;;
    esac
done

# Add service version detection
flags+=("-sV")

# Output prefix
OUT_PREFIX="ironcrypt_ports_${TARGET//[:\/]/-}_$(date +%Y%m%d%H%M%S)"

# Run nmap scan
echo "${GREEN}[IronCrypt][PortScans] Running nmap with flags: ${flags[*]} on $TARGET${RESET}"
echo "${YELLOW}[!] Ensure you have permission. Root may be required for some flags.${RESET}"

nmap -Pn "${flags[@]}" -p- -oA "$OUT_PREFIX" "$TARGET"

echo "${GREEN}[IronCrypt][PortScans] Scan complete.${RESET}"
echo "${CYAN}Outputs: ${OUT_PREFIX}.nmap ${OUT_PREFIX}.gnmap ${OUT_PREFIX}.xml${RESET}"

# Pause before returning
read -rp "$(printf "${CYAN}Press Enter to return to scan menu...${RESET}")" _
