#!/usr/bin/env python3
"""IronCrypt Aegiscope asset workspace and reporting engine."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import html
import json
import sqlite3
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlparse


SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS runs (
  id TEXT PRIMARY KEY,
  target TEXT NOT NULL,
  operation TEXT NOT NULL,
  started_at TEXT,
  completed_at TEXT,
  status TEXT,
  manifest_path TEXT NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS assets (
  id INTEGER PRIMARY KEY,
  kind TEXT NOT NULL,
  value TEXT NOT NULL,
  first_seen TEXT NOT NULL,
  last_seen TEXT NOT NULL,
  UNIQUE(kind, value)
);
CREATE TABLE IF NOT EXISTS observations (
  run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
  asset_id INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  source TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  data_json TEXT NOT NULL DEFAULT '{}',
  UNIQUE(run_id, asset_id, source)
);
CREATE TABLE IF NOT EXISTS edges (
  run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
  source_asset_id INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  relation TEXT NOT NULL,
  target_asset_id INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  source TEXT NOT NULL,
  UNIQUE(run_id, source_asset_id, relation, target_asset_id, source)
);
CREATE TABLE IF NOT EXISTS findings (
  id INTEGER PRIMARY KEY,
  run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
  finding_key TEXT NOT NULL,
  severity TEXT NOT NULL,
  title TEXT NOT NULL,
  asset_value TEXT,
  source TEXT NOT NULL,
  evidence_json TEXT NOT NULL DEFAULT '{}',
  UNIQUE(run_id, finding_key, asset_value)
);
CREATE INDEX IF NOT EXISTS idx_assets_kind_value ON assets(kind, value);
CREATE INDEX IF NOT EXISTS idx_observations_run ON observations(run_id);
CREATE INDEX IF NOT EXISTS idx_edges_run ON edges(run_id);
CREATE INDEX IF NOT EXISTS idx_findings_run ON findings(run_id);
"""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def connect(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    connection.executescript(SCHEMA)
    return connection


def run_id_for(manifest: Path, data: dict[str, Any]) -> str:
    seed = f"{manifest.resolve()}|{data.get('started_at', '')}|{data.get('operation', '')}"
    return hashlib.sha256(seed.encode()).hexdigest()[:20]


def normalize_asset(kind: str, value: Any) -> str:
    text = str(value or "").strip()
    if kind in {"domain", "host", "technology", "service"}:
        text = text.lower().rstrip(".")
    if kind == "url":
        parsed = urlparse(text)
        if parsed.scheme and parsed.hostname:
            netloc = parsed.hostname.lower()
            if parsed.port:
                netloc += f":{parsed.port}"
            text = parsed._replace(netloc=netloc, fragment="").geturl()
    return text


def asset_kind(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme in {"http", "https"} and parsed.hostname:
        return "url"
    if ":" in value and all(part for part in value.split(":")):
        return "ipv6"
    parts = value.split(".")
    if len(parts) == 4 and all(part.isdigit() and 0 <= int(part) <= 255 for part in parts):
        return "ipv4"
    return "domain"


def add_asset(
    connection: sqlite3.Connection,
    run_id: str,
    kind: str,
    value: Any,
    source: str,
    observed_at: str,
    data: dict[str, Any] | None = None,
) -> int | None:
    normalized = normalize_asset(kind, value)
    if not normalized:
        return None
    connection.execute(
        """INSERT INTO assets(kind, value, first_seen, last_seen) VALUES(?, ?, ?, ?)
           ON CONFLICT(kind, value) DO UPDATE SET
             first_seen=MIN(assets.first_seen, excluded.first_seen),
             last_seen=MAX(assets.last_seen, excluded.last_seen)""",
        (kind, normalized, observed_at, observed_at),
    )
    row = connection.execute("SELECT id FROM assets WHERE kind=? AND value=?", (kind, normalized)).fetchone()
    assert row is not None
    asset_id = int(row["id"])
    connection.execute(
        """INSERT INTO observations(run_id, asset_id, source, observed_at, data_json)
           VALUES(?, ?, ?, ?, ?)
           ON CONFLICT(run_id, asset_id, source) DO UPDATE SET
             observed_at=excluded.observed_at, data_json=excluded.data_json""",
        (run_id, asset_id, source, observed_at, json.dumps(data or {}, sort_keys=True)),
    )
    return asset_id


def add_edge(
    connection: sqlite3.Connection,
    run_id: str,
    source_asset: int | None,
    relation: str,
    target_asset: int | None,
    source: str,
) -> None:
    if source_asset is None or target_asset is None:
        return
    connection.execute(
        """INSERT OR IGNORE INTO edges(run_id, source_asset_id, relation, target_asset_id, source)
           VALUES(?, ?, ?, ?, ?)""",
        (run_id, source_asset, relation, target_asset, source),
    )


def iter_jsonl(path: Path) -> Iterable[dict[str, Any]]:
    with path.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(value, dict):
                yield value


def list_values(value: Any) -> list[Any]:
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def safe_artifact_path(run_dir: Path, value: Any) -> Path | None:
    root = run_dir.resolve()
    candidate = (run_dir / str(value)).resolve()
    try:
        candidate.relative_to(root)
    except ValueError:
        return None
    return candidate


def ingest_jsonl(
    connection: sqlite3.Connection, run_id: str, path: Path, observed_at: str
) -> None:
    name = path.name.lower()
    for item in iter_jsonl(path):
        source = path.name
        if "nuclei" in name:
            matched = item.get("matched-at") or item.get("host") or item.get("url") or ""
            key = str(item.get("template-id") or item.get("template") or "nuclei-finding")
            info = item.get("info") if isinstance(item.get("info"), dict) else {}
            severity = str(info.get("severity") or item.get("severity") or "unknown").lower()
            title = str(info.get("name") or item.get("name") or key)
            if matched:
                add_asset(connection, run_id, asset_kind(str(matched)), matched, source, observed_at, item)
            connection.execute(
                """INSERT OR REPLACE INTO findings
                   (run_id, finding_key, severity, title, asset_value, source, evidence_json)
                   VALUES(?, ?, ?, ?, ?, ?, ?)""",
                (run_id, key, severity, title, str(matched), source, json.dumps(item, sort_keys=True)),
            )
            continue

        url = item.get("url") or item.get("endpoint") or item.get("matched-at")
        host = item.get("host") or item.get("input") or item.get("domain")
        if isinstance(host, str) and "://" in host:
            host = urlparse(host).hostname
        url_id = add_asset(connection, run_id, "url", url, source, observed_at, item) if url else None
        host_id = add_asset(connection, run_id, "domain", host, source, observed_at, item) if host else None
        if url_id and not host_id:
            parsed_host = urlparse(str(url)).hostname
            host_id = add_asset(connection, run_id, "domain", parsed_host, source, observed_at, item)
        add_edge(connection, run_id, host_id, "serves", url_id, source)

        for address in list_values(item.get("a") or item.get("ip") or item.get("host_ip")):
            ip_id = add_asset(connection, run_id, asset_kind(str(address)), address, source, observed_at, item)
            add_edge(connection, run_id, host_id, "resolves_to", ip_id, source)
        for address in list_values(item.get("aaaa")):
            ip_id = add_asset(connection, run_id, "ipv6", address, source, observed_at, item)
            add_edge(connection, run_id, host_id, "resolves_to", ip_id, source)
        for cname in list_values(item.get("cname")):
            cname_id = add_asset(connection, run_id, "domain", cname, source, observed_at, item)
            add_edge(connection, run_id, host_id, "cname", cname_id, source)
        for technology in list_values(item.get("tech") or item.get("technologies")):
            tech_id = add_asset(connection, run_id, "technology", technology, source, observed_at, {})
            add_edge(connection, run_id, url_id or host_id, "uses", tech_id, source)


def ingest_nmap(connection: sqlite3.Connection, run_id: str, path: Path, observed_at: str) -> None:
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError):
        return
    for host in root.findall("host"):
        addresses = [node.get("addr", "") for node in host.findall("address")]
        names = [node.get("name", "") for node in host.findall("hostnames/hostname")]
        host_ids = [
            add_asset(connection, run_id, asset_kind(value), value, path.name, observed_at, {})
            for value in names + addresses
            if value
        ]
        anchor = host_ids[0] if host_ids else None
        for port in host.findall("ports/port"):
            state = port.find("state")
            if state is None or state.get("state") != "open":
                continue
            protocol = port.get("protocol", "tcp")
            port_id = port.get("portid", "")
            service = port.find("service")
            service_name = service.get("name", "unknown") if service is not None else "unknown"
            endpoint = f"{addresses[0] if addresses else (names[0] if names else 'unknown')}:{port_id}/{protocol}"
            endpoint_id = add_asset(
                connection,
                run_id,
                "service",
                endpoint,
                path.name,
                observed_at,
                {"service": service_name, "port": port_id, "protocol": protocol},
            )
            add_edge(connection, run_id, anchor, "exposes", endpoint_id, path.name)


def ingest_api_inventory(
    connection: sqlite3.Connection, run_id: str, path: Path, observed_at: str
) -> None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return
    for endpoint in data.get("endpoints", []):
        value = endpoint.get("url") or endpoint.get("path")
        endpoint_id = add_asset(connection, run_id, "api-endpoint", value, path.name, observed_at, endpoint)
        for method in endpoint.get("methods", []):
            method_id = add_asset(connection, run_id, "http-method", method, path.name, observed_at, {})
            add_edge(connection, run_id, endpoint_id, "accepts", method_id, path.name)


def ingest_manifest(connection: sqlite3.Connection, manifest: Path) -> str:
    data = json.loads(manifest.read_text(encoding="utf-8"))
    run_id = run_id_for(manifest, data)
    observed_at = str(data.get("completed_at") or data.get("started_at") or utc_now())
    connection.execute(
        """INSERT OR REPLACE INTO runs
           (id, target, operation, started_at, completed_at, status, manifest_path)
           VALUES(?, ?, ?, ?, ?, ?, ?)""",
        (
            run_id,
            str(data.get("target", "")),
            str(data.get("operation", "unknown")),
            str(data.get("started_at", "")),
            str(data.get("completed_at", "")),
            str(data.get("status", "unknown")),
            str(manifest.resolve()),
        ),
    )
    target = str(data.get("target", ""))
    target_id = add_asset(connection, run_id, asset_kind(target), target, "manifest", observed_at, data)
    if target_id and asset_kind(target) == "url":
        hostname = urlparse(target).hostname
        hostname_id = add_asset(connection, run_id, "domain", hostname, "manifest", observed_at, {})
        add_edge(connection, run_id, hostname_id, "serves", target_id, "manifest")

    run_dir = manifest.parent
    artifacts = data.get("artifacts") if isinstance(data.get("artifacts"), list) else []
    candidates = {path for artifact in artifacts if (path := safe_artifact_path(run_dir, artifact)) is not None}
    candidates.update(run_dir.rglob("*.jsonl"))
    candidates.update(run_dir.rglob("*.xml"))
    candidates.update(run_dir.rglob("api-inventory.json"))
    for path in sorted(candidates):
        if not path.is_file():
            continue
        if path.name == "api-inventory.json":
            ingest_api_inventory(connection, run_id, path, observed_at)
        elif path.suffix.lower() == ".xml":
            ingest_nmap(connection, run_id, path, observed_at)
        elif path.suffix.lower() == ".jsonl":
            ingest_jsonl(connection, run_id, path, observed_at)
    connection.commit()
    return run_id


def command_assets(connection: sqlite3.Connection, args: argparse.Namespace) -> int:
    clauses: list[str] = []
    values: list[Any] = []
    if args.port:
        args.kind = "service"
        args.match = f":{args.port}/"
    if args.technology:
        args.kind = "technology"
        args.match = args.technology
    if args.kind:
        clauses.append("a.kind=?")
        values.append(args.kind)
    if args.match:
        clauses.append("a.value LIKE ?")
        values.append(f"%{args.match}%")
    query = """SELECT a.kind, a.value, a.first_seen, a.last_seen,
                      COUNT(DISTINCT o.run_id) AS run_count
               FROM assets a LEFT JOIN observations o ON o.asset_id=a.id"""
    if clauses:
        query += " WHERE " + " AND ".join(clauses)
    query += " GROUP BY a.id ORDER BY a.kind, a.value LIMIT ?"
    values.append(args.limit)
    rows = [dict(row) for row in connection.execute(query, values)]
    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        for row in rows:
            print(f"{row['kind']:<14} {row['value']:<60} runs={row['run_count']} last={row['last_seen']}")
    return 0


def command_graph(connection: sqlite3.Connection, args: argparse.Namespace) -> int:
    selected_asset = args.asset_option or args.asset
    if not selected_asset:
        raise ValueError("graph requires an asset value")
    rows = connection.execute(
        """SELECT sa.kind AS source_kind, sa.value AS source_value, e.relation,
                  ta.kind AS target_kind, ta.value AS target_value, e.source
           FROM edges e JOIN assets sa ON sa.id=e.source_asset_id
           JOIN assets ta ON ta.id=e.target_asset_id
           WHERE sa.value=? OR ta.value=? ORDER BY e.relation, sa.value, ta.value""",
        (selected_asset, selected_asset),
    ).fetchall()
    if args.format == "dot":
        print("digraph aegiscope {")
        for row in rows:
            left = json.dumps(f"{row['source_kind']}:{row['source_value']}")
            right = json.dumps(f"{row['target_kind']}:{row['target_value']}")
            print(f"  {left} -> {right} [label={json.dumps(row['relation'])}];")
        print("}")
    else:
        for row in rows:
            print(
                f"{row['source_kind']}:{row['source_value']} --{row['relation']}--> "
                f"{row['target_kind']}:{row['target_value']} [{row['source']}]"
            )
    return 0


def resolve_runs(connection: sqlite3.Connection, baseline: str | None, current: str | None) -> tuple[str, str]:
    runs = connection.execute("SELECT id FROM runs ORDER BY completed_at, rowid").fetchall()
    if baseline and current:
        return baseline, current
    if len(runs) < 2:
        raise ValueError("at least two ingested runs are required")
    return str(runs[-2]["id"]), str(runs[-1]["id"])


def run_assets(connection: sqlite3.Connection, run_id: str) -> set[tuple[str, str]]:
    rows = connection.execute(
        """SELECT a.kind, a.value FROM observations o JOIN assets a ON a.id=o.asset_id
           WHERE o.run_id=?""",
        (run_id,),
    )
    return {(str(row["kind"]), str(row["value"])) for row in rows}


def command_diff(connection: sqlite3.Connection, args: argparse.Namespace) -> int:
    if args.since:
        amount, unit = int(args.since[:-1]), args.since[-1].lower()
        if amount < 1 or unit not in {"h", "d", "w"}:
            raise ValueError("--since must use a positive duration such as 24h, 7d, or 4w")
        delta = {"h": dt.timedelta(hours=amount), "d": dt.timedelta(days=amount), "w": dt.timedelta(weeks=amount)}[unit]
        cutoff = (dt.datetime.now(dt.timezone.utc) - delta).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        rows = [
            dict(row)
            for row in connection.execute(
                "SELECT kind, value, first_seen, last_seen FROM assets WHERE first_seen>=? ORDER BY kind, value",
                (cutoff,),
            )
        ]
        result = {"since": args.since, "cutoff": cutoff, "added": rows, "removed": [], "unchanged_count": 0}
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"Assets first observed since {cutoff}:")
            for row in rows:
                print(f"  + {row['kind']}:{row['value']} first={row['first_seen']}")
        return 0
    baseline, current = resolve_runs(connection, args.baseline, args.current)
    before, after = run_assets(connection, baseline), run_assets(connection, current)
    result = {
        "baseline": baseline,
        "current": current,
        "added": [{"kind": kind, "value": value} for kind, value in sorted(after - before)],
        "removed": [{"kind": kind, "value": value} for kind, value in sorted(before - after)],
        "unchanged_count": len(before & after),
    }
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"Baseline: {baseline}\nCurrent:  {current}")
        print("\nAdded:")
        for item in result["added"]:
            print(f"  + {item['kind']}:{item['value']}")
        print("\nRemoved:")
        for item in result["removed"]:
            print(f"  - {item['kind']}:{item['value']}")
        print(f"\nUnchanged: {result['unchanged_count']}")
    return 0


