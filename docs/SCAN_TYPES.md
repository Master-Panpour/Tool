# Aegiscope port-scan profiles

| Profile | Nmap behavior | Purpose |
|---|---|---|
| `quick-tcp` | `-sT --top-ports 1000 -sV` | Privilege-friendly service inventory |
| `full-tcp` | `-sT -p- -sV` | Exhaustive TCP inventory; potentially long-running |
| `udp-top` | `-sU --top-ports 100 -sV` | Bounded UDP service discovery |
| `firewall-map` | `-sA --top-ports 1000` | Filtered/unfiltered firewall-path mapping, not open-port discovery |
| `custom` | Validated scan type and port expression | Explicit advanced assessment |

Every profile also receives `--max-rate <request-rate>` and `-oA <run-directory>/nmap`.

Normal Nmap host discovery is enabled by default. `--skip-host-discovery` adds `-Pn`, causing Nmap to treat the target as online. This can make scans slower and should only be used when discovery probes are known to be blocked.

Custom scan types are `connect`, `syn`, `null`, `fin`, `xmas`, `ack`, and `udp`. `--service-detection` explicitly adds `-sV`. A custom port expression is limited to numeric Nmap port syntax rather than accepting arbitrary Nmap arguments.

Some raw-packet scans require elevated privileges. Aegiscope does not invoke `sudo` automatically.
