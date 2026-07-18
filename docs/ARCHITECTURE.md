# Aegiscope architecture

## Layers

1. `bin/aegiscope` is the operator interface: subcommands, validation, menus, and orchestration.
2. `lib/core.sh` owns scope enforcement, authorization assertions, request ceilings, redaction, run directories, atomic versioned manifests, execution ledgers, evidence hashes, and terminal design.
3. `lib/advanced.sh` owns phased pipelines, checkpoints/cache, credential profiles, API recon, Nuclei policy, and workspace wrappers.
4. `lib/workspace.py` provides the SQLite schema, artifact normalization, queries, graphs, history, API import, fingerprints, and HTML dashboard.
5. `lib/plugins.sh` defines the reviewed local-adapter contract; `plugins/` contains adapters.

## Evidence flow

```text
authorized target
  -> phased tool execution
  -> original artifacts + exact redacted commands
  -> manifest.json (scope snapshot, execution outcomes, evidence SHA-256)
  -> automatic SQLite ingestion
  -> assets / observations / edges / findings
  -> queries, graphs, historical diffs, and HTML dashboard
```

Original artifacts remain the source evidence. Normalization adds a searchable cross-run view but does not replace raw tool output.

## Pipeline state

Each pipeline run contains `.state/<tool>.completed.json` checkpoints and a `pipeline-policy.json` description. Missing required tools produce skipped checkpoints and a failing pipeline exit. `resume` validates the original target and skips completed steps. `retry --failed-only` bypasses cache for incomplete steps. Earlier manifests, plans, and failed states are moved into history rather than discarded. Cache entries are target and credential-profile scoped, published atomically, and expire according to `--cache-ttl`.

## Reporting model

`lib/workspace.py report` combines a run manifest with normalized findings and assets. It emits Markdown, print-ready HTML, JSON, findings CSV, and `report-quality.json`. Evidence is re-hashed at report time. The strict gate requires complete engagement metadata, successful coverage, required tools, workspace ingestion, intact evidence, and a recognized per-finding analyst disposition supplied through `finding_overrides`. The section model follows OWASP WSTG reporting guidance and NIST SP 800-115 assessment principles.

## Extension contract

A plugin is a locally reviewed shell file that implements metadata plus check, command-build, execute, normalize, and artifact hooks. The loader validates names and contract functions before use. Plugins still run through the same scope, authorization, rate, run-manifest, and artifact controls as built-in commands.

## Trust boundaries

- Scope files and authorization assertions control target eligibility.
- Request-rate validation is applied before network contact and passed to supported integrations.
- Credential profiles live outside command history and are redacted in display/manifests.
- Nuclei rejects unsigned templates and can require an exact content fingerprint for a reviewed template tree.
- External binaries and plugins are dependencies, not trusted data; preserve their versions and review updates before operational use.
- Results can contain sensitive assessment evidence and must be access-controlled accordingly.
