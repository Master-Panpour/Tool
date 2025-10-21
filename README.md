# IronCrypt

IronCrypt is a CLI reconnaissance & enumeration toolkit for **educational / lab / research use**.  
It provides organized, menu-driven workflows for **target reconnaissance**, **port scanning**, and **web enumeration**, plus helper scripts for permission automation and optional safe auto-update behavior. Other red-team features (DDOS, XSS, etc.) are intentionally stubbed as “coming soon”.

---

## Features (quick)

- **Target Recon** — IP/ASN geolocation, DNS lookups, whois, HTTP headers, SSL cert inspection, ping, traceroute, quick nmap.  
- **Port Scanning** — Multiple scan types (TCP-Connect, SYN, NULL, FIN, Xmas, ACK, UDP) with compatibility checks so you don’t accidentally combine incompatible TCP scan types.  
- **Web Enumeration** — directory/file fuzzing (ffuf / gobuster), HTTP headers/methods analysis, TLS/SSL inspection.  
- **Permissions automation** — `required_perms.sh` automates `chmod +x` for project scripts and (when in a git repo) records the executable bit in the git index.  
- **Safe Auto-Update (opt-in)** — `required_perms.sh` can check/pull updates from the repo (git preferred). If enabled and allowed, it can offer a raw-download fallback that prompts and shows diffs before replacing the script.

> Run IronCrypt only in lab/CTF environments or on systems you own and have explicit written permission to test. Unauthorized scanning or attacks are illegal.

**Notes / authoritative references:** Nmap is used for port/service/version detection, ffuf is the fast web fuzzer used for directory discovery, SecLists is the recommended curated collection of wordlists, Kali provides a `wordlists` package containing `rockyou.txt.gz`, and to record executable bit changes in git use `git update-index --chmod=+x`.

---

## Project layout:
   <pre>
   IronCrypt/
   ├── README.md
   ├── LICENSE
   ├── deps.txt
   ├── .gitignore
   ├── required_perms.sh # make scripts executable + optional auto-update
   ├── bin/
   │ ├── ironcrypt.sh
   │ ├── ddos_stub.sh
   │ ├── xss_stub.sh
   │ ├── other_stub.sh
   │ ├── portscans/
   │ │ ├── scan_menu.sh
   │ │ └── run_port_scans.sh
   │ ├── web_enum/
   │ │ ├── web_menu.sh
   │ │ └── run_web_enum.sh
   │ └── target_recon/
   │ ├── recon_menu.sh
   │ └── recon_tools.sh
   ├── wordlists/
   │ ├── small.txt
   │ └── rockyou.txt # large — keep out of git or use Git LFS / external host
   └── docs/
   ├── USAGE.md
   └── SCAN_TYPES.md</pre>

---

## ⚠️ Important: Legal & Permission Notice

Only run scans or tests against systems you own or have **explicit written permission** to test. Unauthorized scanning or attacks are illegal in many jurisdictions. Use this tool responsibly in labs, CTFs, or environments that permit security testing.


---

## Setup (quick)

1. **Clone the repo:**
   ```bash
   git clone https://github.com/Master-Panpour/Tool.git IronCrypt
   cd IronCrypt
2. **Install dependencies:**
   ```bash
   sudo apt update
   sudo apt install -y nmap whois dnsutils curl openssl traceroute jq
for web enumeration: install gobuster or ffuf (ffuf can be installed via `go install github.com/ffuf/ffuf/v2@latest`)
3. **Make the helper executable and preview/apply permissions:**
<pre>chmod +x required_perms.sh 
# Preview (no changes) 
./required_perms.sh --dry 
# Apply permissions 
./required_perms.sh 
# Enable safe git-based auto-update check during run (opt-in) 
AUTO_UPDATE=1 ./required_perms.sh</pre>
---

## Contributing & roadmap

- Pull requests welcome — open PRs against main.

- Planned improvements: non-interactive CLI flags, JSON/HTML reporting, subdomain/vhost enumeration, improved logging, optional GPG verification for auto-update.