def dashboard_html(connection: sqlite3.Connection) -> str:
    counts = connection.execute("SELECT kind, COUNT(*) count FROM assets GROUP BY kind ORDER BY count DESC").fetchall()
    assets = connection.execute("SELECT kind, value, last_seen FROM assets ORDER BY last_seen DESC LIMIT 500").fetchall()
    findings = connection.execute(
        "SELECT severity, title, asset_value, source FROM findings ORDER BY id DESC LIMIT 250"
    ).fetchall()
    runs = connection.execute(
        "SELECT operation, target, completed_at, status, manifest_path FROM runs ORDER BY completed_at DESC LIMIT 100"
    ).fetchall()
    edges = connection.execute(
        """SELECT sa.value source_value, e.relation, ta.value target_value, e.source
           FROM edges e JOIN assets sa ON sa.id=e.source_asset_id
           JOIN assets ta ON ta.id=e.target_asset_id ORDER BY e.rowid DESC LIMIT 500"""
    ).fetchall()
    cards = "".join(
        f'<div class="card"><strong>{html.escape(row["kind"])}</strong><span>{row["count"]}</span></div>'
        for row in counts
    )
    asset_rows = "".join(
        f"<tr><td>{html.escape(row['kind'])}</td><td>{html.escape(row['value'])}</td><td>{html.escape(row['last_seen'])}</td></tr>"
        for row in assets
    )
    finding_rows = "".join(
        f"<tr><td><span class='sev {html.escape(row['severity'])}'>{html.escape(row['severity'])}</span></td>"
        f"<td>{html.escape(row['title'])}</td><td>{html.escape(row['asset_value'] or '')}</td><td>{html.escape(row['source'])}</td></tr>"
        for row in findings
    ) or "<tr><td colspan='4'>No normalized findings</td></tr>"
    run_rows = "".join(
        f"<tr><td>{html.escape(row['operation'])}</td><td>{html.escape(row['target'])}</td>"
        f"<td>{html.escape(row['status'] or '')}</td><td>{html.escape(row['completed_at'] or '')}</td>"
        f"<td><code>{html.escape(row['manifest_path'])}</code></td></tr>"
        for row in runs
    )
    edge_rows = "".join(
        f"<tr><td>{html.escape(row['source_value'])}</td><td>{html.escape(row['relation'])}</td>"
        f"<td>{html.escape(row['target_value'])}</td><td>{html.escape(row['source'])}</td></tr>"
        for row in edges
    ) or "<tr><td colspan='4'>No relationships recorded</td></tr>"
    return f"""<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>IronCrypt Aegiscope Dashboard</title><style>
:root{{--bg:#071019;--panel:#0e1b27;--line:#203649;--text:#e6f0f6;--muted:#8ba2b4;--cyan:#29d3e2;--magenta:#d35cff;--green:#45df8b}}
*{{box-sizing:border-box}}body{{margin:0;background:linear-gradient(135deg,#050b11,#0a1824);color:var(--text);font:14px system-ui}}
header{{padding:28px 5vw;border-bottom:1px solid var(--line)}}h1{{margin:0;color:var(--cyan)}}header p{{color:var(--muted)}}main{{padding:24px 5vw}}
.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px}}.card{{background:var(--panel);border:1px solid var(--line);padding:16px;border-radius:10px;display:flex;justify-content:space-between}}.card span{{font-size:20px;color:var(--magenta)}}
section{{margin-top:28px}}table{{width:100%;border-collapse:collapse;background:var(--panel)}}th,td{{text-align:left;padding:9px;border-bottom:1px solid var(--line)}}th{{color:var(--cyan)}}.sev{{padding:2px 8px;border-radius:10px;background:#253444}}.sev.high,.sev.critical{{background:#782c43}}.sev.medium{{background:#695421}}
</style></head><body><header><h1>IRONCRYPT → AEGISCOPE</h1><p>Authorized reconnaissance asset intelligence • generated {html.escape(utc_now())}</p></header><main>
<div class="cards">{cards}</div><section><h2>Recent runs</h2><table><tr><th>Operation</th><th>Target</th><th>Status</th><th>Completed</th><th>Manifest evidence</th></tr>{run_rows}</table></section>
<section><h2>Findings</h2><table><tr><th>Severity</th><th>Title</th><th>Asset</th><th>Source</th></tr>{finding_rows}</table></section>
<section><h2>Asset relationships</h2><table><tr><th>Source</th><th>Relation</th><th>Target</th><th>Evidence source</th></tr>{edge_rows}</table></section>
<section><h2>Assets</h2><table><tr><th>Kind</th><th>Value</th><th>Last seen</th></tr>{asset_rows}</table></section></main></body></html>"""


