# SALUS

Your data does not disappear. It leaves a trail.

SALUS is a data identity and investigation platform for small businesses in India, 10 to 100 people, with no security team. When a sensitive file leaks, the owner can answer three questions in plain language: what left, who moved it, and what now.

This repository is the Startup Buildathon India 2026 prototype. All records are synthetic. The demo works end to end on free infrastructure.

## The Ghost Copy demo

1. Seed a synthetic 1,000 row customer dataset with 5 canary rows and Data DNA.
2. Replay a simulated download and external share. The UI labels both as SIMULATED.
3. Generate a ghost copy locally: rename, XLSX to CSV, remove the watermark, delete 3 columns, drop 700 rows, keep 3 canary rows.
4. Upload the ghost copy to the investigation intake.
5. SALUS matches about 30 percent of the source records, flags the canary, correlates stored events, shows lineage, computes risk, and writes a grounded incident report with next actions.

Expected result: match score 0.999, 300 matched rows, canary CN-007 found, risk 93 CRITICAL, four recommended actions.

## Stack

- Flutter Web, Material 3, custom lineage graph
- Django 5 and Django REST Framework
- PostgreSQL on Render, SQLite for local tests
- pandas, openpyxl, hashlib for the data engine
- scikit-learn MLP autoencoder for behaviour scoring
- Gemini API through REST, optional and key gated, deterministic fallback always available
- Docker and Render blueprint

## Local setup

Prerequisites: Python 3.13, Flutter 3.47 or newer. PostgreSQL is not required locally.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_demo --reset
python manage.py runserver 0.0.0.0:8000
```

In a second terminal, build the public site and serve it:

```powershell
.\scripts\build_site.ps1 -ApiBase http://localhost:8000
.\scripts\serve_site.ps1
```

Open http://localhost:8080 for the landing page, or http://localhost:8080/app/ for the product. Sign in with `meera@acmetraders.test` (Meera Nair, owner). No password is required in this demo build. The login screen also has an "Initialize demo data" button for a fresh database.

For app only UI work, run Flutter directly:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_BASE=http://localhost:8000
```

## One command demo preparation

From the repository root:

```powershell
.\scripts\demo_up.ps1 -Serve
```

This runs migrations, seeds if needed, writes `demo_data/customer_master_v1.xlsx`, writes `demo_data/clients_export_final.csv`, and starts Django. Add `-Reset` to rebuild the demo organization.

Then build and serve the site:

```powershell
.\scripts\build_site.ps1 -ApiBase http://localhost:8000
.\scripts\serve_site.ps1
```

## Gemini reports

The report layer has two providers:

- `SALUS_TEMPLATE`: deterministic, evidence driven, always works. This is the default when no key is present.
- `GEMINI`: REST call with the evidence JSON only, JSON response mode, schema validation, timeout, retries, sanitizer, and fallback.

Gemini output is checked against the stored evidence. Every `EV`, `MT`, `RS`, `INC`, `SL`, `USER`, `ORG`, `INV` and `CN` reference must exist. Risk points, limitations and grounding references always come from the deterministic engine. The report also stores a SHA-256 `evidence_hash`, so the prose is tied to one evidence snapshot.

Set `GEMINI_API_KEY` in `.env` or the Render environment to enable Gemini. A free Google AI Studio key needs no billing. The UI and fixture always show which provider wrote the report. The template is never presented as Gemini output.

## Environment

Copy `.env.example` to `.env` for local runs. Django reads environment variables directly, so either export them or use your shell profile.

