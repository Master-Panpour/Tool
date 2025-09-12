# Port Scan Types & Compatibility

These are some common Nmap scan types:

| Scan Type       | Nmap Flag     | Description                                                  |
|------------------|----------------|--------------------------------------------------------------|
| TCP Connect      | `-sT`          | Uses OS connect(); requires no raw packet privileges         |
| SYN              | `-sS`          | Stealth / half-open scan; needs root/raw privileges          |
| NULL             | `-sN`          | No flags; uses TCP null scan                                 |
| FIN              | `-sF`          | FIN-flag scan                                               |
| Xmas             | `-sX`          | FIN, PSH, URG flags; “Christmas tree” packets                |
| ACK              | `-sA`          | Used to map firewall rules etc.                             |
| UDP              | `-sU`          | UDP scan                                                    |

---

## Which combinations are allowed / disallowed

- You generally can use **only one TCP scan type** at a time among `-sT`, `-sS`, `-sN`, `-sF`, `-sX`, `-sA`. Using more than one TCP scan type together is **invalid**.  
- You *can* combine one TCP scan type with UDP scan (`-sU`). E.g. `nmap -sS -sU target` is valid. :contentReference[oaicite:1]{index=1}  
- Always check privilege: some scan types need root or special privileges (raw sockets).  
- Also some scan types (NULL, FIN, Xmas) may behave differently depending on OS / firewall settings.  

---

## Web Enumeration Categories

In web enumeration we can categorize like:

- Directory / File enumeration (wordlist / brute force)  
- Virtual Hosts enumeration  
- Subdomain enumeration  
- HTTP methods / headers analysis  
- SSL / TLS info etc.

---

