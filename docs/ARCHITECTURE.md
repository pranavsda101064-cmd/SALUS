# SALUS architecture

## One line

Metadata first investigation for small businesses: detect sensitive data, fingerprint cells, match partial copies, correlate real events, score risk deterministically, and explain the result.

## Request path

```text
CSV or XLSX upload
  -> parse in memory, no raw persistence
  -> PII scan and sensitivity labels
  -> cell fingerprints and rarity weights
  -> SUSPECT asset
  -> match against ORIGINAL assets in the same organization
  -> canary check
  -> correlate stored events by source asset, actor and time window
  -> deterministic risk S, D, B, E
  -> investigation, incident, risk snapshot, grounded report
  -> audit trail for intake, status and report changes
  -> lineage derived from events and match
```

## Apps

| App | Responsibility |
|---|---|
| organizations | Organization, user, audit log, tenant anchor |
| assets | Dataset metadata, columns, sensitivity, DNA summary |
| pii_scan | Verhoeff, GSTIN check digit, regex and header detectors, scan result |
| data_dna | Cell fingerprints, match records, canary issuances |
| events | Standard schema, dedup, actor integrity, serialization |
| simulator | Simulated download, share and baseline events |
| lineage | Read only graph derived from events and matches |
| risk_engine | Policy, factor computation, assessment snapshot |
| anomaly_model | Per user MLP autoencoder and top features |
| incidents | Investigation, correlation, incident creation, bundle assembly |
| ai_reports | Deterministic composer, grounded Gemini client, fallback |
| demo | Seeded organization and synthetic generator |
| api | Contract serializers and endpoints |
| frontend/landing | Public landing page and legal pages |

## Data DNA

Row hashing fails when a column is deleted or a row moves. SALUS hashes each normalized cell value instead.

1. Normalize: NFKC, trim, collapse whitespace, lowercase, and digits only for phone and Aadhaar style values.
2. Hash: SHA-256 of organization salt plus the normalized value. The column name is not included.
3. Weight: `log(1 + N / frequency)`, so rare identity values dominate common ones.
4. Match: weighted containment of the suspect inside the source, plus row coverage.
5. Evidence: a row only counts when it has at least one rare matched cell or three matched cells. Rarity is relative to the source size, `max(1.0, 0.5 * log(1 + N))`.
6. Report: matched columns, dropped columns, matched cells, canary hits.

A match must have at least one rare shared value and one matched row, unless the file is an exact copy. This stops a file that only shares common values such as city and department from opening an incident.

The demo ghost copy keeps 8 of 11 columns and 300 of 1,000 rows. It still scores 0.999 because the suspect values have very high containment in the source. The headline "30 percent" is row coverage, which is shown separately from weighted cell recall.

Scaling path: MinHash over cell hashes with LSH buckets. The current exact set overlap is deterministic, easy to audit, and fast for a 1,000 row demo.

## Events and lineage

The event schema is the only activity write shape. Events are deduplicated on organization and event ID.

Correlation is deliberately conservative:

1. Find the latest download or copy of the source dataset in the last 180 days before the suspect upload.
2. Prefer a download that has an external share by the same actor within 48 hours.
3. If no download exists, fall back to recent external share events for the source asset. Do not invent a download.
4. Never synthesize a share from a similarity match.
5. If no event exists, the incident still opens but D and E reflect the missing evidence.

The lineage painter builds nodes and edges on read. Every edge carries a ref to an EVENT or a MATCH. There is no writable edge table, which structurally prevents invented lineage.

## Risk

```text
R = 0.35*S + 0.30*D + 0.20*B + 0.15*E
```

- S uses the matched columns only. It mixes the highest sensitivity with the mean.
- D uses the destination trust table and the most severe correlated external share.
- B uses a per user autoencoder trained on synthetic baseline events.
- E uses a fixed sequence table with after hours, download then share, external share only, bulk volume, canary, high match confidence and repeated access.

Weights are demo policy. The report shows the formula and points so judges can audit the result.

## Behaviour model

Features: hour sine and cosine, weekend flag, action one hot (view, download, copy, share), log volume, destination trust, file sensitivity. 10 features.

