# IronCrypt Aegiscope usage

## Command model

```text
aegiscope recon  --target URL|DOMAIN [options]
aegiscope ports  --target HOST [options]
aegiscope web    --target URL|DOMAIN [options]
aegiscope xss    --target URL --parameter NAME [options]
aegiscope load   --target URL [options]
aegiscope ddos   --target URL [options] # bounded load-resilience alias
aegiscope doctor
aegiscope report [--run DIRECTORY]
aegiscope compare [--baseline DIRECTORY] [--current DIRECTORY]
aegiscope update --check
```

Run the repository-local command as `./aegiscope`. Running it without arguments opens the full nested interactive menu; automation should use explicit subcommands.

## Safety controls

All commands that contact a target:

1. Validate the target syntax.
2. Normalize a URL to its hostname.
3. Require a match in `config/authorized_scope.txt` (or `--scope-file FILE`).
4. Require an authorization assertion: selection under the interactive menu's caution, or `--authorized` for direct commands and automation.
5. Reject request rates above `AEGISCOPE_MAX_RATE` (default 100).

`--authorized` is an assertion, not a bypass: scope membership is still mandatory.
The interactive menu displays the legal-use caution up front and treats the operator's subsequent scan selection as that assertion; it still enforces the scope file and rate ceilings.

## Ports

```bash
./aegiscope ports --target HOST --profile quick-tcp --authorized
```

Options include `--request-rate`, `--skip-host-discovery`, and custom scan controls. Normal Nmap host discovery is the default. See [SCAN_TYPES.md](SCAN_TYPES.md).

## Web

Modes:

- `dir`: ffuf with `-ac`, `-rate`, `-maxtime`, optional recursion, repeatable `--header`, and `json|html|csv|all` output. Gobuster is the fallback.
- `vhost`: Gobuster VHost mode with `--append-domain`, one worker, and a calculated delay.
- `dns`: Gobuster DNS mode with the same single-worker request-rate delay.
- `subdomains`: Subfinder JSONL/source attribution; jq extracts hosts and httpx adds status, title, technologies, server, IP, and CNAME.
- `http`: follows redirects, records headers/body, lists server hints and cookies, checks common security headers, and prints the OPTIONS `Allow` value as advertised methods.
- `tech`: httpx or WhatWeb technology/CMS fingerprinting.
- `tls`: testssl.sh JSON/HTML output with OpenSSL or Nmap fallbacks.
- `all`: runs every web stage and records partial failures in the manifest exit code.

Example with authentication and controlled fuzzing:

```bash
./aegiscope web \
  --target https://app.lab.example.com \
  --mode dir \
  --header 'Authorization: Bearer TOKEN' \
  --request-rate 20 \
  --max-time 180 \
  --recursion-depth 1 \
  --output-format all \
  --authorized
```

Authentication values are redacted in the manifest.

## Recon

The stages correspond to OWASP WSTG information gathering:

| Stage | Collected evidence |
|---|---|
| `network` | Ping and route context |
| `intel` | Optional Shodan and IPinfo evidence |
| `server` | DNS, Whois, redirects, headers, cookies, HTTP/TLS hints |
| `metafiles` | `robots.txt`, `sitemap.xml`, `.well-known/security.txt` |
| `applications` | httpx or WhatWeb fingerprinting |
| `entry-points` | Passive form, input, button, link, action, and name attributes |
| `paths` | Passive links/actions extracted from the fetched page |
| `architecture` | DNS topology, optional route data, CDN/ASN/CNAME metadata |
| `all` | Every stage in numbered artifact directories |

The `all` stage performs external intelligence only when `--external-intel` is supplied. Selecting the dedicated `intel` stage is itself an explicit request for those lookups.

## XSS reflection audit

`aegiscope xss` is a complete non-executing discovery workflow. It sends a unique canary plus harmless punctuation through named GET or POST parameters, distinguishes raw from encoded reflection, captures response contexts, records content type and CSP, identifies common DOM sources/sinks, and writes text plus JSONL evidence. `--discover-parameters` extracts candidates from the target query string and HTML form fields. Response bodies are capped with `--max-response-bytes`.

It deliberately does not inject script elements, event handlers, or executable browser payloads. Findings are investigation leads for manual validation within the assessment scope.

## DDoS/load resilience

The `load` command—and its `ddos` alias—implements a bounded, single-source resilience assessment. It supports k6, hey, and curl engines, common HTTP methods, repeatable authentication/custom headers, redacted request bodies, maximum error-rate thresholds, p95 latency thresholds, and structured test plans/results.

```bash
./aegiscope ddos \
  --target https://app.lab.example.com/api \
  --duration 10 --request-rate 10 --concurrency 2 \
  --method POST --header 'Authorization: Bearer TOKEN' \
  --body '{"healthCheck":true}' \
  --max-error-rate 5 --p95-ms 1000 --authorized
```

Hard limits remain:

- Maximum duration: 60 seconds.
- Maximum configured rate: 100 requests/second.
- Maximum concurrency: 20.
- Maximum duration × rate budget: 1,000 requests.

These limits can be lowered with environment settings but should not be raised without corresponding organizational controls. Threshold failures return a nonzero status suitable for CI. Distributed traffic coordination, availability-destruction logic, and limit bypasses are not implemented.

## Doctor and reports

`aegiscope doctor` identifies installed and missing core, recommended, optional, and development tools.

`aegiscope report` converts the latest manifest into Markdown. Pass `--run results/<directory>` for a specific run. jq produces the summarized form; without jq the raw manifest is embedded.

`aegiscope compare` compares two run manifests, defaulting to the two newest runs, and writes a Markdown diff into the current run directory.

## Interactive menu and colors

Run `./aegiscope` without a subcommand for the full nested menu. Colors identify banners, section headings, selectable numbers, prompts, success output, warnings, and errors. Color is automatically disabled for redirected output and can be explicitly disabled with `NO_COLOR=1`.

## Updates

`aegiscope update --check` fetches the tracked branch and reports whether it is current, behind, ahead, or diverged. It never modifies the working tree. Review changes and use `git pull --ff-only` manually.