| Variable | Default | Notes |
|---|---|---|
| DJANGO_DEBUG | 1 | Set 0 in production |
| SALUS_DEMO_MODE | same as DEBUG | Keep 1 for the Render demo, or demo login and seed are disabled |
| SALUS_SEED_ON_START | 1 | Seed the synthetic workspace at API start |
| DJANGO_SECRET_KEY | dev key | Generate in production |
| DJANGO_ALLOWED_HOSTS | * | Use `.onrender.com` on Render |
| SALUS_HASH_SALT | demo salt | Change per deployment |
| SALUS_MATCH_THRESHOLD | 0.3 | Investigations below this score create no incident |
| DATABASE_URL | empty | Empty uses SQLite. Render provides Postgres |
| GEMINI_API_KEY | empty | Optional |
| GEMINI_MODEL | gemini-2.5-flash | Free tier model |
| GEMINI_TIMEOUT | 8 | Seconds |
| GEMINI_RETRIES | 1 | Extra attempts after the first |
| CORS_ALLOWED_ORIGINS | localhost ports | Comma separated |
| CORS_ALLOW_ALL_ORIGINS | same as DEBUG | Set 1 for the demo static site |

Flutter API target:

```powershell
flutter run -d chrome --web-port 8080 --dart-define=API_BASE=http://localhost:8000
```

## Tests

```powershell
cd backend
python manage.py test tests -v 2

cd ..\frontend
flutter analyze
flutter test
```

The backend test suite has 49 tests. They cover Verhoeff, the GSTIN check digit, India PII detection, normalization, rarity thresholds, weak overlap rejection, ghost matching after row and column loss, extra columns, the risk policy, share only correlation, risk, production API validation, Gemini schema and reference grounding, investigation deduplication, audit trails, report evidence hashes, and cross tenant isolation.

End to end checks:

```powershell
python scripts/e2e_check.py
python scripts/check_replay.py
```

The end to end check also verifies duplicate upload returns the same investigation, the audit trail records status changes and report regeneration, and the report evidence hash is stable.

## Investigation workflow and backend models

- `Investigation` is a first class intake record. It links the source asset, suspect asset, match and incident, stores the input SHA-256, and uses a unique constraint on organization and input hash. Uploading the same file twice returns the existing investigation with `duplicate: true`.
- `AuditLog` records investigation creation, duplicate intake, incident status changes, report regeneration and demo seed. The incident bundle includes the latest 20 audit entries.
- `Event.actor_ref` is a nullable foreign key to the organization user. The standard `actor_id` string stays for future connectors, while simulator and intake events are validated against the organization.
- `Report.evidence_hash` is a SHA-256 of the canonical evidence JSON. The report is tied to the exact evidence snapshot.
- New endpoints: `GET /investigations`, `GET /investigations/{id}`, `GET /audit`.

## Landing page

The public landing page follows the installed `landing-page-design` skill. It lives in `frontend/landing/` and is served at `/`, while the Flutter product is served at `/app/`.

- Audience: owners and operations leads at Indian businesses with 10 to 100 people.
- Offer: run the live Ghost Copy and see a partial copy traced to its source.
- Primary action: open the live demo. One primary action, repeated in the nav, hero and final section.
- Layout: classic hero plus sections, with a mandatory tagline reveal after the hero.
- Visual system: Manrope, flat dark backgrounds, one mint accent, Phosphor icons, Tailwind scale spacing and radius, base curve `cubic-bezier(0.22, 1, 0.36, 1)`.
- Ship items: skip link, focus rings, mobile full height menu, FAQ JSON-LD, OG image, branded favicon, privacy and terms pages, branded 404, 390px check.
- QA: 1440, 1024, 768 and 390 widths have no horizontal overflow, the primary action is visible in the first screen, all links return 200, all reveals and tagline words trigger on scroll, and there are no console errors.
- Scope: the skill was applied to the landing page. The product dashboard keeps its own working design system.
- Embedded simulation: the `#how-it-works` section replays the Ghost Copy in eight animated chapters. It reads `GET /api/v1/simulation/ghost-copy` when the demo API is available and falls back to a bundled snapshot. Movement events stay labelled SIMULATED. The neural network drawing is illustrative; the B score and top features are real.

## Repository map