Model: scikit-learn `MLPRegressor` with hidden layers 8 and 4, deterministic random state. It is trained on the user's synthetic baseline events and stored as a pickled blob per organization and actor. Reconstruction error is mapped to a 0 to 100 score using the baseline p95. Per feature squared error gives the top contributors. If no baseline exists, B is 50 with a clear basis string.

Torch is intentionally not used in the deployment. Render free gives 512 MB and scikit-learn is enough.

## Reports

The deterministic composer fills the full schema from stored evidence. It is the fallback and the default when no Gemini key exists.

The Gemini client:

- sends only structured evidence and the schema,
- requests `application/json`,
- validates keys and types,
- checks every referenced identifier against the stored evidence,
- keeps risk points, limitations and grounding references deterministic,
- falls back on timeout, network, parse, schema or unknown reference failure,
- sanitizes em dashes and control characters,
- records the provider and the SHA-256 hash of the evidence snapshot so the UI can be honest.

## Investigation and audit

An investigation is a first class record, not an implicit side effect of an incident. It stores the organization, creator, source asset, suspect asset, match, incident, input filename, input SHA-256, rows, columns, status and creation time. The unique constraint on organization and input SHA-256 makes uploads idempotent: the second upload of the same file returns the first investigation with `duplicate: true`.

The audit log records investigation creation, duplicate intake, incident status changes, report regeneration and demo seed. Audit rows are organization scoped and exposed through the incident bundle and `GET /audit`.

Events can reference up to two actor fields: the standard `actor_id` string and a nullable `actor_ref` foreign key to the organization user. Simulator, intake and manual events must resolve to a user in the organization. Connector events may carry an external actor string without a user reference.

## Landing page

The public landing page is a static HTML, CSS and JavaScript site at `frontend/landing`. It follows the `landing-page-design` skill: one audience, one offer, one primary action, Manrope, Phosphor icons, flat dark backgrounds, electric cobalt and neon yellow accents, token spacing, a word by word tagline reveal, FAQ JSON-LD, legal pages and a branded 404. The How it works section includes an interactive Ghost Copy console that reads live demo evidence when the API is awake and falls back to a stored snapshot.

`scripts/build_site.ps1` and `frontend/build_render.sh` produce a `dist` folder with the landing page at `/` and the Flutter product at `/app/`. `scripts/serve_site.ps1` serves the same layout locally. The dashboard keeps its own working product design system; the skill is scoped to the landing page.

## Tenancy and privacy

- Every model carries an organization foreign key.
- Every query filters by the authenticated user's organization.
- Cross tenant asset lookups return 404, covered by tests.
- Raw uploads stay in memory. Only hashes, labels, counts and metadata are stored.
- Cell hashes use a deployment salt, so the same value hashes differently in another deployment.

### Production note: per organization hash salts

This build uses one deployment wide salt (`SALUS_HASH_SALT`). That is enough for the demo, but a production deployment should scope the salt to each organization so a database leak from one tenant cannot be used to dictionary attack another tenant's fingerprints.

Recommended shape:

1. Add an encrypted `hash_salt` secret to each `Organization` (for example a 32 byte random value wrapped with a KMS or Django `SECRET_KEY` derived key). Never expose it through the API.
2. Replace `settings.SALUS_HASH_SALT` with the organization salt in `prepare_asset`, `_canary_hashes`, and any future fingerprint writer. Keep the salt version in `Asset.dna_version`.
3. Rotate per organization by re-fingerprinting that organization's assets into a new version, then deleting the old rows. Matches must never compare fingerprints written with different salts.
4. Keep the deployment salt only as a migration fallback. If a row has no salt version, treat it as legacy and re-fingerprint before matching.
5. Store the salts in a secrets manager, not in the database backup, and log only salt versions, never salt values.

The matching code already reads the salt at hash time, so this is a storage and key management change, not a matching algorithm change.


## Limits

- USB, screenshots and retyped data are invisible.
- A match is a lead, not proof of intent.
- A canary and a watermark can be removed.
- Risk weights are not validated standards.
- The free deployment sleeps and can cold start slowly.

## Later

Google Workspace connector, secure viewer, endpoint agent, embedding based matcher, column type classifier, Gemma for private classification, MinHash and LSH for scale.
