# IronCrypt Aegiscope

IronCrypt Aegiscope is the authorized reconnaissance and enumeration product in the IronCrypt startup family. The name combines **aegis** (protection) with **scope** (the explicit boundary of a security assessment). Its command is `aegiscope`.

> Aegiscope assumes authorized professional use. Operate only within applicable law, written authorization, and the configured assessment scope.

## Capabilities

- Nmap profiles: `quick-tcp`, `full-tcp`, `udp-top`, `firewall-map`, and constrained `custom` scans.
- Normal Nmap host discovery by default; `--skip-host-discovery` enables the advanced `-Pn` override.
- Directory enumeration with ffuf auto-calibration, rate/time limits, recursion, headers, and JSON/HTML/CSV output; Gobuster is the fallback.
- Gobuster VHost discovery with a rate-limited single worker.
- Gobuster DNS discovery for controlled hostname enumeration.
- Subfinder JSONL with source attribution, followed by httpx status/title/technology enrichment.
- HTTP redirect, server, cookie, security-header, and advertised-method analysis.
- Optional testssl.sh JSON/HTML TLS analysis with verified OpenSSL and Nmap fallbacks.
- OWASP WSTG-aligned reconnaissance stages: server fingerprinting, metafiles, application enumeration, entry points, execution paths, and architecture.
- Network basics plus optional Shodan/IPinfo intelligence.
- Context-aware XSS discovery using harmless unique canaries, query/form parameter discovery, raw-versus-encoded punctuation checks, response context evidence, DOM source/sink indicators, and JSONL results.
- Bounded, single-source DDoS/load-resilience testing through k6, hey, or curl with custom methods, authentication headers, request bodies, error-rate thresholds, p95 latency thresholds, and structured plans/results. Distributed flooding is not provided.
- Per-run result directories containing artifacts and a JSON manifest with target, scope, commands, versions, timestamps, exit status, and artifact paths.
- Non-interactive `recon`, `ports`, `web`, `xss`, `load`, `doctor`, `report`, `compare`, and check-only `update` commands.
- A colored nested menu with reconnaissance, port, web, application-security, resilience, reporting, and maintenance categories. Set `NO_COLOR=1` to disable color.

## Setup

```bash
git clone https://github.com/Master-Panpour/Tool.git ironcrypt-aegiscope
cd ironcrypt-aegiscope
chmod +x required_perms.sh
./required_perms.sh
```

Install the core and recommended Debian/Ubuntu packages:

```bash
sudo apt update
sudo apt install -y bash curl nmap openssl jq dnsutils whois traceroute gobuster
```

Optional integrations follow their official installation instructions:

- [ffuf](https://github.com/ffuf/ffuf)
- [Subfinder](https://docs.projectdiscovery.io/opensource/subfinder/install)
- [httpx](https://docs.projectdiscovery.io/opensource/httpx/install)
- [testssl.sh](https://github.com/testssl/testssl.sh)
- [Gobuster](https://github.com/OJ/gobuster)
- [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/)
- [hey](https://github.com/rakyll/hey)

Check the local environment:

```bash
./aegiscope doctor
```

## Authorized scope

Edit `config/authorized_scope.txt`. It accepts exact hosts, wildcard domains, and IPv4 CIDRs:

```text
app.lab.example.com
*.lab.example.com
192.0.2.0/24
```

Targets outside this file are rejected. Non-interactive jobs must also pass `--authorized` to assert that written authorization exists. The full interactive menu displays a legal-use caution and treats a subsequent scan selection as the same assertion. The default scope only permits localhost.

## Examples

```bash
./aegiscope ports --target 127.0.0.1 --profile quick-tcp --authorized
./aegiscope ports --target 192.0.2.10 --profile udp-top --request-rate 50 --authorized
./aegiscope ports --target app.lab.example.com --profile custom --scan-type syn --ports 22,80,443 --service-detection --authorized

./aegiscope web --target https://app.lab.example.com --mode http --authorized
./aegiscope web --target https://app.lab.example.com --mode dir --request-rate 25 --recursion-depth 1 --output-format all --authorized
./aegiscope web --target https://app.lab.example.com --mode vhost --wordlist wordlists/vhosts-small.txt --authorized
./aegiscope web --target lab.example.com --mode dns --authorized
./aegiscope web --target lab.example.com --mode subdomains --authorized
./aegiscope web --target https://app.lab.example.com --mode tech --authorized
./aegiscope web --target https://app.lab.example.com --mode tls --authorized

./aegiscope recon --target https://app.lab.example.com --stage all --authorized
./aegiscope recon --target app.lab.example.com --stage intel --authorized
./aegiscope xss --target 'https://app.lab.example.com/search?q=term' --discover-parameters --authorized
./aegiscope ddos --target https://app.lab.example.com/api --duration 10 --request-rate 10 --concurrency 2 --method POST --header 'Authorization: Bearer TOKEN' --body '{"probe":true}' --max-error-rate 5 --p95-ms 1000 --authorized
./aegiscope report
./aegiscope compare
```

Use `--skip-host-discovery` only when the authorized target is known to suppress discovery probes. It maps to Nmap `-Pn` and is never enabled by default.

Sensitive `Authorization`, `Cookie`, and `Proxy-Authorization` header values are redacted in manifests even though the original values are passed to the selected tool.

## Results

Runs are stored under:

```text
results/<UTC timestamp>_<target>_<operation>/
├── manifest.json
├── tool output files
└── report.md             # after `aegiscope report`
```

The results directory is ignored by Git. Treat reports as sensitive assessment data.

## Development

```bash
shellcheck aegiscope required_perms.sh bin/aegiscope bin/**/*.sh lib/*.sh
shfmt -d -i 2 -ci aegiscope required_perms.sh bin lib tests
bats tests
```

Linux CI runs Bash syntax validation, ShellCheck, shfmt, and mocked Bats tests. See [docs/USAGE.md](docs/USAGE.md) for the complete CLI reference and [docs/SCAN_TYPES.md](docs/SCAN_TYPES.md) for profile semantics.

The complete implementation audit is maintained in [docs/FEATURE_MATRIX.md](docs/FEATURE_MATRIX.md).

## Design references

Aegiscope follows the information-gathering structure in the [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/01-Information_Gathering/README). Its HTTP method output is deliberately labelled “advertised methods” according to [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html), rather than claiming an exhaustive authorization test.

The project remains licensed under GPLv3. The name collision check performed during this rename found no exact public web result for “Aegiscope” or “IronCrypt Aegiscope”; this is not a legal trademark clearance.
