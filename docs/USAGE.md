---

## docs/USAGE.md

```markdown
# USAGE — IronCrypt

This document walks through how to use IronCrypt: how to run it, which options are available, examples.

---

## 🎮 Running IronCrypt

From project root:

```bash
cd IronCrypt
./bin/ironcrypt.sh

---

You will see a menu:

 -Port Scanning Options
 -Web Enumeration Options
 -DDOS (coming soon)
 -XSS Automation (coming soon)
 -Exit

Select one by entering the number.

---

## 🌐 Port Scanning Options

When you pick Port Scanning Options, you’ll be taken to a submenu:

 -You can pick one or more scan types from:

    > TCP-Connect (-sT)
    > SYN (-sS)
    > NULL (-sN)
    > FIN (-sF)
    > Xmas (-sX)
    > ACK (-sA)
    > UDP (-sU)

 -Rules / compatibility:

    > Only one TCP scan type can be selected per run (e.g. you can choose -sS or -sT but not both together).

    > You can combine a TCP scan type with -sU (UDP) in the same run.

After selecting scan types, you will be asked for:

 -target IP or hostname (default: 127.0.0.1)

 -confirmation (permission prompt)

Then IronCrypt runs nmap with the appropriate flags, scanning all ports (-p-) and doing service version detection (-sV). The output files are saved with a timestamp and target in their names (prefix like ironcrypt_ports_<target>_<timestamp>).

---

## 🌐 Web Enumeration Options

When you pick Web Enumeration Options, you’ll get a submenu of categories:

| Category                        | What it does                                                                                                           |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Directory/File enumeration      | Uses wordlists (e.g. `rockyou.txt` or `small.txt`) with `ffuf` or `gobuster` to find hidden paths/files on the server. |
| HTTP headers / methods analysis | Fetches HTTP headers, runs `OPTIONS` request to see allowed methods.                                                   |
| SSL/TLS info                    | Uses `openssl` (or fallback) to fetch the server certificate, cipher suites etc.                                       |

After choosing category, you will be prompted for:

 -base URL (default http://127.0.0.1:8080)
 -if applicable: path to wordlist

Outputs:

 -Directory enumeration → output file (json or txt) with prefix ironcrypt_ffuf_dir_... or ironcrypt_gobuster_dir_...
 -For headers / methods → printed to console
 -For SSL/TLS → certificate details printed

 ---

## ⚠️Troubleshooting

- If ffuf or gobuster is not found → make sure installed and in $PATH.
- If nmap flags cause “permission denied” or require root → run with sudo for some scan types.
- For SSL/TLS info, ensure the target supports HTTPS; if port isn’t 443 you may need to specify correct port.