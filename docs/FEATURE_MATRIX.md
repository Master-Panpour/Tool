# IronCrypt Aegiscope implementation matrix

This matrix maps the requested roadmap to implemented behavior and regression coverage.

| Capability | Implementation | Verification |
|---|---|---|
| IronCrypt product identity | IronCrypt Aegiscope, command `aegiscope`, versioned branding | CLI and banner tests |
| Three header designs and transition | Classic, shield, minimal; one-time `IRONCRYPT` -> `AEGISCOPE` TTY animation | Forced-color/non-animation Bats test |
| Systematic menu | Ten top-level categories with focused submenus | Menu smoke test |
| TCP/UDP/firewall/custom profiles | `ports --profile quick-tcp|full-tcp|udp-top|firewall-map|custom` | Profile argument tests |
| Normal discovery and advanced `-Pn` | Default omits `-Pn`; `--skip-host-discovery` adds it explicitly | Nmap argument tests |
| ffuf integration | Calibration, rate/time limits, recursion, headers, JSON/HTML/CSV/all | ffuf mock test |
| Gobuster modes | Directory fallback plus bounded DNS and VHost discovery | Gobuster mode tests |
| Asset workspace | SQLite runs, assets, observations, edges, and findings | Asset/dashboard Bats test |
| Asset queries | Kind, text, port, technology, JSON | CLI/database test |
| Relationships and history | Text/DOT graph, run-to-run diff, `--since`, evidence linkage | Graph/diff paths and Bats test |
| Portable dashboard | Runs, findings, assets, edges, evidence paths in one HTML file | Dashboard Bats test |
| Phased pipeline | Subfinder -> dnsx -> Naabu -> Nmap -> httpx -> Katana | Complete pipeline Bats test |
| Resume, retry and cache | Per-tool checkpoints, target-locked resume, credential cache namespace, preserved manifest/plan/failure history | Resume/retry/recovery Bats tests |
| Pipeline completeness | Required missing tools fail automation; Nmap scans the resolved in-scope host list | Dependency and Nmap-list tests |
| Subfinder/httpx enrichment | Source-attributed JSONL, global/provider rates, derived-host scope filtering, status, title, technologies, IP/CNAME | Pipeline ingestion/scope test |
| API reconnaissance | OpenAPI/Swagger JSON or YAML, Postman JSON, Burp XML, discovery, GraphQL capability, CORS evidence | OpenAPI/Postman/CORS Bats tests |
| Nuclei validation | Unsigned disabled, conservative exclusions, rate ceiling, stored responses, optional exact template digest, version evidence | Policy, normalization, pin/mismatch tests |
| testssl.sh | JSON/HTML output with OpenSSL/Nmap fallback | TLS mock test |
| HTTP analysis | Redirect/status/server/cookie/security headers and correctly labelled advertised methods | HTTP mock test |
| OWASP stages | Server, metafiles, applications, entry points, paths, architecture | Stage directory-layout test |
| Credential profiles | Mode-0600 files; redacted list/show; integrations receive headers without logging secrets | Credential Bats test |
| Plugin adapters | Reviewed local contract: check, build, execute, normalize, artifacts | Sample `http-head` plugin test |
| XSS analysis | Harmless canary only, query/form discovery, context/encoding/DOM evidence, JSONL | XSS tests |
| Load resilience | Bounded k6/hey/curl, auth/method/body, p95/error thresholds, hard caps; no distributed flooding | Load and cap tests |
| Structured evidence | Versioned manifests, scope snapshot, authorization assertion, redacted execution ledger, per-command status/timeline, artifact size/SHA-256 | Manifest/integrity tests |
| Enterprise reports | Markdown, print-ready HTML, JSON, findings CSV, engagement profiles, executive/technical sections and strict readiness gate | Formal report, tamper and validation tests |
| Non-interactive operation | `recon`, `pipeline`, `resume`, `retry`, `ports`, `web`, `api`, `validate`, `assets`, `auth`, `plugins`, `xss`, `load`, `doctor`, `report`, `compare`, `diff`, `update` | Help and command tests |
| Guardrails | Scope file, explicit assertion, global rate ceiling, safe updater behavior | Scope/rate/update tests |
| Shell/Python quality | Bash syntax, ShellCheck, shfmt, Python compile, mocked Bats, Linux CI | CI workflow |

Legal caution: operators remain responsible for written authorization, assessment scope, rate selection, applicable law, and secure evidence handling.
