# IronCrypt Aegiscope usage

## Command model

```text
aegiscope pipeline --target URL|DOMAIN [--phase passive|verify|active|all]
aegiscope resume RUN_DIRECTORY --target URL|DOMAIN [pipeline options]
aegiscope retry RUN_DIRECTORY --failed-only --target URL|DOMAIN [pipeline options]
aegiscope assets init|ingest|list|graph|diff|dashboard [options]
aegiscope ports --target HOST [options]
aegiscope web --target URL|DOMAIN [options]
aegiscope recon --target URL|DOMAIN [options]
aegiscope api --target URL [options]
aegiscope validate --target URL|HOST [options]
aegiscope auth add|list|show|remove [options]
aegiscope plugins list|doctor|run [options]
aegiscope xss --target URL [options]
aegiscope load|ddos --target URL [options]
aegiscope doctor
aegiscope report [--run DIRECTORY] [--format markdown|html|json|csv|all]
aegiscope compare [--baseline DIRECTORY] [--current DIRECTORY]
aegiscope diff [--since 7d|--baseline RUN_ID --current RUN_ID]
aegiscope update --check
```

Run `./aegiscope` without arguments for the interactive menu. Scripts and scheduled jobs should use explicit subcommands.

## Safety controls

Commands that contact a target validate syntax, normalize its hostname, enforce `config/authorized_scope.txt` (or `--scope-file`), require `--authorized` for direct operation, and reject rates above `AEGISCOPE_MAX_RATE` (100 by default). `--authorized` is an assertion, not a scope bypass.

Scope entries support exact hosts, wildcard domains, and IPv4 CIDRs. Derived pipeline hosts are filtered through the same scope before later phases consume them.

## Pipeline

```bash
./aegiscope pipeline --target lab.example.com --phase all --request-rate 20 --authorized
```

Phases:

| Phase | Work |
|---|---|
| `passive` | Subfinder source-attributed domain collection |
| `verify` | dnsx resolution, Naabu port discovery, Nmap service evidence, httpx web enrichment |
| `active` | Katana scoped endpoint crawling |
| `all` | Passive, verification, and active phases |

The pipeline writes per-tool checkpoints, a machine-readable phase policy, and credential-aware cache entries. Required missing phase dependencies make automation fail instead of silently reducing coverage. Nmap receives the complete resolved in-scope host list. Continue an interrupted run with `resume`; use `retry --failed-only` to rerun steps that lack completed checkpoints. Resume is locked to the original target, and earlier manifests, plans, and failed checkpoint states are retained under history directories.

```bash
./aegiscope resume results/<run> --target lab.example.com --phase all --authorized
./aegiscope retry results/<run> --failed-only --target lab.example.com --phase all --authorized
```

Use `--cache-ttl 0` to disable cache reuse. Protected headers can be supplied with `--auth-profile NAME`. Subfinder provider-specific budgets use `--provider-rate-limits 'provider=2/s,other=1/s'` while the global ceiling remains authoritative.

## Asset workspace

Run manifests are automatically ingested into `results/workspace/assets.db`. Manual ingestion is also available:

```bash
./aegiscope assets init
./aegiscope assets ingest --manifest results/<run>/manifest.json
```

Queries and views:

```bash
./aegiscope assets list --kind domain
./aegiscope assets list --port 443
./aegiscope assets list --technology nginx --json
./aegiscope assets graph app.lab.example.com
./aegiscope assets graph app.lab.example.com --format dot
./aegiscope assets diff --baseline RUN_ID --current RUN_ID --json
./aegiscope diff --since 7d
./aegiscope assets dashboard --output results/dashboard.html
```

The dashboard includes run/evidence paths, assets, normalized findings, and relationships. Raw artifacts remain authoritative.

## Ports

Profiles are `quick-tcp`, `full-tcp`, `udp-top`, `firewall-map`, and `custom`. Normal Nmap host discovery is the default. `--skip-host-discovery` explicitly adds `-Pn`; use it only when a known in-scope host suppresses discovery probes. See [SCAN_TYPES.md](SCAN_TYPES.md).

## Web enumeration

- `dir`: ffuf auto-calibration, rate/time limits, recursion, repeatable headers, and `json|html|csv|all`; Gobuster fallback.
- `vhost`: Gobuster VHost discovery with append-domain behavior and bounded workers/delay.
- `dns`: Gobuster DNS discovery.
- `subdomains`: Subfinder JSONL/source attribution followed by httpx enrichment.
- `http`: redirects, status, server hints, cookies, security headers, and OPTIONS `Allow` labelled as **advertised methods**.
- `tech`: httpx or WhatWeb technology/CMS hints.
- `tls`: testssl.sh JSON/HTML, with OpenSSL/Nmap fallbacks.
- `all`: all web stages, preserving partial-failure status.

```bash
./aegiscope web --target https://app.lab.example.com --mode dir \
  --auth-profile staging --request-rate 20 --max-time 180 \
  --recursion-depth 1 --output-format all --authorized
```

## API reconnaissance

Import OpenAPI/Swagger JSON or YAML, Postman collections, or Burp XML:

