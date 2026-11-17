# Team tasks

Current state: the Ghost Copy path, backend investigation models, and public landing page work end to end with tests and fixtures. 49 backend tests pass. Use this list for the final polish and pitch work.

## 1. Data DNA and backend

Owns: `backend/pii_scan`, `backend/data_dna`, `backend/assets`, `backend/incidents`, `backend/api`.

Already done:

- Verhoeff Aadhaar, PAN, GSTIN with base 36 check digit, UPI, phone, email, financial headers.
- Cell fingerprints with organization salt and relative rarity thresholds.
- Partial copy matching after rename, XLSX to CSV, column loss, row loss and extra columns.
- Weak overlap rejection so common values alone cannot open an incident.
- Canary issuance and detection.
- `Investigation` model with deduplication on input SHA-256.
- `AuditLog` model, audit trail in the incident bundle, `GET /audit`.
- Event actor integrity with a nullable user foreign key.
- Report `evidence_hash`.
- Tenant scoped endpoints and tests.
- Health database check, bounded pagination, upload size and XLSX validation.

Next tasks:

1. Run a Postgres smoke test against Render or Neon before judging.
2. Write the production note for per organization hash salts.
3. Review the incident bundle query count if more than 50 incidents are seeded.
4. Add a small admin view for demo reset if the team wants one.

## 2. AI and risk

Owns: `backend/anomaly_model`, `backend/risk_engine`, `backend/ai_reports`.

Already done:

- Deterministic S, D, B, E formula with policy endpoint.
- Per user MLP autoencoder, reconstruction error, percentile and top features.
- Deterministic report composer with the final schema and golden fixture test.
- Gemini REST client, JSON mode, timeout, retries, schema validation, evidence reference grounding, sanitizer and fallback.
- Share only correlation contributes to destination and sequence risk.
- Report evidence hash and audit logging for regeneration.

Next tasks:

1. Run one live Gemini call when a free AI Studio key is available and capture the output in `contract/fixtures/report_gemini.json`.
2. Tune the autoencoder threshold mapping so B is not always 100 for the demo. Keep it explainable.
3. Prepare the risk slide: formula, factor definitions, why the weights are demo policy.
4. Rehearse the fallback story so the template is never presented as Gemini output.

## 3. Flutter and product

Owns: `frontend` and `frontend/landing`.

Already done:

- Login, shell, command center, data discovery, investigation intake, incident detail.
- Custom lineage graph with edge refs and simulated styling.
- Risk factor bars, canary card, report, actions, limits.
- File upload via a web file picker with a VM stub for tests.
- Public landing page built with the `landing-page-design` skill: Manrope, Phosphor icons, flat dark palette, tagline reveal, FAQ schema, legal pages, branded 404.
- Interactive Ghost Copy console on the landing page with live demo evidence and a snapshot fallback.
- App UI redesigned with Manrope, electric cobalt `#0864E8`, neon yellow `#F5FF00`, flat surfaces, one stat strip, and Overview, Trail and Report tabs in incident detail.
- Site build with landing at `/` and Flutter at `/app/`.
- Playwright QA at 1440, 1024, 768 and 390 widths with no overflow and no console errors.
- Pitch screenshots in `docs/screenshots/`.

Next tasks:

1. Run the app on the actual 1366x768 projector and adjust any small text.
2. Check the lineage graph at 5 and 7 nodes, and with a missing suspect asset.
3. Add a small loading skeleton for the incident detail when opened from a list.
4. Add a "demo reset" affordance if the team wants one.
5. Keep the landing page copy and screenshots in sync with the final demo.

## 4. Simulator, demo and pitch

Owns: `scripts`, `docs/DEMO_SCRIPT.md`, demo data, QA.

Already done:

- Seeded 1,000 row dataset with 11 columns and 5 canary rows, including checksum valid GSTINs.
- Ghost copy script with rename, format change, 3 column drops, 700 row drop, watermark removal, 3 canary rows kept.
- Simulator baseline and replay, labelled SIMULATED.
- QA scripts: `scripts/e2e_check.py`, `scripts/check_replay.py`, `scripts/export_fixtures.py`, `scripts/build_site.ps1`, `scripts/serve_site.ps1`.
- Landing page QA and screenshots in `docs/QA_REPORT.md`.
- Render and Docker scaffolding.

Next tasks:

1. Record the full demo three times and pick the cleanest run.
2. Build the pitch deck: problem, demo, architecture, risk, honesty, roadmap.
3. Prepare the 30 second version for a crowded hall.
4. Run the demo on the actual judging laptop and browser.
5. Keep the fallback video and local server ready.
6. Verify the Render cold start, static build, and warm up routine.

## Integration gates

- Gate 1: 49 backend tests green, `scripts/e2e_check.py` prints E2E OK.
- Gate 2: Flutter analyze and test green, site build at `/` and `/app/`, live upload opens the incident.
- Gate 3: landing page and app checks from `docs/QA_REPORT.md` pass.
- Gate 4: three clean demo runs under three minutes.
- Gate 5: Render deploy healthy, login works, seed is idempotent, cold start handled.

## Ownership boundaries

- Do not edit `backend/data_dna` or `backend/pii_scan` without the backend owner.
- Do not edit `frontend/lib/widgets/lineage_graph.dart` without the product owner.
- The contract in `contract/README.md` is frozen. Any shape change needs a version bump and a fixture re-export.