def command_dashboard(connection: sqlite3.Connection, args: argparse.Namespace) -> int:
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(dashboard_html(connection), encoding="utf-8")
    print(output)
    return 0


def parse_postman(data: dict[str, Any]) -> dict[str, Any]:
    endpoints: list[dict[str, Any]] = []

    def walk(items: list[Any]) -> None:
        for item in items:
            if not isinstance(item, dict):
                continue
            if isinstance(item.get("item"), list):
                walk(item["item"])
            request = item.get("request")
            if not isinstance(request, dict):
                continue
            url = request.get("url")
            if isinstance(url, dict):
                url = url.get("raw")
            endpoints.append(
                {
                    "path": str(url or ""),
                    "url": str(url or ""),
                    "methods": [str(request.get("method") or "GET").upper()],
                    "parameters": [],
                }
            )

    walk(data.get("item", []))
    info = data.get("info") if isinstance(data.get("info"), dict) else {}
    return {"title": info.get("name", "Postman collection"), "version": "", "format": "postman", "security_schemes": [], "endpoints": endpoints}


def parse_burp(path: Path) -> dict[str, Any]:
    root = ET.parse(path).getroot()
    endpoints = []
    for item in root.findall(".//item"):
        url = item.findtext("url", "")
        method = item.findtext("method", "GET").upper()
        endpoints.append({"path": urlparse(url).path or url, "url": url, "methods": [method], "parameters": []})
    return {"title": "Burp export", "version": "", "format": "burp", "security_schemes": [], "endpoints": endpoints}