```bash
./aegiscope api --target https://app.lab.example.com \
  --import ./collection.json --format postman --cors \
  --auth-profile staging --request-rate 10 --authorized
```

`--discover` checks common local specification paths, `--graphql` sends only a `__typename` capability query, and `--cors` records advertised methods and access-control response headers. These outputs are evidence for review, not proof of an authorization flaw.

## Nuclei validation

By default, unsigned/signature-mismatched templates and DoS/code/fuzz/headless categories are disabled. `--include-intrusive` permits fuzz/headless while DoS/code stay excluded. Response evidence, policy, and template-version output are retained.

For a reviewed local template set, require an exact content fingerprint:

```bash
digest="$(python3 lib/workspace.py --db results/workspace/assets.db fingerprint --path ./reviewed-templates)"
./aegiscope validate --target https://app.lab.example.com \
  --templates ./reviewed-templates --template-sha256 "$digest" \
  --severity medium,high,critical --request-rate 10 --authorized
```

## Credentials and plugins

Create a header file outside the repository, one `Name: value` per line, then import it:

```bash
./aegiscope auth add --name staging --from-file ./private-headers.txt
./aegiscope auth list
./aegiscope auth show --name staging
./aegiscope auth remove --name staging
```

Profiles are stored with mode 0600 where supported. List/show never print values. Authentication, cookie, proxy-authorization, and request-body data are redacted from manifests.

Plugin commands:

```bash
./aegiscope plugins list
./aegiscope plugins doctor
./aegiscope plugins run --name http-head --target https://app.lab.example.com --request-rate 10 --authorized
```

Only run reviewed local plugins. Each plugin must implement check, command-build, execute, normalize, and artifact hooks; built-in guardrails still apply.

## OWASP reconnaissance

`recon` stages correspond to OWASP information gathering:

| Stage | Evidence |
|---|---|
| `network` | Ping and route context |
| `intel` | Optional Shodan/IPinfo evidence |
| `server` | DNS, Whois, HTTP redirect/header/cookie/TLS hints |
| `metafiles` | robots.txt, sitemap.xml, security.txt |
| `applications` | httpx/WhatWeb fingerprinting |
| `entry-points` | Passive forms, inputs, buttons, links, actions, names |
| `paths` | Passive links/actions from fetched content |
| `architecture` | DNS topology, route, CDN/ASN/CNAME metadata |

`all` performs external intelligence only when `--external-intel` is supplied.

## XSS reflection analysis

`xss` uses unique non-executing canaries, discovers query and form parameters, distinguishes raw/encoded punctuation, captures response context, records content type/CSP, and identifies common DOM sources/sinks. It does not send script elements, event handlers, or executable browser payloads. Results are validation leads, not confirmed exploitability.

## Bounded load resilience

`load` and its `ddos` alias support k6, hey, and curl; HTTP methods, headers, bodies; maximum error-rate and p95 thresholds; and structured plans/results. Hard maximums are 60 seconds, 100 requests/second, concurrency 20, and 1,000 total configured requests. Distributed coordination, flooding, and guardrail bypasses are intentionally absent.

## Reports, menu, and updates

`report` generates an assessment package from a run manifest and the normalized workspace:

```bash
# Draft Markdown using safe placeholder metadata
./aegiscope report --run results/<run>

# Enterprise bundle: Markdown, print-ready HTML, JSON, findings CSV, quality JSON
./aegiscope report --run results/<run> --format all \
  --profile ./client-report-profile.json

# Fail unless metadata, execution coverage, tool availability, evidence integrity,
# workspace ingestion, run status, and analyst validation satisfy the final gate
./aegiscope report --run results/<run> --format all \
  --profile ./client-report-profile.json --strict
```

Start from `config/report_profile.example.json`. Reports include document control, executive summary, objectives, scope/schedule, methodology, limitations, findings/severity summary, detailed remediation fields, coverage, assets, redacted command ledger, tool versions, evidence size/SHA-256 verification, and a point-in-time disclaimer. Scanner findings are explicitly marked unvalidated. To pass strict final readiness, add a `finding_overrides` entry keyed by each source/template ID or Aegiscope reference and give it a disposition (`Confirmed`, `False Positive`, `Accepted Risk`, `Remediated`, or `Not Applicable`) plus analyst-reviewed impact, likelihood, remediation owner, and target date where applicable.

The structure follows [OWASP WSTG reporting guidance](https://owasp.org/www-project-web-security-testing-guide/v42/5-Reporting/README) and [NIST SP 800-115](https://csrc.nist.gov/pubs/sp/800/115/final). It provides an evidence-backed template, not legal advice or a substitute for tester analysis and business-risk ownership.

`compare` compares two manifest runs. Asset `diff` compares normalized inventory across runs or time windows.

The ten menu categories are workspace/assets, pipelines, network/ports, web, API, validation, resilience, evidence/reporting, credentials/plugins, and environment/design. Classic, shield, and minimal headers are selectable. `NO_ANIMATION=1` and `NO_COLOR=1` support accessible or automated output.

`update --check` fetches tracked-branch metadata and reports current/behind/ahead/diverged state. It never replaces files or executes remote content.
