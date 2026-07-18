# IronCrypt Aegiscope implementation matrix

This matrix audits the requested roadmap against the implementation.

| Requested capability | Implementation | Verification |
|---|---|---|
| Unique IronCrypt startup product name | IronCrypt Aegiscope / `aegiscope` | CLI version and branding tests |
| Quick/full TCP, UDP-top, firewall-map and custom profiles | `aegiscope ports --profile ...` | Bats profile tests |
| Normal discovery; advanced `-Pn` | Default excludes `-Pn`; explicit `--skip-host-discovery` | Bats argument tests |
| Gobuster VHost discovery | `web --mode vhost`, append-domain and bounded delay | Bats VHost test |
| Gobuster DNS discovery | `web --mode dns` | Bats DNS test |
| Enhanced ffuf | Auto-calibration, rate/time, recursion, headers, redaction, JSON/HTML/CSV/all | Bats ffuf test |
| Subfinder → httpx | Source-attributed JSONL, jq extraction and structured enrichment | Bats pipeline test |
| testssl.sh | JSON/HTML output with OpenSSL/Nmap fallbacks | Bats TLS test |
| HTTP analysis | Redirects, status, server hints, cookies, security headers, advertised methods | Bats HTTP test |
| OWASP information-gathering stages | Network, intel, server, metafiles, apps, entry points, paths, architecture | Bats directory-layout test |
| Results and manifests | Unique UTC run directories, commands, versions, status and artifacts | Bats manifest tests |
| Non-interactive CLI | `recon`, `ports`, `web`, `xss`, `load`, `doctor`, `report`, `compare`, `update` | Help and command tests |
| Authorized scope and rate ceiling | Exact/wildcard/CIDR scope plus authorization assertion and global ceiling | Scope/rate Bats tests |
| DDoS category | Bounded single-source k6/hey/curl workflow with methods, auth headers, redacted bodies, error/p95 thresholds and JSON plans/results | Bats load, custom-request and cap tests |
| XSS category | Harmless-canary GET/POST discovery, form/query extraction, encoding/context evidence, DOM indicators and JSONL; no payload execution | Bats XSS and discovery tests |
| Extensive colored menu | Seven top-level categories with nested category/profile menus | Forced-color menu test |
| Extra versatility | DNS discovery, Shodan/IPinfo evidence and run comparison | Pipeline and comparison tests |
| Updater correction | Check-only branch comparison; no remote replacement/execution | Static review and help |
| Shell quality | Bash syntax, ShellCheck, shfmt, mocked Bats and Linux CI | CI workflow and local checks |

Legal caution: Aegiscope assumes authorized professional use. Operators remain responsible for written authorization, scope, rate limits, applicable law, and handling assessment data.
