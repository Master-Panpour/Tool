# IronCrypt Aegiscope

IronCrypt Aegiscope is a personal, authorization-first reconnaissance workspace for red-team and security-assessment use. It coordinates established tools, normalizes their evidence into a SQLite asset model, and preserves exact run metadata for repeatable analysis.

> Use Aegiscope only within applicable law, written authorization, and the configured assessment scope.

## Release status

The current release is **Aegiscope 0.4.1**. The repository quality gate covers Bash syntax, ShellCheck, shfmt, Python compilation, JSON validation, executable permissions, and mocked Bats integration tests. The mocked suite validates orchestration and evidence handling without scanning live targets; operators should still complete an authorized lab acceptance run with their installed external-tool versions before production use.

## What it provides

- A phased pipeline: Subfinder -> dnsx -> Naabu -> Nmap -> httpx -> Katana, with passive, verification, and active phases.
- Checkpoints, failed-step retry, credential-aware cache TTLs, preserved resume history, phase-policy evidence, and target-locked resumable runs.
- A persistent SQLite asset workspace containing domains, IPs, services, URLs, technologies, findings, observations, and relationships.
- Asset queries by kind, port, technology, or text; relationship graphs; historical diffs; and a portable HTML dashboard.
- Nmap profiles: `quick-tcp`, `full-tcp`, `udp-top`, `firewall-map`, and constrained `custom` scans.
- Normal Nmap host discovery by default, with `--skip-host-discovery` as the advanced `-Pn` override.
- ffuf auto-calibration, request/time limits, recursion, protected headers, and JSON/HTML/CSV output.
- Gobuster directory, DNS, and VHost discovery.
- Subfinder source-attributed JSONL with global/per-provider limits and in-scope filtering, followed by httpx status, title, technology, server, IP, and CNAME enrichment.
- HTTP redirect, status, server, cookie, security-header, and advertised-method analysis.
- API inventory from OpenAPI, Swagger, Postman, and Burp exports; safe specification discovery, GraphQL capability probing, and CORS evidence.
- Nuclei validation with unsigned templates disabled, conservative default exclusions, optional reviewed-template SHA-256 pinning, template-version evidence, rate limits, and stored responses.
- Optional testssl.sh JSON/HTML TLS analysis with OpenSSL and Nmap fallbacks.
- OWASP WSTG-aligned stages: server fingerprinting, metafiles, application enumeration, entry points, execution paths, and architecture.
- Harmless-canary XSS reflection analysis with parameter discovery, encoding/context evidence, DOM indicators, and JSONL results.
- Bounded single-source load-resilience testing using k6, hey, or curl, with hard duration/rate/concurrency/request caps. Distributed flooding is not implemented.
- Protected local authentication-header profiles and a reviewed plugin adapter contract.
- Versioned run manifests containing the authorization assertion, scope snapshot, exact redacted commands, per-command timestamps/exit codes, tool versions, and SHA-256 evidence inventory.
- Enterprise report bundles in Markdown, print-ready HTML, JSON, and findings CSV, with engagement profiles, executive/technical sections, evidence verification, and strict final-report readiness gates.
- An extensive category/subcategory menu with permanent mascot, classic, shield, and minimal IronCrypt-to-Aegiscope header designs.

## Setup

```bash
git clone https://github.com/Master-Panpour/Tool.git ironcrypt-aegiscope
cd ironcrypt-aegiscope
chmod +x required_perms.sh
./required_perms.sh
```

Core Debian/Ubuntu packages:

```bash
sudo apt update
sudo apt install -y bash curl python3 python3-yaml sqlite3 nmap openssl jq dnsutils whois traceroute gobuster
```

