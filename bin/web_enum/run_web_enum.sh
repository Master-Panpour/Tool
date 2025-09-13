#!/usr/bin/env bash
# run_web_enum.sh - Execute web enumeration based on selected category
# Copyright (C) 2025 Master_Panpour
#
# GPLv3: Free software, no warranty.

# ANSI colors
RESET="\033[0m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"

CATEGORY="$1"
DEFAULT_URL="http://127.0.0.1:8080"
DEFAULT_WORDLIST="../../wordlists/rockyou.txt"

# Prompt for target URL
read -rp "Enter target base URL (default: $DEFAULT_URL): " TARGET
TARGET=${TARGET:-$DEFAULT_URL}

echo -e "${CYAN}[IronCrypt][WebEnum] Selected category: $CATEGORY${RESET}"

case "$CATEGORY" in
  "dir")
    # Directory/File brute-force
    read -rp "Enter wordlist path (default: $DEFAULT_WORDLIST): " WORDLIST
    WORDLIST=${WORDLIST:-$DEFAULT_WORDLIST}

    echo -e "${GREEN}[IronCrypt][WebEnum] Directory/File enumeration using wordlist $WORDLIST${RESET}"

    if command -v ffuf >/dev/null 2>&1; then
      OUT="ironcrypt_ffuf_dir_$(echo "$TARGET" | sed 's/[:\/]/_/g')_$(date +%s).json"
      ffuf -w "$WORDLIST":FUZZ -u "${TARGET%/}/FUZZ" -mc 200,301,302,403 -fc 404 -of json -o "$OUT"
      echo -e "${GREEN}[IronCrypt][WebEnum] Completed. Output: $OUT${RESET}"
    elif command -v gobuster >/dev/null 2>&1; then
      OUT="ironcrypt_gobuster_dir_$(echo "$TARGET" | sed 's/[:\/]/_/g')_$(date +%s).txt"
      gobuster dir -u "${TARGET%/}/" -w "$WORDLIST" -o "$OUT"
      echo -e "${GREEN}[IronCrypt][WebEnum] Completed. Output: $OUT${RESET}"
    else
      echo -e "${RED}[!] Neither ffuf nor gobuster installed.${RESET}"
      exit 2
    fi
    ;;

  "subdomains")
    echo -e "${GREEN}[IronCrypt][WebEnum] Running Subdomain Enumeration...${RESET}"
    if command -v sublist3r >/dev/null 2>&1; then
      OUT="ironcrypt_sublist3r_$(echo "$TARGET" | sed 's/[:\/]/_/g')_$(date +%s).txt"
      sublist3r -d "$(echo "$TARGET" | sed 's|https://||; s|http://||')" -o "$OUT"
      echo -e "${GREEN}[IronCrypt][WebEnum] Completed. Output: $OUT${RESET}"
    elif command -v assetfinder >/dev/null 2>&1; then
      OUT="ironcrypt_assetfinder_$(echo "$TARGET" | sed 's|https://||; s|http://||')_$(date +%s).txt"
      assetfinder "$(echo "$TARGET" | sed 's|https://||; s|http://||')" > "$OUT"
      echo -e "${GREEN}[IronCrypt][WebEnum] Completed. Output: $OUT${RESET}"
    else
      echo -e "${RED}[!] Neither sublist3r nor assetfinder installed.${RESET}"
      exit 2
    fi
    ;;

  "headers")
    echo -e "${GREEN}[IronCrypt][WebEnum] Fetching HTTP headers and allowed methods${RESET}"
    curl -I "$TARGET"
    echo
    echo -e "${GREEN}[IronCrypt][WebEnum] Checking allowed HTTP methods using OPTIONS${RESET}"
    curl -X OPTIONS "$TARGET" -i
    ;;

  "cms")
    echo -e "${GREEN}[IronCrypt][WebEnum] CMS detection using whatweb/wappalyzer${RESET}"
    if command -v whatweb >/dev/null 2>&1; then
      whatweb "$TARGET"
    elif command -v wappalyzer >/dev/null 2>&1; then
      wappalyzer "$TARGET"
    else
      echo -e "${RED}[!] Neither whatweb nor wappalyzer installed.${RESET}"
      exit 2
    fi
    ;;

  "ssl")
    echo -e "${GREEN}[IronCrypt][WebEnum] SSL/TLS info category${RESET}"
    HOST=$(echo "$TARGET" | sed 's|https://||; s|http://||')
    if command -v openssl >/dev/null 2>&1; then
      echo -e "${GREEN}[IronCrypt][WebEnum] Using openssl to fetch certificate details${RESET}"
      openssl s_client -connect "$HOST":443 -showcerts </dev/null
    elif command -v nmap >/dev/null 2>&1; then
      echo -e "${GREEN}[IronCrypt][WebEnum] Using nmap ssl-cert script${RESET}"
      nmap --script ssl-cert -p 443 "$HOST"
    else
      echo -e "${RED}[!] Neither openssl nor nmap installed.${RESET}"
      exit 2
    fi
    ;;

  *)
    echo -e "${RED}[!] Unknown web enum category: $CATEGORY${RESET}"
    exit 1
    ;;
esac
