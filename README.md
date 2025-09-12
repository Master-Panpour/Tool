# IronCrypt

IronCrypt is a CLI reconnaissance tool made for educational / lab / practice use in cybersecurity.  
It provides organized options for port scanning and web enumeration. Other red-team features are stubbed out (“coming soon”).

---

## ⚙️ Features

- **Port Scanning** with multiple scan types (TCP-Connect, SYN, NULL, FIN, Xmas, ACK, UDP).  
- Ability to *combine* one TCP scan type with UDP scan together, respecting compatibility.  
- **Web Enumeration** with categories like directory enumeration, HTTP headers/methods check, TLS/SSL info.  
- Wordlists support, including `rockyou.txt` and a small sample for quick tests.  
- Clear user prompts, safe defaults, and warnings about legal and ethical use.

---

## 📦 Dependencies

- `nmap`  
- `gobuster`  
- Optionally `ffuf` (via Go)  
- `openssl` (for SSL/TLS info)  
- Wordlists: sample `small.txt` + `rockyou.txt` (if using large enumeration)  

---

## 📁 Project Structure

IronCrypt/
├── README.md
├── LICENSE
├── deps.txt
├── bin/
│ ├── ironcrypt.sh
│ ├── portscans/
│ │ ├── scan_menu.sh
│ │ └── run_port_scans.sh
│ ├── web_enum/
│ │ ├── web_menu.sh
│ │ └── run_web_enum.sh
│ ├── ddos_stub.sh
│ ├── xss_stub.sh
│ └── other_stub.sh
├── wordlists/
│ ├── small.txt
│ └── rockyou.txt
└── docs/
├── USAGE.md
└── SCAN_TYPES.md

---



## ⚠️ Important: Legal & Permission Notice

Only run scans or tests against systems you own or have **explicit written permission** to test. Unauthorized scanning or attacks are illegal in many jurisdictions. Use this tool responsibly in labs, CTFs, or environments that permit security testing.

---

## Setup & Installation

1. Clone or copy the project folder, e.g.:

   ```bash
   git clone https://github.com/Master-Panpour/Tool.git IronCrypt
   cd IronCrypt