Optional integrations use their official installation instructions: [ffuf](https://github.com/ffuf/ffuf), [Subfinder](https://docs.projectdiscovery.io/opensource/subfinder/install), [dnsx](https://docs.projectdiscovery.io/opensource/dnsx/install), [Naabu](https://docs.projectdiscovery.io/opensource/naabu/install), [httpx](https://docs.projectdiscovery.io/opensource/httpx/install), [Katana](https://docs.projectdiscovery.io/opensource/katana/install), [Nuclei](https://docs.projectdiscovery.io/opensource/nuclei/install), [testssl.sh](https://github.com/testssl/testssl.sh), [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/), and [hey](https://github.com/rakyll/hey).

Check what is available:

```bash
./aegiscope doctor
```

## Authorized scope

Edit `config/authorized_scope.txt`. It supports exact hosts, wildcard domains, and IPv4 CIDRs:

```text
app.lab.example.com
*.lab.example.com
192.0.2.0/24
```

Targets outside the scope file are rejected. Direct commands also require `--authorized`; this asserts written authorization but never bypasses scope. The global request ceiling defaults to 100 and can be lowered with `AEGISCOPE_MAX_RATE`.

## Quick examples

```bash
# Phased reconnaissance and continuation
./aegiscope pipeline --target lab.example.com --phase passive --request-rate 20 --authorized
./aegiscope pipeline --target lab.example.com --phase all --request-rate 20 --provider-rate-limits 'shodan=2/s' --authorized
./aegiscope resume results/<pipeline-run> --target lab.example.com --phase all --authorized
./aegiscope retry results/<pipeline-run> --failed-only --target lab.example.com --phase all --authorized

# Asset intelligence
./aegiscope assets list --port 443
./aegiscope assets list --technology nginx --json
./aegiscope assets graph app.lab.example.com --format dot
./aegiscope diff --since 7d
./aegiscope assets dashboard --output results/aegiscope-dashboard.html

# Port and web work
./aegiscope ports --target 127.0.0.1 --profile quick-tcp --authorized
./aegiscope ports --target app.lab.example.com --profile custom --scan-type syn --ports 22,80,443 --service-detection --authorized
./aegiscope web --target https://app.lab.example.com --mode dir --request-rate 20 --recursion-depth 1 --output-format all --authorized
./aegiscope web --target https://app.lab.example.com --mode vhost --authorized
./aegiscope web --target lab.example.com --mode subdomains --authorized

# Protected authentication and API recon
./aegiscope auth add --name staging --from-file ./private-headers.txt
./aegiscope api --target https://app.lab.example.com --import collection.json --format postman --cors --auth-profile staging --authorized

# Signed/pinned validation
digest="$(python3 lib/workspace.py --db results/workspace/assets.db fingerprint --path ./reviewed-templates)"
./aegiscope validate --target https://app.lab.example.com --templates ./reviewed-templates --template-sha256 "$digest" --request-rate 10 --authorized

# Evidence and reporting
./aegiscope report
./aegiscope report --format all --profile config/report_profile.example.json
./aegiscope report --format all --profile ./client-report-profile.json --strict
./aegiscope compare
```

Use `--skip-host-discovery` only when a known in-scope target suppresses discovery probes. Sensitive authorization, cookie, proxy-authorization, and request-body values are redacted from manifests.

## Menu and header designs

Run `./aegiscope` without arguments. Its menu is organized into workspace/assets, pipelines, network/ports, web, API, validation, resilience, evidence/reporting, credentials/plugins, and environment/design.

The first interactive render animates `IRONCRYPT` into `AEGISCOPE`. The permanent IronCrypt Sentinel mascot is the default; select permanent, classic, shield, or minimal under **Environment & design**, or set:

```bash
AEGISCOPE_BANNER_STYLE=permanent ./aegiscope
NO_ANIMATION=1 ./aegiscope
NO_COLOR=1 ./aegiscope
```

Animation and color are automatically suppressed in non-interactive output and CI.

### Header and animation implementation

The terminal branding is dependency-free Bash in `lib/core.sh`. It uses ANSI escape sequences through `printf`, with magenta for IronCrypt, cyan for Aegiscope and menu choices, yellow for prompts and the transition arrow, and blue for section labels. `AEGISCOPE_BANNER_STYLE` dispatches to one of four renderers: `permanent`, `classic`, `shield`, or `minimal`. Every renderer includes the persistent credit line `IronCrypt • Made by Master_Panpour & Master_Demon`.

On the first interactive render, `ui_brand_animation` clears and redraws the terminal through seven frames, sleeping 70 milliseconds between frames:

```text
I
IR
IRON
IRONCRYPT
IRONCRYPT  →
IRONCRYPT  →  AEGIS
IRONCRYPT  →  AEGISCOPE
```

The animation runs only when standard output is a terminal. It is skipped when `NO_ANIMATION=1`, when `CI=true`, or when output is redirected. Color follows the `NO_COLOR` convention and can be enabled in automated tests with `AEGISCOPE_FORCE_COLOR=1`. The **Environment & design** menu previews and switches all four header styles for the current session.

## Results and development

Every run is written below `results/` with its manifest and evidence. The cross-run database is `results/workspace/assets.db`; authentication profiles are protected under `results/workspace/auth/`. Reports are drafts until automated findings are manually validated and the strict quality gate passes. Copy [the report-profile example](config/report_profile.example.json), supply the real engagement metadata, and protect the entire results tree as sensitive assessment data.

```bash
bash -n aegiscope required_perms.sh bin/aegiscope lib/*.sh plugins/*.sh
shellcheck -S warning aegiscope required_perms.sh bin/aegiscope lib/*.sh plugins/*.sh
shfmt -d -i 2 -ci aegiscope required_perms.sh bin lib tests plugins
python3 -m py_compile lib/workspace.py
bats tests
```

Linux CI runs these syntax, formatting, static-analysis, Python, executable-bit, and fully mocked Bats checks. See [complete usage](docs/USAGE.md), [architecture](docs/ARCHITECTURE.md), [profile semantics](docs/SCAN_TYPES.md), the [implementation matrix](docs/FEATURE_MATRIX.md), and the [changelog](CHANGELOG.md).

The project remains GPLv3 licensed.
