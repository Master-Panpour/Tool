# Changelog

## 0.4.1 - Unreleased

### Added

- Permanent IronCrypt Sentinel ASCII mascot header.
- Persistent `IronCrypt • Made by Master_Panpour & Master_Demon` credit footer across every banner style.

### Changed

- The permanent mascot header is now the default terminal design and is selectable from the Environment & design menu.

## 0.4.0 - 2026-07-18

### Added

- SQLite asset, observation, relationship, finding, history, graph, and dashboard workspace.
- Passive/verification/active reconnaissance pipeline with checkpoints, cache, resume, and failed-step retry.
- OpenAPI, Swagger, Postman, Burp, GraphQL capability, CORS, and Nuclei validation workflows.
- Credential profiles, reviewed plugin adapters, and three animated terminal-header designs.
- Versioned manifests with authorization/scope evidence, redacted execution outcomes, and SHA-256 artifact inventory.
- Enterprise Markdown, print-ready HTML, JSON, findings CSV, and report-quality outputs.
- Per-finding analyst dispositions and strict final-report readiness enforcement.

### Changed

- Missing required pipeline tools and failed required reconnaissance stages now return failing automation status.
- Nmap pipeline coverage now consumes every resolved in-scope host.
- Derived hosts are scope-filtered before verification; Katana is constrained to FQDN scope.
- Automatic HTTP redirects, Nuclei redirects, and interactsh are disabled to prevent implicit out-of-scope contact.
- Pipeline resume is locked to the original target and preserves prior manifests, plans, and checkpoint history.
- Load-resilience assessment treats HTTP 4xx/5xx responses as failed requests and retains hard traffic caps.

### Security and auditability

- HTTP header validation rejects control-character injection.
- Plugin artifacts must remain inside their run directory.
- Nuclei template fingerprints reject symbolic links and require exact SHA-256 syntax.
- Formal reports re-hash evidence and reject tampered or missing evidence under the strict quality gate.
