# Security Policy

IronCrypt Aegiscope is an authorization-first reconnaissance tool. Security reports that help protect its users, assessment data, credentials, and authorized scope boundaries are welcome.

## Supported Versions

Security fixes are provided for the current minor release line. Users should reproduce an issue on the latest available patch release before reporting it.

| Version | Supported |
| ------- | --------- |
| 0.4.x   | ✅        |
| 0.3.x   | ❌        |
| < 0.3   | ❌        |

Unsupported versions may still receive documentation corrections, but no security backports are promised.

## Security Scope

Examples of issues that are in scope include:

- bypasses of the authorized-scope file, explicit authorization checks, or request-rate ceilings;
- shell or command injection, unsafe argument construction, path traversal, or unintended command execution;
- disclosure or unsafe storage of authentication headers, cookies, tokens, request bodies, or other secrets;
- incomplete redaction of manifests, reports, logs, command ledgers, or error output;
- tampering with evidence, manifests, checksums, report-quality gates, or run-history integrity;
- unsafe plugin containment, updater behavior, resume/cache isolation, or cross-target data reuse;
- unintended contact with out-of-scope hosts through redirects, DNS resolution, crawling, validation, or third-party integrations; and
- vulnerabilities in Aegiscope's use of an external dependency when the integration creates a distinct security impact.

The following are normally out of scope:

- vulnerabilities that exist only in an upstream tool and are not caused or amplified by Aegiscope;
- findings produced against a reconnaissance target rather than against Aegiscope itself;
- reports about unsupported versions that do not reproduce on the latest `0.4.x` release;
- automated scanner output without a reproducible security impact;
- social engineering, physical attacks, credential stuffing, denial-of-service testing, or disruption of project infrastructure; and
- use of Aegiscope outside written authorization or applicable law.

## Reporting a Vulnerability

Do not disclose a suspected vulnerability in a public issue, discussion, pull request, log, screenshot, or social-media post.

Use [GitHub's private vulnerability reporting form](https://github.com/Master-Panpour/Tool/security/advisories/new). If that form is unavailable, open a minimal [public issue](https://github.com/Master-Panpour/Tool/issues/new) titled **Private security contact requested**. Include no vulnerability details, proof of concept, secrets, target information, or sensitive artifacts in that issue; a maintainer will arrange a private channel.

Include the following when possible:

- affected Aegiscope version, commit SHA, operating system, shell, and relevant external-tool versions;
- a concise description of the vulnerability and its security impact;
- the affected command, component, or trust boundary;
- minimal reproduction steps performed in an isolated system you own or are authorized to test;
- sanitized logs, manifests, or artifacts with credentials and client/target data removed;
- whether exploitation crosses an authorized scope, exposes secrets, corrupts evidence, or executes commands; and
- suggested remediation or disclosure constraints, if any.

Never submit live credentials, private keys, access tokens, client data, or unredacted assessment evidence. If a repository secret is discovered, do not use it; report it immediately and delete unnecessary local copies.

## Response Process

These are response targets rather than a service-level agreement:

1. We aim to acknowledge a complete report within **3 business days**.
2. We aim to provide an initial triage decision within **7 business days**.
3. For an accepted report, we will assess severity, identify affected versions, and agree on a coordinated-disclosure plan.
4. We aim to provide a status update at least every **14 calendar days** while remediation is active.
5. When a fix is ready, we may publish a security advisory, patched release, migration guidance, and credit to the reporter if requested.

If a report is declined, we will explain the reason when practical—for example, inability to reproduce, an upstream-only defect, expected documented behavior, unsupported configuration, or lack of security impact.

Please allow a reasonable remediation period before public disclosure. A common target is up to **90 days**, adjusted for severity, active exploitation, fix complexity, and downstream coordination. Earlier disclosure may be appropriate when a fix is available or users face immediate risk.

## Research and Safe Harbor

Security research under this policy must:

- use only accounts, systems, targets, and data you own or have explicit permission to test;
- use the minimum activity necessary to demonstrate the issue;
- avoid persistence, data destruction, privacy violations, service degradation, and access to another person's data;
- stop testing and report promptly if sensitive data is encountered;
- comply with applicable law and third-party terms; and
- keep vulnerability details confidential until coordinated disclosure.

Good-faith research that follows this policy will be treated as authorized for this project, and IronCrypt will not recommend legal action based solely on that compliant research. This statement does not authorize testing of third-party systems and is not legal advice.

## Severity and Remediation

Triage considers practical exploitability and impact, with particular attention to command execution, credential exposure, authorization or scope bypass, cross-target data leakage, evidence integrity, and availability. Scanner severity alone does not determine the final rating.

Fixes may include code changes, safer defaults, additional validation, dependency constraints, documentation, or a decision that the behavior is expected. Security fixes are tested through the project's Linux CI and mocked Bats suite before release when feasible.

## Recognition and Bounties

With permission, accepted reporters may be credited in the advisory, release notes, or changelog. Anonymous reporting is respected. This project does not currently operate a paid bug-bounty program, and submission does not create an entitlement to payment.

## Security Updates

Security notices and patched versions are published through [GitHub Security Advisories](https://github.com/Master-Panpour/Tool/security/advisories) and repository releases or changelog entries. Users should update to the newest supported `0.4.x` patch and review any accompanying migration instructions.
