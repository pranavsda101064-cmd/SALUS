# SALUS API contract

Version: 1.0-demo. Frozen for the hackathon build.
Fixtures in this folder are generated from the live API by `scripts/export_fixtures.py`.

All endpoints are under `/api/v1`. Timestamps are UTC ISO 8601 with `Z`.
All records are synthetic. No real personal data is used.

## Authentication

- `POST /auth/demo-login` with `{"email": "meera@acmetraders.test"}` returns a token.
- Send `Authorization: Token <token>` on every other endpoint.
- `GET /health`, `GET /risk/policy` and `GET /simulation/ghost-copy` are open.
- `GET /simulation/ghost-copy` is demo only. It returns the synthetic ORG-01 storyboard, never raw cell values, and returns 403 when `SALUS_DEMO_MODE` is off.
- `POST /dev/seed` is open in the demo build so a fresh Render database can be initialized from the login screen.
- Demo login and seed require `SALUS_DEMO_MODE=1`. Outside demo mode they return 403.
- `GET /health` checks the database and returns 503 when it is unavailable.
- Throttle scopes: login 20 per minute, seed 5 per minute, upload 30 per minute, report 30 per minute, anonymous 60 per minute, authenticated 600 per minute.

## Identifiers

| Prefix | Object | Example |
|---|---|---|
| ORG | organization | ORG-01 |
| USER | user | USER-104 |
| SL | asset | SL-9281 |
| EV | event | EV-10021 |
| MT | match | MT-2001 |
| RS | risk assessment | RS-3001 |
| INC | incident | INC-4001 |
| INV | investigation | INV-6001 |
| RP | report | RP-5001 |
| CN | canary issuance | CN-007 |

## Enums

- `action`: FILE_VIEWED, FILE_DOWNLOADED, FILE_COPIED, EXTERNAL_SHARE, SUSPECT_UPLOAD
- `source`: SIMULATOR, INTAKE, CONNECTOR, MANUAL
- `kind`: ORIGINAL, DERIVED, SUSPECT
- `sensitivity`: LOW, MEDIUM, HIGH, CRITICAL
- `pii_type`: NAME, EMAIL, PHONE, AADHAAR, PAN, GSTIN, UPI_ID, FINANCIAL_ACCOUNT, FINANCIAL_AMOUNT, IFSC, LOCATION, OTHER
- `incident status`: OPEN, TRIAGED, CONTAINED, CLOSED
- `investigation status`: OPEN, CLOSED, NO_MATCH
- `risk band`: LOW, MEDIUM, HIGH, CRITICAL
- `report provider`: SALUS_TEMPLATE, GEMINI
- lineage ref type: EVENT, MATCH

## Standard event schema

This is the only write shape for activity. Event IDs are unique per organization for deduplication.

```json
{
  "event_id": "EV-10021",
  "organization_id": "ORG-01",
  "actor_id": "USER-104",
  "asset_id": "SL-9281",
  "action": "FILE_DOWNLOADED",
  "source": "SIMULATOR",
  "destination": "local_device",
  "timestamp": "2026-11-12T17:10:00Z",
  "evidence": {"rows": 1000, "bytes": 184320, "simulated": true},
  "simulated": true
}
```

Event API responses include `simulated`. The UI must show the SIMULATED label when it is true.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | /health | open | Liveness and report provider |
| POST | /auth/demo-login | open | Demo token |
| GET | /organizations/me | token | Current user and org |
| GET | /overview | token | Command center counts |
| GET | /assets | token | Non baseline assets |
| POST | /assets | token | Multipart upload of a dataset |
| GET | /assets/{asset_id} | token | Asset metadata and PII scan |
| GET | /assets/{asset_id}/events | token | Events for one asset |
| GET | /investigations | token | Investigation list with risk and match summary |
| POST | /investigations | token | Multipart suspect upload, full incident bundle, deduplicated on input SHA-256 |
| GET | /investigations/{investigation_id} | token | Incident bundle, or a no match summary |
| GET | /audit | token | Organization scoped audit trail, filter by entity_type and entity_id |
| GET | /incidents | token | Incident list |
| GET | /incidents/{incident_id} | token | Full bundle with lineage and report |
| GET | /incidents/{incident_id}/lineage | token | Nodes and edges with refs |
| POST | /incidents/{incident_id}/status | token | status in body |
| POST | /incidents/{incident_id}/report | token | Regenerate report |
| GET | /events | token | Filter by asset_id, actor_id, action, source, limit |
| POST | /simulator/run | token | Replay the ghost copy scenario with fresh event IDs |
| POST | /dev/seed | open | Idempotent seed, optional reset |
| GET | /risk/policy | open | Weights, tables, bands, disclaimer |
| GET | /simulation/ghost-copy | open, demo only | Sanitized Ghost Copy storyboard for the landing simulation |

