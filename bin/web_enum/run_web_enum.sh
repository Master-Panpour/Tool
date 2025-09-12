#!/usr/bin/env bash
# run_web_enum.sh - handles analyzed web enumeration based on category

CATEGORY="$1"
DEFAULT_URL="http://127.0.0.1:8080"
DEFAULT_WORDLIST="../../wordlists/rockyou.txt"

read -rp "Enter target base URL (default: $DEFAULT_URL): " TARGET
TARGET=${TARGET:-$DEFAULT_URL}

echo "[IronCrypt][WebEnum] Selected category: $CATEGORY"

case "$CATEGORY" in
  "dir")
    read -rp "Enter wordlist path (default: $DEFAULT_WORDLIST): " WORDLIST
    WORDLIST=${WORDLIST:-$DEFAULT_WORDLIST}

    echo "[IronCrypt][WebEnum] Directory/File enumeration using wordlist $WORDLIST"
    if command -v ffuf >/dev/null 2>&1; then
      OUT="ironcrypt_ffuf_dir_$(echo "$TARGET" | sed 's/[:\/]/_/g')_$(date +%s).json"
      ffuf -w "$WORDLIST":FUZZ -u "${TARGET%/}/FUZZ" -mc 200,301,302,403 -fc 404 -of json -o "$OUT"
      echo "[IronCrypt][WebEnum] Completed. Output: $OUT"
    elif command -v gobuster >/dev/null 2>&1; then
      OUT="ironcrypt_gobuster_dir_$(echo "$TARGET" | sed 's/[:\/]/_/g')_$(date +%s).txt"
      gobuster dir -u "${TARGET%/}/" -w "$WORDLIST" -o "$OUT"
      echo "[IronCrypt][WebEnum] Completed. Output: $OUT"
    else
      echo "[!] Neither ffuf nor gobuster installed."
      exit 2
    fi
    ;;
  "headers")
    # simple headers/methods enumeration
    echo "[IronCrypt][WebEnum] Fetching HTTP headers and allowed methods"
    # use curl
    curl -I "$TARGET"
    echo
    echo "[IronCrypt][WebEnum] Check for allowed HTTP methods using OPTIONS"
    curl -X OPTIONS "$TARGET" -i
    ;;
  "ssl")
    echo "[IronCrypt][WebEnum] SSL/TLS info category"
    # need openssl or nmap
    if command -v openssl >/dev/null 2>&1; then
      echo "[IronCrypt][WebEnum] Using openssl to fetch cert details"
      openssl s_client -connect "$(echo "$TARGET" | sed 's|https://||; s|http://||')":443 -showcerts </dev/null
    else
      echo "[!] openssl not found. You can use nmap -sV --script ssl-cert etc."
    fi
    ;;
  *)
    echo "[!] Unknown web enum category: $CATEGORY"
    ;;
esac