```text
backend/
  salus/              Django settings and URLs
  organizations/      Tenant, users, audit log
  assets/             Dataset metadata
  pii_scan/           Verhoeff, GSTIN checksum, India PII detection, labels
  data_dna/           Cell fingerprints, rarity thresholds, matching, canaries
  events/             Standard event schema, actor integrity and ingestion
  simulator/          Simulated download, share and baseline events
  lineage/            Derived graph, every edge has an event or match ref
  risk_engine/        Deterministic S, D, B, E and total score
  anomaly_model/      Small behaviour autoencoder, top features
  incidents/          Investigation, correlation, incident creation and bundles
  ai_reports/         Deterministic composer, grounded Gemini client, fallback
  demo/               Synthetic generator and seed command
  api/                Serializers, views, URL contract
  tests/              Unit, production and tenant tests
frontend/
  landing/            Public landing page, legal pages, 404, brand assets
  lib/screens/        Login, shell, command center, discovery, intake, incident
  lib/widgets/        Common UI and lineage painter
  lib/api.dart        Typed API client
  dist/               Built site, landing at root, Flutter at app/ (ignored)
contract/             Frozen API contract and live fixtures
scripts/              Dataset, ghost copy, QA, fixture export, site build, demo up
docs/                 Architecture, landing design, demo script, team tasks
```

## Render deployment, free tier

`render.yaml` defines:

- `salus-api`: Django web service, migrates and seeds idempotently on start.
- `salus-web`: static site built by `frontend/build_render.sh`. Landing at `/`, Flutter app at `/app/`.
- `salus-db`: Render Postgres, free plan.

Steps:

1. Push this repository to GitHub.
2. In Render, create a new Blueprint from the repository.
3. Confirm the three resources. If the free database plan is unavailable in your region, remove the `databases` block and set `DATABASE_URL` to a free Neon or Supabase Postgres URL.
4. Keep `SALUS_DEMO_MODE=1`. Without it, demo login and seed are disabled in production.
5. Set `GEMINI_API_KEY` if you have one. Leave it empty to use the deterministic report.
6. After deploy, open `https://salus-web.onrender.com` for the landing page and `/app/` for the product. The first load can be slow because the free API instance sleeps.

Free tier notes:

- The free web service sleeps after about 15 minutes idle. Warm it two minutes before judging. A free UptimeRobot ping every 5 to 10 minutes also works.
- The free static site build installs Flutter, so the first deploy can take several minutes. If it is unreliable, run `frontend/build_render.sh` locally, force add `frontend/dist`, and change the static build command to `echo prebuilt`.
- The demo seed runs on every API start and skips if ORG-01 already exists. Use `POST /api/v1/dev/seed` with `{"reset": true}` to rebuild.
- Keep a local run and a recorded backup video for judging.

## Docker

```powershell
docker compose up --build
```

This starts Postgres, Django on port 8000, the landing page at http://localhost:8080, and the Flutter app at http://localhost:8080/app/. The API base is set to `http://localhost:8000`.

Docker is not installed on the current development laptop, so the native path above is the verified one.

## Demo endpoint note

`POST /api/v1/dev/seed` is open in this prototype so a fresh Render database can be initialized from the login screen. It only touches the synthetic ORG-01 workspace and requires `SALUS_DEMO_MODE=1`. Remove it or protect it before any real deployment.

## What SALUS cannot do

- It cannot see USB copies, screenshots, retyped data, or activity outside connected or simulated sources.
- A similarity match is a lead, not proof of intent.
- A canary can be stripped. A watermark can be removed. Neither is used as the only signal.
- The risk weights are demo policy values, not validated standards.
- Monitoring is authorized and visible. No covert surveillance.

## Later phases, not built here

- Google Workspace connector using Drive Activity API and Admin Reports API.
- Secure viewer and endpoint agent.
- Column type classifier and embedding based copy matcher.
- Gemma for private on device classification.
- MinHash or LSH for very large fingerprint corpora.

## Team

Four roles: data DNA and backend, AI and risk, Flutter and product, simulator and demo. See `docs/TEAM_TASKS.md` for current ownership and next tasks.