def load_structured(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        try:
            import yaml  # type: ignore[import-not-found]
        except ImportError as error:
            raise ValueError("YAML API input requires PyYAML/python3-yaml") from error
        value = yaml.safe_load(text)
    if not isinstance(value, dict):
        raise ValueError("API input must contain an object/document")
    return value


def parse_api_spec(path: Path, base_url: str | None, input_format: str) -> dict[str, Any]:
    if input_format == "burp" or (input_format == "auto" and path.suffix.lower() == ".xml"):
        return parse_burp(path)
    data = load_structured(path)
    if input_format == "postman" or (input_format == "auto" and isinstance(data.get("item"), list)):
        return parse_postman(data)
    endpoints: list[dict[str, Any]] = []
    methods = {"get", "put", "post", "delete", "options", "head", "patch", "trace"}
    for route, definition in (data.get("paths") or {}).items():
        if not isinstance(definition, dict):
            continue
        route_methods = sorted(method.upper() for method in definition if method.lower() in methods)
        endpoints.append(
            {
                "path": route,
                "url": f"{base_url.rstrip('/')}{route}" if base_url else route,
                "methods": route_methods,
                "parameters": sorted(
                    {
                        str(parameter.get("name"))
                        for method in definition.values()
                        if isinstance(method, dict)
                        for parameter in method.get("parameters", [])
                        if isinstance(parameter, dict) and parameter.get("name")
                    }
                ),
            }
        )
    components = data.get("components") if isinstance(data.get("components"), dict) else {}
    security = components.get("securitySchemes") if isinstance(components.get("securitySchemes"), dict) else {}
    if not security and isinstance(data.get("securityDefinitions"), dict):
        security = data["securityDefinitions"]
    return {
        "title": ((data.get("info") or {}).get("title") if isinstance(data.get("info"), dict) else "API"),
        "version": ((data.get("info") or {}).get("version") if isinstance(data.get("info"), dict) else ""),
        "format": "openapi" if data.get("openapi") else "swagger" if data.get("swagger") else "json-api",
        "security_schemes": sorted(security),
        "endpoints": endpoints,
    }


SEVERITY_ORDER = ("critical", "high", "medium", "low", "info", "informational", "unknown")


def report_profile(path: Path | None, manifest: dict[str, Any]) -> dict[str, Any]:
    target = str(manifest.get("target") or "unspecified target")
    profile: dict[str, Any] = {
        "engagement_name": f"Authorized Security Assessment - {target}",
        "client": "Not supplied",
        "assessment_type": "External reconnaissance and validation",
        "classification": "CONFIDENTIAL",
        "report_version": "0.1-draft",
        "report_status": "Draft - requires analyst review",
        "assessors": [],
        "authorization_reference": "Not supplied",
        "executive_summary": "",
        "strategic_recommendations": [
            "Manually validate automated findings and remove false positives before final issue.",
            "Prioritize confirmed issues using business context, exposure, and compensating controls.",
            "Retest remediated issues and retain the evidence package according to organizational policy.",
        ],
        "objectives": [
            "Identify externally observable assets, services, technologies, and security-relevant conditions within the authorized scope.",
            "Preserve reproducible command, tool-version, timeline, and evidence records for analyst validation.",
        ],
        "methodology": [
            "OWASP Web Security Testing Guide information-gathering and reporting structure",
            "NIST SP 800-115 planning, discovery, analysis, and reporting principles",
        ],
        "limitations": [
            "This is a point-in-time automated assessment; the environment can change after collection.",
            "Automated observations and scanner findings require qualified manual validation before risk acceptance or remediation decisions.",
            "Only the configured scope, selected command, available tools, credentials, and reachable attack surface were assessed.",
        ],
        "assumptions": ["The operator possessed written authorization for the recorded scope and testing window."],
        "distribution": ["Authorized client stakeholders", "Authorized assessment team"],
    }
    if path:
        supplied = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(supplied, dict):
            raise ValueError("report profile must contain a JSON object")
        profile.update(supplied)
    return profile


def evidence_inventory(manifest_path: Path, manifest: dict[str, Any]) -> list[dict[str, Any]]:
    evidence = manifest.get("evidence")
    if isinstance(evidence, list) and all(isinstance(item, dict) for item in evidence):
        inventory = []
        for source_item in evidence:
            item = dict(source_item)
            path = safe_artifact_path(manifest_path.parent, item.get("path", ""))
            if path is None:
                item["integrity_status"] = "outside-run-rejected"
            elif not path.is_file():
                item["integrity_status"] = "missing"
            else:
                digest = hashlib.sha256()
                with path.open("rb") as handle:
                    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                        digest.update(chunk)
                item["actual_size_bytes"] = path.stat().st_size
                item["actual_sha256"] = digest.hexdigest()
                try:
                    recorded_size = int(item.get("size_bytes", -1))
                except (TypeError, ValueError):
                    recorded_size = -1
                if item.get("sha256") in {None, "", "unavailable"}:
                    item["integrity_status"] = "unverifiable"
                elif item.get("sha256") != item["actual_sha256"] or recorded_size != item["actual_size_bytes"]:
                    item["integrity_status"] = "mismatch"
                else:
                    item["integrity_status"] = "verified"
            inventory.append(item)
        return inventory
    inventory: list[dict[str, Any]] = []
    artifacts = manifest.get("artifacts") if isinstance(manifest.get("artifacts"), list) else []
    for relative in artifacts:
        path = safe_artifact_path(manifest_path.parent, relative)
        if path is None:
            continue
        if not path.is_file():
            continue
        inventory.append(
            {
                "path": str(relative),
                "size_bytes": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "integrity_status": "calculated-legacy",
            }
        )
    return inventory


def report_findings(connection: sqlite3.Connection, manifest_path: Path, manifest: dict[str, Any]) -> list[dict[str, Any]]:
    run_id = run_id_for(manifest_path, manifest)
    rows = connection.execute(
        "SELECT finding_key, severity, title, asset_value, source, evidence_json FROM findings WHERE run_id=? ORDER BY id",
        (run_id,),
    ).fetchall()
    findings: list[dict[str, Any]] = []
    for index, row in enumerate(rows, 1):
        try:
            raw = json.loads(row["evidence_json"] or "{}")
        except json.JSONDecodeError:
            raw = {}
        info = raw.get("info") if isinstance(raw.get("info"), dict) else {}
        classification = info.get("classification") if isinstance(info.get("classification"), dict) else {}
        references = info.get("reference") or info.get("references") or raw.get("reference") or []
        if isinstance(references, str):
            references = [references]
        findings.append(
            {
                "reference_id": f"AEGIS-{index:03d}",
                "source_id": str(row["finding_key"]),
                "title": str(row["title"]),
                "severity": str(row["severity"] or "unknown").lower(),
                "affected_asset": str(row["asset_value"] or manifest.get("target") or "unspecified"),
                "source": str(row["source"]),
                "category": ", ".join(str(value) for value in list_values(info.get("tags") or raw.get("tags"))) or "Uncategorized",
                "status": "Unvalidated automated finding",
                "description": str(info.get("description") or raw.get("description") or "No source description was supplied; analyst review is required."),
                "impact": str(info.get("impact") or raw.get("impact") or "Business impact has not been established by automated reconnaissance."),
                "likelihood": str(info.get("likelihood") or raw.get("likelihood") or "Not assessed; determine during manual validation and threat analysis."),
                "remediation": str(info.get("remediation") or raw.get("remediation") or "Validate the condition, identify root cause, and define a system-specific corrective action."),
                "remediation_owner": "Not assigned",
                "target_date": "Not assigned",
                "cvss_score": classification.get("cvss-score") or info.get("cvss-score") or "",
                "cvss_vector": classification.get("cvss-metrics") or info.get("cvss-metrics") or "",
                "cve": classification.get("cve-id") or [],
                "cwe": classification.get("cwe-id") or [],
                "references": references if isinstance(references, list) else [],
                "evidence": raw,
            }
        )
    return findings


def structured_observations(manifest_path: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    run_dir = manifest_path.parent
    observations: dict[str, Any] = {}
    load_assessment = run_dir / "load-assessment.json"
    if load_assessment.is_file():
        try:
            observations["load_resilience"] = json.loads(load_assessment.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            observations["load_resilience"] = {"status": "unparseable", "artifact": load_assessment.name}
    api_inventory = run_dir / "api-inventory.json"
    if api_inventory.is_file():
        try:
            api_data = json.loads(api_inventory.read_text(encoding="utf-8"))
            observations["api_inventory"] = {
                "title": api_data.get("title"),
                "format": api_data.get("format"),
                "endpoint_count": len(api_data.get("endpoints", [])),
                "security_schemes": api_data.get("security_schemes", []),
            }
        except json.JSONDecodeError:
            observations["api_inventory"] = {"status": "unparseable", "artifact": api_inventory.name}
    xss_results = run_dir / "xss-results.jsonl"
    if xss_results.is_file():
        rows = list(iter_jsonl(xss_results))
        observations["xss_reflection_analysis"] = {
            "parameters_tested": len(rows),
            "reflected_parameters": sum(1 for item in rows if item.get("reflected") is True),
            "raw_punctuation_parameters": sum(1 for item in rows if item.get("raw_punctuation") is True),
            "status": "investigation leads only; executable XSS was not tested",
        }
    cors_analysis = run_dir / "api-cors-analysis.txt"
    if cors_analysis.is_file():
        observations["cors_analysis_artifact"] = cors_analysis.name
    http_analyses = sorted(path.name for path in run_dir.rglob("*-analysis.txt"))
    if http_analyses:
        observations["http_analysis_artifacts"] = http_analyses
    return observations


def required_tools_for(manifest: dict[str, Any]) -> list[str]:
    operation = str(manifest.get("operation") or "")
    if operation.startswith("pipeline-"):
        phase = operation.removeprefix("pipeline-").removesuffix("-resume")
        tools = []
        if phase in {"passive", "all"}:
            tools += ["subfinder"]
        if phase in {"verify", "active", "all"}:
            tools += ["dnsx", "httpx"]
        if phase in {"active", "all"}:
            tools += ["naabu", "nmap", "katana"]
        return tools
    if operation.startswith("ports-"):
        return ["nmap"]
    if operation == "nuclei-validate":
        return ["nuclei"]
    if operation.startswith("xss-") or operation.startswith("api-"):
        return ["curl"]
    if operation.startswith("load-"):
        return [operation.removeprefix("load-")]
    return []


def build_report_data(
    connection: sqlite3.Connection,
    manifest_path: Path,
    profile_path: Path | None,
    strict: bool,
) -> tuple[dict[str, Any], dict[str, Any]]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    profile = report_profile(profile_path, manifest)
    run_id = run_id_for(manifest_path, manifest)
    ingested_run = connection.execute("SELECT 1 FROM runs WHERE id=?", (run_id,)).fetchone() is not None
    findings = report_findings(connection, manifest_path, manifest)
    finding_overrides = profile.get("finding_overrides") if isinstance(profile.get("finding_overrides"), dict) else {}
    allowed_dispositions = {"confirmed", "false positive", "accepted risk", "remediated", "not applicable"}
    override_fields = {"status", "description", "impact", "likelihood", "remediation", "remediation_owner", "target_date", "cvss_score", "cvss_vector"}
    for finding in findings:
        override = finding_overrides.get(finding["source_id"]) or finding_overrides.get(finding["reference_id"])
        if not isinstance(override, dict):
            continue
        disposition = str(override.get("status") or "").strip()
        if disposition.lower() not in allowed_dispositions:
            raise ValueError(f"finding override {finding['source_id']} requires a recognized status")
        for field in override_fields:
            if field in override and override[field] is not None and override[field] != "":
                finding[field] = str(override[field])
    evidence = evidence_inventory(manifest_path, manifest)
    severity_counts = {severity: 0 for severity in SEVERITY_ORDER}
    for finding in findings:
        severity = finding["severity"]
        severity_counts[severity if severity in severity_counts else "unknown"] += 1
    executions = manifest.get("executions") if isinstance(manifest.get("executions"), list) else []
    execution_summary = {
        "total": len(executions),
        "succeeded": sum(1 for item in executions if isinstance(item, dict) and item.get("exit_code") == 0),
        "failed": sum(1 for item in executions if isinstance(item, dict) and item.get("exit_code") not in {0, None}),
    }
    checkpoints = []
    state_dir = manifest_path.parent / ".state"
    if state_dir.is_dir():
        for path in sorted(state_dir.glob("*.json")):
            try:
                checkpoints.append(json.loads(path.read_text(encoding="utf-8")))
            except (OSError, json.JSONDecodeError):
                continue
    tool_versions = manifest.get("tool_versions") if isinstance(manifest.get("tool_versions"), dict) else {}
    required_tools = required_tools_for(manifest)
    missing_tools = [tool for tool in required_tools if str(tool_versions.get(tool, "not installed")) == "not installed"]
    asset_counts = {
        str(row["kind"]): int(row["count"])
        for row in connection.execute(
            """SELECT a.kind, COUNT(DISTINCT a.id) count FROM observations o
               JOIN assets a ON a.id=o.asset_id WHERE o.run_id=? GROUP BY a.kind ORDER BY a.kind""",
            (run_id,),
        )
    }
    required_profile_fields = ("engagement_name", "client", "report_status", "assessors", "authorization_reference", "executive_summary", "strategic_recommendations", "objectives", "limitations")
    missing_profile = []
    for field in required_profile_fields:
        value = profile.get(field)
        if value is None or value == "" or value == "Not supplied" or value == []:
            missing_profile.append(field)
    findings_validated = all(finding["status"].lower() in allowed_dispositions for finding in findings)
    findings_requiring_validation = sum(1 for finding in findings if finding["status"].lower() not in allowed_dispositions)
    report_marked_final = str(profile.get("report_status") or "").strip().lower().startswith("final")
    integrity_failures = [item for item in evidence if item.get("integrity_status") in {"missing", "mismatch", "outside-run-rejected"}]
    execution_ledger_present = not manifest.get("commands") or bool(executions)
    quality = {
        "strict": strict,
        "ready_for_final": not missing_profile and report_marked_final and not missing_tools and manifest.get("status") == "completed" and findings_validated and not integrity_failures and ingested_run and execution_ledger_present,
        "missing_profile_fields": missing_profile,
        "missing_required_tools": missing_tools,
        "automated_findings_require_validation": findings_requiring_validation,
        "analyst_validation_complete": findings_validated,
        "report_marked_final": report_marked_final,
        "workspace_ingestion_complete": ingested_run,
        "execution_ledger_present": execution_ledger_present,
        "evidence_items": len(evidence),
        "evidence_with_sha256": sum(1 for item in evidence if item.get("sha256") and item.get("sha256") != "unavailable"),
        "evidence_integrity_failures": len(integrity_failures),
    }
    if strict and not quality["ready_for_final"]:
        raise ValueError(f"strict report quality gate failed: {json.dumps(quality, sort_keys=True)}")
    report = {
        "schema_version": "aegiscope-report-1.0",
        "generated_at": utc_now(),
        "profile": profile,
        "engagement": {
            "target": manifest.get("target"),
            "scope_key": manifest.get("scope_key"),
            "scope_file": manifest.get("scope_file"),
            "authorization": manifest.get("authorization", {}),
            "operation": manifest.get("operation"),
            "started_at": manifest.get("started_at"),
            "completed_at": manifest.get("completed_at"),
            "status": manifest.get("status"),
            "exit_code": manifest.get("exit_code"),
            "run_id": manifest.get("run_id") or manifest_path.parent.name,
        },
        "executive_summary": {
            "finding_count": len(findings),
            "severity_counts": severity_counts,
            "assessment_outcome": "Automated collection completed; findings require analyst validation."
            if manifest.get("status") == "completed"
            else "Collection was incomplete or encountered errors; review execution coverage before relying on results.",
            "risk_statement": "Scanner severity is technical evidence and an input to organizational risk management, not a final business-risk decision.",
        },
        "coverage": {
            "required_tools": required_tools,
            "missing_required_tools": missing_tools,
            "execution_summary": execution_summary,
            "checkpoints": checkpoints,
            "asset_counts": asset_counts,
        },
        "technical_observations": structured_observations(manifest_path, manifest),
        "findings": findings,
        "evidence": evidence,
        "commands": manifest.get("commands", []),
        "executions": executions,
        "tool_versions": tool_versions,
        "quality_gate": quality,
        "source_manifest": str(manifest_path.resolve()),
    }
    return report, quality


def markdown_cell(value: Any) -> str:
    return str(value if value is not None and value != "" else "-").replace("|", "\\|").replace("\n", " ")


def markdown_list(values: Any, fallback: str = "Not supplied") -> str:
    if not isinstance(values, list) or not values:
        return f"- {fallback}\n"
    return "".join(f"- {value}\n" for value in values)


def render_markdown_report(report: dict[str, Any]) -> str:
    profile, engagement = report["profile"], report["engagement"]
    summary, coverage, findings = report["executive_summary"], report["coverage"], report["findings"]
    lines = [
        f"# {profile['engagement_name']}",
        "",
        f"**Classification:** {profile['classification']}  ",
        f"**Client:** {profile['client']}  ",
        f"**Report version:** {profile['report_version']}  ",
        f"**Status:** {profile['report_status']}  ",
        f"**Generated:** {report['generated_at']}",
        "",
        "## Table of contents",
        "",
        "1. Document control",
        "2. Executive summary",
        "3. Engagement parameters",
        "4. Assessment coverage",
        "5. Technical observations",
        "6. Findings summary and details",
        "7. Evidence inventory",
        "8. Command and tool appendix",
        "9. Quality gate, severity model, and disclaimer",
        "",
        "## Document control",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Engagement | {markdown_cell(profile['engagement_name'])} |",
        f"| Client | {markdown_cell(profile['client'])} |",
        f"| Assessment type | {markdown_cell(profile['assessment_type'])} |",
        f"| Version | {markdown_cell(profile['report_version'])} |",
        f"| Status | {markdown_cell(profile['report_status'])} |",
        f"| Authorization reference | {markdown_cell(profile['authorization_reference'])} |",
        f"| Assessors | {markdown_cell(', '.join(profile['assessors']) if isinstance(profile['assessors'], list) else profile['assessors'])} |",
        "",
        "### Authorized distribution",
        "",
        markdown_list(profile.get("distribution"), "Restricted to authorized recipients").rstrip(),
        "",
        "## Executive summary",
        "",
        str(profile.get("executive_summary") or "This draft summarizes the recorded automated assessment outcome and requires engagement-specific business context before final issue."),
        "",
        summary["assessment_outcome"],
        "",
        summary["risk_statement"],
        "",
        "### Findings by severity",
        "",
        "| Critical | High | Medium | Low | Informational | Unknown |",
        "|---:|---:|---:|---:|---:|---:|",
        f"| {summary['severity_counts']['critical']} | {summary['severity_counts']['high']} | {summary['severity_counts']['medium']} | {summary['severity_counts']['low']} | {summary['severity_counts']['info'] + summary['severity_counts']['informational']} | {summary['severity_counts']['unknown']} |",
        "",
        "### Strategic recommendations",
        "",
        markdown_list(profile.get("strategic_recommendations")).rstrip(),
        "",
        "## Engagement parameters",
        "",
        "### Objectives",
        "",
        markdown_list(profile.get("objectives")).rstrip(),
        "",
        "### Scope and schedule",
        "",
        "| Parameter | Recorded value |",
        "|---|---|",
        f"| Target | `{markdown_cell(engagement['target'])}` |",
        f"| Scope key | `{markdown_cell(engagement['scope_key'])}` |",
        f"| Scope source | `{markdown_cell(engagement['scope_file'])}` |",
        f"| Operation | `{markdown_cell(engagement['operation'])}` |",
        f"| Started (UTC) | {markdown_cell(engagement['started_at'])} |",
        f"| Completed (UTC) | {markdown_cell(engagement['completed_at'])} |",
        f"| Run status | {markdown_cell(engagement['status'])} (exit {markdown_cell(engagement['exit_code'])}) |",
        "",
        "### Methodology",
        "",
        markdown_list(profile.get("methodology")).rstrip(),
        "",
        "### Limitations",
        "",
        markdown_list(profile.get("limitations")).rstrip(),
        "",
        "### Assumptions and rules of engagement",
        "",
        markdown_list(profile.get("assumptions")).rstrip(),
        f"- Authorization assertion: `{markdown_cell(engagement.get('authorization', {}).get('assertion'))}`",
        "- Scope membership and configured request-rate ceilings were enforced by Aegiscope before target contact.",
        "",
        "## Assessment coverage",
        "",
        f"- Executions recorded: {coverage['execution_summary']['total']}",
        f"- Successful executions: {coverage['execution_summary']['succeeded']}",
        f"- Failed executions: {coverage['execution_summary']['failed']}",
        f"- Required tools: {', '.join(coverage['required_tools']) or 'none identified for this operation'}",
        f"- Missing required tools: {', '.join(coverage['missing_required_tools']) or 'none'}",
        "",
        "### Observed assets",
        "",
        "| Asset type | Count |",
        "|---|---:|",
    ]
    lines += [f"| {markdown_cell(kind)} | {count} |" for kind, count in coverage["asset_counts"].items()]
    if not coverage["asset_counts"]:
        lines.append("| No normalized assets | 0 |")
    lines += ["", "## Technical observations", ""]
    if report["technical_observations"]:
        for name, observation in report["technical_observations"].items():
            lines += [f"### {name.replace('_', ' ').title()}", "", "```json", json.dumps(observation, indent=2, sort_keys=True), "```", ""]
    else:
        lines += ["No additional structured operational observations were produced by this run.", ""]
    lines += ["", "## Findings summary", "", "| Reference | Severity | Title | Affected asset | Validation status |", "|---|---|---|---|---|"]
    for finding in findings:
        lines.append(
            f"| {finding['reference_id']} | {markdown_cell(finding['severity'].upper())} | {markdown_cell(finding['title'])} | {markdown_cell(finding['affected_asset'])} | {markdown_cell(finding['status'])} |"
        )
    if not findings:
        lines.append("| - | - | No normalized vulnerability findings were produced by this run. This does not establish absence of vulnerabilities. | - | - |")
    lines += ["", "## Detailed findings", ""]
    for finding in findings:
        lines += [
            f"### {finding['reference_id']} - {finding['title']}",
            "",
            f"- **Severity:** {finding['severity'].upper()}",
            f"- **Affected asset:** `{finding['affected_asset']}`",
            f"- **Validation status:** {finding['status']}",
            f"- **Category:** {finding['category']}",
            f"- **Source:** {finding['source']} / {finding['source_id']}",
            f"- **CVSS:** {finding['cvss_score'] or 'Not supplied'} {finding['cvss_vector'] or ''}",
            f"- **CVE:** {', '.join(str(value) for value in finding['cve']) or 'Not supplied'}",
            f"- **CWE:** {', '.join(str(value) for value in finding['cwe']) or 'Not supplied'}",
            f"- **Remediation owner:** {finding['remediation_owner']}",
            f"- **Target date:** {finding['target_date']}",
            "",
            "**Description**",
            "",
            finding["description"],
            "",
            "**Likelihood and impact**",
            "",
            f"- Likelihood: {finding['likelihood']}",
            f"- Impact: {finding['impact']}",
            "",
            "**Remediation**",
            "",
            finding["remediation"],
            "",
            "**Evidence and reproduction**",
            "",
            f"Review source artifact `{finding['source']}` and the preserved command ledger. Mask sensitive values before external distribution.",
            "",
            "**References**",
            "",
            markdown_list(finding.get("references"), "No source references supplied").rstrip(),
            "",
        ]
    if not findings:
        lines += ["No detailed finding records are available. Review observations and raw evidence before drawing conclusions.", ""]
    lines += [
        "## Evidence inventory",
        "",
        "| Artifact | Bytes | SHA-256 | Integrity |",
        "|---|---:|---|---|",
    ]
    for item in report["evidence"]:
        lines.append(f"| `{markdown_cell(item.get('path'))}` | {item.get('size_bytes', '-')} | `{markdown_cell(item.get('sha256'))}` | {markdown_cell(item.get('integrity_status'))} |")
    if not report["evidence"]:
        lines.append("| No evidence artifacts recorded | - | - | - |")
    lines += ["", "## Command and tool appendix", "", "### Redacted command ledger", ""]
    lines += [f"{index}. `{command}`" for index, command in enumerate(report["commands"], 1)] or ["No commands recorded."]
    lines += ["", "### Tool versions", "", "| Tool | Version |", "|---|---|"]
    lines += [f"| {markdown_cell(tool)} | {markdown_cell(version)} |" for tool, version in sorted(report["tool_versions"].items())]
    lines += [
        "",
        "## Quality gate and disclaimer",
        "",
        f"- Ready for final issue: **{str(report['quality_gate']['ready_for_final']).lower()}**",
        f"- Report marked final: {str(report['quality_gate']['report_marked_final']).lower()}",
        f"- Missing profile fields: {', '.join(report['quality_gate']['missing_profile_fields']) or 'none'}",
        f"- Automated findings awaiting validation: {report['quality_gate']['automated_findings_require_validation']}",
        f"- Evidence integrity failures: {report['quality_gate']['evidence_integrity_failures']}",
        f"- Workspace ingestion complete: {str(report['quality_gate']['workspace_ingestion_complete']).lower()}",
        "",
        "This report describes a point-in-time authorized assessment. It is not a warranty that every vulnerability was identified. Technical severity and automated output must be combined with business context by the organization's risk owner.",
        "",
        "### Severity model",
        "",
        "- **Critical:** credible potential for catastrophic compromise or impact requiring immediate validation and response.",
        "- **High:** substantial compromise or impact likely to require urgent remediation.",
        "- **Medium:** meaningful weakness requiring planned remediation after contextual validation.",
        "- **Low:** limited direct impact or defense-in-depth weakness.",
        "- **Informational:** observation that improves understanding or hardening but is not itself a confirmed vulnerability.",
        "",
    ]
    return "\n".join(lines)


def render_html_report(report: dict[str, Any]) -> str:
    markdown = render_markdown_report(report)
    source_lines = markdown.splitlines()
    sections: list[str] = []
    in_list = False
    in_code = False
    index = 0
    while index < len(source_lines):
        line = source_lines[index]
        escaped = html.escape(line)
        if line.startswith("```"):
            if in_code:
                sections.append("</code></pre>")
                in_code = False
            else:
                sections.append("<pre><code>")
                in_code = True
            index += 1
            continue
        if in_code:
            sections.append(escaped)
            index += 1
            continue
        if line.startswith("|"):
            if in_list:
                sections.append("</ul>")
                in_list = False
            table_lines = []
            while index < len(source_lines) and source_lines[index].startswith("|"):
                table_lines.append(source_lines[index])
                index += 1
            rows = [[cell.strip() for cell in row.strip("|").split("|")] for row in table_lines]
            if len(rows) >= 2:
                sections.append("<table><thead><tr>" + "".join(f"<th>{html.escape(cell)}</th>" for cell in rows[0]) + "</tr></thead><tbody>")
                for row in rows[2:]:
                    sections.append("<tr>" + "".join(f"<td>{html.escape(cell)}</td>" for cell in row) + "</tr>")
                sections.append("</tbody></table>")
            continue
        if line.startswith("### "):
            if in_list:
                sections.append("</ul>")
                in_list = False
            sections.append(f"<h3>{html.escape(line[4:])}</h3>")
        elif line.startswith("## "):
            if in_list:
                sections.append("</ul>")
                in_list = False
            sections.append(f"<h2>{html.escape(line[3:])}</h2>")
        elif line.startswith("# "):
            sections.append(f"<h1>{html.escape(line[2:])}</h1>")
        elif line.startswith("- "):
            if not in_list:
                sections.append("<ul>")
                in_list = True
            sections.append(f"<li>{escaped[2:]}</li>")
        elif line:
            if in_list:
                sections.append("</ul>")
                in_list = False
            sections.append(f"<p>{escaped}</p>")
        index += 1
    if in_list:
        sections.append("</ul>")
    body = "\n".join(sections)
    return f"""<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(str(report['profile']['engagement_name']))}</title><style>
@page{{size:A4;margin:18mm}}:root{{--ink:#17212b;--navy:#11263a;--cyan:#087e8b;--line:#cad5df;--muted:#526575}}
body{{max-width:1100px;margin:0 auto;padding:36px;color:var(--ink);font:14px/1.55 system-ui,Arial;background:#fff}}
h1{{color:var(--navy);border-bottom:4px solid var(--cyan);padding-bottom:12px}}h2{{margin-top:34px;color:var(--navy);border-bottom:1px solid var(--line)}}h3{{color:var(--cyan)}}
p,li{{max-width:95ch}}code,pre{{font-family:ui-monospace,Consolas,monospace}}table{{width:100%;border-collapse:collapse;margin:12px 0 22px}}th,td{{border:1px solid var(--line);padding:7px;text-align:left;vertical-align:top}}th{{background:#edf4f7;color:var(--navy)}}
@media print{{body{{padding:0}}h2{{break-before:auto}}h3{{break-after:avoid}}table,pre{{break-inside:avoid}}}}
</style></head><body><div class="classification">{html.escape(str(report['profile']['classification']))}</div>{body}</body></html>"""


def command_report(connection: sqlite3.Connection, args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest)
    if not manifest_path.is_file():
        raise ValueError(f"manifest not found: {manifest_path}")
    profile_path = Path(args.profile) if args.profile else None
    if profile_path and not profile_path.is_file():
        raise ValueError(f"report profile not found: {profile_path}")
    report, quality = build_report_data(connection, manifest_path, profile_path, args.strict)
    output_dir = Path(args.output_dir) if args.output_dir else manifest_path.parent
    output_dir.mkdir(parents=True, exist_ok=True)
    formats = ("markdown", "html", "json", "csv") if args.format == "all" else (args.format,)
    outputs: list[Path] = []
    if "markdown" in formats:
        output = output_dir / "report.md"
        output.write_text(render_markdown_report(report), encoding="utf-8")
        outputs.append(output)
    if "html" in formats:
        output = output_dir / "report.html"
        output.write_text(render_html_report(report), encoding="utf-8")
        outputs.append(output)
    if "json" in formats:
        output = output_dir / "report.json"
        output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        outputs.append(output)
    if "csv" in formats:
        output = output_dir / "findings.csv"
        with output.open("w", encoding="utf-8", newline="") as handle:
            fields = ("reference_id", "severity", "title", "affected_asset", "status", "category", "source", "cvss_score", "cvss_vector", "cve", "cwe", "references", "description", "impact", "likelihood", "remediation", "remediation_owner", "target_date")
            writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
            writer.writeheader()
            for finding in report["findings"]:
                row = dict(finding)
                for field in ("cve", "cwe", "references"):
                    row[field] = "; ".join(str(value) for value in list_values(row.get(field)))
                writer.writerow(row)
        outputs.append(output)
    quality_output = output_dir / "report-quality.json"
    quality_output.write_text(json.dumps(quality, indent=2) + "\n", encoding="utf-8")
    outputs.append(quality_output)
    for output in outputs:
        print(output)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, help="SQLite asset database")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("init")
    ingest = subparsers.add_parser("ingest")
    ingest.add_argument("--manifest", required=True)
    assets = subparsers.add_parser("assets")
    assets.add_argument("--kind")
    assets.add_argument("--match")
    assets.add_argument("--port", type=int)
    assets.add_argument("--technology")
    assets.add_argument("--limit", type=int, default=200)
    assets.add_argument("--json", action="store_true")
    graph = subparsers.add_parser("graph")
    graph.add_argument("asset", nargs="?")
    graph.add_argument("--asset", dest="asset_option")
    graph.add_argument("--format", choices=("text", "dot"), default="text")
    diff = subparsers.add_parser("diff")
    diff.add_argument("--baseline")
    diff.add_argument("--current")
    diff.add_argument("--since")
    diff.add_argument("--json", action="store_true")
    dashboard = subparsers.add_parser("dashboard")
    dashboard.add_argument("--output", required=True)
    api = subparsers.add_parser("api-parse")
    api.add_argument("--input", required=True)
    api.add_argument("--output", required=True)
    api.add_argument("--base-url")
    api.add_argument("--format", choices=("auto", "openapi", "postman", "burp"), default="auto")
    fingerprint = subparsers.add_parser("fingerprint")
    fingerprint.add_argument("--path", required=True)
    report = subparsers.add_parser("report")
    report.add_argument("--manifest", required=True)
    report.add_argument("--profile")
    report.add_argument("--output-dir")
    report.add_argument("--format", choices=("markdown", "html", "json", "csv", "all"), default="markdown")
    report.add_argument("--strict", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    database = Path(args.db)
    connection = connect(database)
    try:
        if args.command == "init":
            print(database)
            return 0
        if args.command == "ingest":
            print(ingest_manifest(connection, Path(args.manifest)))
            return 0
        if args.command == "assets":
            return command_assets(connection, args)
        if args.command == "graph":
            return command_graph(connection, args)
        if args.command == "diff":
            return command_diff(connection, args)
        if args.command == "dashboard":
            return command_dashboard(connection, args)
        if args.command == "api-parse":
            inventory = parse_api_spec(Path(args.input), args.base_url, args.format)
            output = Path(args.output)
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
            print(output)
            return 0
        if args.command == "fingerprint":
            selected = Path(args.path)
            if selected.is_symlink():
                raise ValueError("fingerprint input cannot be a symbolic link")
            files = [selected] if selected.is_file() else sorted(path for path in selected.rglob("*") if path.is_file())
            digest = hashlib.sha256()
            for file_path in files:
                if file_path.is_symlink():
                    raise ValueError(f"fingerprint tree contains a symbolic link: {file_path}")
                digest.update(str(file_path.relative_to(selected) if selected.is_dir() else file_path.name).encode())
                digest.update(file_path.read_bytes())
            print(digest.hexdigest())
            return 0
        if args.command == "report":
            return command_report(connection, args)
    except (OSError, ValueError, json.JSONDecodeError, sqlite3.Error) as error:
        print(f"workspace error: {error}", file=sys.stderr)
        return 1
    finally:
        connection.close()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
