# Team tasks

Current state: the Ghost Copy path works end to end with tests and fixtures. Use this list to divide the remaining polish and pitch work.

## 1. Data DNA and backend

Owns: `backend/pii_scan`, `backend/data_dna`, `backend/assets`, `backend/api`.

Already done:

- Verhoeff Aadhaar, PAN, GSTIN, UPI, phone, email, financial headers.
- Cell fingerprints with organization salt and rarity weights.
- Partial copy matching after rename, XLSX to CSV, column loss and row loss.
- Canary issuance and detection.
- Tenant scoped endpoints with tests.

Next tasks:

1. Add a small detector test for a real looking GSTIN checksum case, even though the demo only checks format.
2. Add a match threshold config in settings instead of the constant 0.3.
3. Add an endpoint to list PII summary counts for the discovery screen if product needs it.
4. Review the API for any N+1 query in incident bundles and asset lists.
5. Write the production note for per organization hash salts.

## 2. AI and risk

Owns: `backend/anomaly_model`, `backend/risk_engine`, `backend/ai_reports`.

Already done:

- Deterministic S, D, B, E formula with policy endpoint.
- Per user MLP autoencoder, reconstruction error, percentile and top features.
- Deterministic report composer with the final schema.
- Gemini REST client, JSON mode, timeout, validation, sanitizer, fallback.

Next tasks:

1. Run one live Gemini call when a free AI Studio key is available and capture the output in `contract/fixtures/report_gemini.json`.
2. Add a golden test for `build_deterministic` with a fixture incident.
3. Tune the autoencoder threshold mapping so B is not always 100 for the demo. Keep it explainable.
4. Add a report schema validation test for malformed Gemini output.
5. Prepare the risk slide: formula, factor definitions, why the weights are demo policy.

## 3. Flutter and product

Owns: `frontend`.

Already done:

- Login, shell, command center, data discovery, investigation intake, incident detail.
- Custom lineage graph with edge refs and simulated styling.
- Risk factor bars, canary card, report, actions, limits.
- File upload via a web file picker with a VM stub for tests.

Next tasks:

1. Run the app against the live backend and fix visual issues on a 1366x768 projector and a phone width.
2. Add a screenshot set for the pitch deck from the real app.
3. Add a small loading skeleton for the incident detail when opened from a list.
4. Check the lineage graph at 5 and 7 nodes, and with a missing suspect asset.
5. Add a "demo reset" affordance behind a long press or a settings item if the team wants one.

## 4. Simulator, demo and pitch

Owns: `scripts`, `docs/DEMO_SCRIPT.md`, demo data, QA.

Already done:

- Seeded 1,000 row dataset with 11 columns and 5 canary rows.
- Ghost copy script with rename, format change, 3 column drops, 700 row drop, watermark removal, 3 canary rows kept.
- Simulator baseline and replay, labelled SIMULATED.
- QA scripts: `scripts/e2e_check.py`, `scripts/check_replay.py`, `scripts/export_fixtures.py`.
- Render and Docker scaffolding.

Next tasks:

1. Record the full demo three times and pick the cleanest run.
2. Build the pitch deck: problem, demo, architecture, risk, honesty, roadmap.
3. Prepare the 30 second version for a crowded hall.
4. Run the demo on the actual judging laptop and browser.
5. Keep the fallback video and local server ready.
6. Verify the Render cold start and warm up routine.

## Integration gates

- Gate 1: backend tests green, `scripts/e2e_check.py` prints E2E OK.
- Gate 2: Flutter analyze and test green, live upload opens the incident.
- Gate 3: three clean demo runs under three minutes.
- Gate 4: Render deploy healthy, login works, seed is idempotent, cold start handled.

## Ownership boundaries

- Do not edit `backend/data_dna` or `backend/pii_scan` without the backend owner.
- Do not edit `frontend/lib/widgets/lineage_graph.dart` without the product owner.
- The contract in `contract/README.md` is frozen. Any shape change needs a version bump and a fixture re-export.