List endpoints accept `limit` and `offset` and return `results`, `count`, `limit`, `offset`. The maximum limit is 500.

Errors use `{"detail": "message"}` with an HTTP status code. Upload parsing errors, invalid limits and foreign actors return 400. Unknown or cross tenant objects return 404.

`POST /investigations` returns:

```json
{
  "matched": true,
  "duplicate": false,
  "investigation": {},
  "bundle": {}
}
```

A second upload of the same file by the same organization returns the existing investigation with `"duplicate": true` and the same incident. No new suspect asset or incident is created.

## Response fixtures

| Fixture | Endpoint |
|---|---|
| `login.json` | POST /auth/demo-login |
| `health.json` | GET /health |
| `overview.json` | GET /overview |
| `asset.json` | GET /assets/SL-9281 |
| `event.json` | GET /events?asset_id=SL-9281 |
| `incident_list.json` | GET /incidents |
| `incident_bundle.json` | GET /incidents/INC-4001 |
| `match.json` | bundle.match |
| `risk.json` | bundle.risk |
| `lineage.json` | bundle.lineage |
| `report.json` | bundle.report |
| `investigation.json` | bundle.investigation |
| `audit_trail.json` | bundle.audit_trail |
| `investigation_list.json` | GET /investigations |
| `audit.json` | GET /audit?entity_id=INC-4001 |
| `risk_policy.json` | GET /risk/policy |
| `simulation_storyboard.json` | GET /simulation/ghost-copy |

## Data DNA and matching

Normalization before hashing:

- Unicode NFKC, trim, collapse whitespace, lowercase.
- Phone and Aadhaar style values with 10 to 16 digits lose spaces, dashes, plus and brackets.
- The column name is not part of the cell hash. This is why a dropped or renamed column does not break the match.
- Hash: SHA-256 of `organization_salt + "|" + normalized_value`.
- Raw values are not stored.

Cell weight from in file frequency:

```text
w = log(1 + N / frequency)
```

`N` is the source row count. A value that appears once weighs far more than a city repeated 900 times.

Metrics per source:

- `containment`: shared source weight divided by query weight, where shared cells use source weight and unknown cells use query weight.
- `recall_vs_original`: matched query rows divided by source row count. This is the "about 30 percent" number used in the demo.
- `cell_recall`: weighted cell recall, stored in `match.evidence.cell_recall` for transparency.
- `matched_rows`: query rows with at least one rare matched cell or at least 3 matched cells. This prevents a file that only shares common values such as city and department from creating an incident.
- `rare_matched_rows`: rows with at least one rare matched cell.
- `matched_columns`: query columns with at least 50 percent of cells present in the source.
- `dropped_columns`: source columns with under 5 percent of their values present in the query.
- `match_score = min(0.999, 0.7 * containment + 0.3 * (1 - exp(-rare_shared / 40)))`.
- `rare_shared` counts shared values whose source weight is at or above `max(1.0, 0.5 * log(1 + N))`. Rarity is relative to the source size.
- A match must have at least one rare shared value and at least one matched row, unless it is an exact file copy.
- An exact file SHA-256 match short circuits to score 1.0.

Thresholds: an investigation below `SALUS_MATCH_THRESHOLD` (default 0.3) returns `matched: false` and creates a `NO_MATCH` investigation, not an incident.

India PII checks include the Aadhaar Verhoeff checksum and the GSTIN base 36 check digit. A GSTIN column is labelled even when some values fail the checksum, and `valid_count` and `invalid_count` report the split.

Canary detection uses six identifier columns: email, phone, aadhaar, pan, gstin, upi_id. It reports the issuance, recipient, matched values and matched rows. A canary can be stripped and it is never the only signal.

MinHash or LSH is the scaling path. The demo uses exact set overlap because it is deterministic at this size.

## Risk policy

```text
R = 0.35*S + 0.30*D + 0.20*B + 0.15*E
```

All factors are 0 to 100. These are demo policy values, not validated standards.

- S: `0.6 * highest matched column sensitivity + 0.4 * mean`, capped at 100. Column scores: AADHAAR 100, PAN 95, FINANCIAL_ACCOUNT 92, GSTIN 85, UPI_ID 82, EMAIL 80, PHONE 78, FINANCIAL_AMOUNT 75, IFSC 70, NAME 55, LOCATION 35, OTHER 10.
- D: destination trust risk from the most severe correlated external share. Fallbacks: download destination, then 20. Values: internal_drive 10, internal_share 15, local_device 25, known_partner 35, personal_email 65, unknown external 85, public_url 95.
- B: behaviour autoencoder reconstruction error mapped to 0 to 100. `100 * (error / baseline_p95)^0.7`, capped. Percentile and top contributing features are returned. A neutral 50 is used when no baseline exists.
- E: 10 base, plus 25 after hours (before 08:00 or from 20:00 IST, or weekend), 25 download then external share within 24 hours, 15 external share with no download or copy event, 20 canary present, 15 high match confidence, 15 bulk volume of 500 or more rows, 10 repeated access in 7 days. Capped at 100.
- Bands: CRITICAL at 75 and above, HIGH at 55, MEDIUM at 30, LOW below 30.

The engine is deterministic. The language model only explains the stored evidence.

## Report schema

Both the deterministic composer and Gemini return the same shape:

```json
{
  "summary": "string",
  "what_left": ["string"],
  "who_moved_it": {
    "assessment": "string",
    "confidence": "HIGH",
    "basis": ["EV-10021"]
  },
  "why_flagged": [{"factor": "S", "reason": "string", "points": 32.2}],
  "recommended_actions": [{"priority": 1, "action": "string", "why": "string"}],
  "limitations": ["string"],
  "grounding_refs": ["MT-2001", "RS-3001", "EV-10021"],
  "evidence_hash": "sha256 of the canonical evidence JSON",
  "provider": "SALUS_TEMPLATE",
  "model": "",
  "engine_note": "optional, only when Gemini was attempted and failed"
}
```

Gemini rules:

- The prompt contains only the structured evidence JSON and the schema.
- The model must not invent events, people, destinations or numbers.
- Response is JSON with `responseMimeType: application/json`.
- Every `EV`, `MT`, `RS`, `INC`, `SL`, `USER`, `ORG`, `INV` and `CN` reference in the response must exist in the evidence. Unknown references reject the response.
- Risk points, limitations and grounding references always come from the deterministic engine, even when Gemini writes the prose.
- Any failure returns the deterministic report. The UI shows which provider produced the text.
- `evidence_hash` is computed from the stored evidence and changes only when the evidence changes.

## Lineage rules

- Every edge has `ref: {"type": "EVENT" | "MATCH", "id": "..."}`.
- A download or share edge requires a stored event.
- A derived-from edge requires a stored match.
- Similarity alone never creates a download or share edge.
- The graph is computed on read from events and matches. There is no writable edge table.

## Backend models

- `Investigation`: first class intake record. Organization, created by, source asset, suspect asset, match, incident, input filename, input SHA-256, rows, columns, status and created at. Unique on organization and input SHA-256, so the same file is not investigated twice.
- `AuditLog`: organization, actor, action, entity type, entity id, detail JSON and created at. Records investigation creation, duplicate intake, incident status changes, report regeneration and demo seed.
- `Event.actor_ref`: nullable foreign key to the organization user. `actor_id` remains the standard schema string, so future connectors can carry external actors while simulator and intake events are validated against the organization.
- `Report.evidence_hash`: SHA-256 of the canonical incident evidence JSON. The report is tied to the exact evidence that produced it.

The incident bundle includes `investigation`, `audit_trail`, `match`, `risk`, `report` and `lineage`. A no match intake creates a `NO_MATCH` investigation with no incident.

## Tenancy and privacy

- Every model has an organization foreign key.
- Every query filters by `request.user.organization`.
- Cross organization asset, investigation, incident and audit lookups return 404 or an empty list.
- Event actors must belong to the organization for simulator, intake and manual sources. Connector events can carry an external actor string with no user reference.
- Raw uploads are parsed in memory and not persisted. Only hashes, labels, schema and aggregates are stored.
- The hash salt is per deployment in this build. Production should use a per organization secret.

## UI copy rules

- Simulated events carry a visible SIMULATED label.
- A match is a lead, not proof of intent.
- State the limits: no USB copies, screenshots, retyped data, or activity outside connected sources.
- No covert surveillance. Everything monitored is authorized and visible.
- No em dashes in user facing text or docs.
