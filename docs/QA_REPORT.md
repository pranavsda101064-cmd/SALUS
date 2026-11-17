# QA report

Date: 16 November 2026
Build: SALUS hackathon prototype

## Backend

- `python manage.py test tests`: 49 tests pass.
- `python manage.py check`: no issues.
- End to end script: `scripts/e2e_check.py` prints E2E OK.
- Ghost Copy result: match 0.999, 300 matched rows, 30 percent row coverage, canary CN-007 found, risk 93 CRITICAL, four actions.
- Duplicate upload returns the same INV-6001 and INC-4001 with `duplicate: true`.
- Audit trail contains INVESTIGATION_CREATED, INCIDENT_STATUS_CHANGED and REPORT_REGENERATED.
- Report evidence hash is stable across regeneration and is 64 hex characters.
- Health returns 200 with database ok and 503 when the database check fails.
- Cross tenant asset, event, investigation and audit lookups are blocked.
- Weak overlap with only common values is rejected. Extra unrelated columns still match.

## Landing page

Playwright checks against the built site:

- Palette: cobalt `#0864E8` for primary actions and links, neon yellow `#F5FF00` for risk and emphasis, neutral dark surfaces, Manrope throughout. The interactive Ghost Copy console uses the same tokens.
- 1440 x 900, 1024 x 768, 768 x 900, 390 x 844: no horizontal overflow.
- Primary action visible in the first screen at every width.
- Manrope loaded, no console errors, no page errors.
- Mobile menu opens, locks scroll, closes with Escape, and restores state.
- All reveal blocks and all 9 tagline words activate after scrolling.
- No font weight above 600, no italics, no gradients outside the hero heading.
- One h1, one primary hero action, FAQ schema present, title, description, canonical and OG image present.
- `/app/`, `privacy.html` and `terms.html` return 200.
- Branded 404 page exists.
- Flutter app loads at `/app/` with base href `/app/`, API health 200, login succeeds, command center renders, incident detail renders.
- The interactive console fetches live demo evidence, advances from chapter 01 to 02, toggles play, and produces no console errors.
- App screenshots show the new tabbed investigation view and audit trail.

Screenshots:

- `docs/screenshots/landing-desktop.png`
- `docs/screenshots/landing-mobile.png`
- `docs/screenshots/landing-mobile-menu.png`
- `docs/screenshots/landing-full.png`
- `docs/screenshots/app-login.png`
- `docs/screenshots/app-command-center.png`
- `docs/screenshots/app-data-discovery.png`
- `docs/screenshots/app-investigation.png`
- `docs/screenshots/app-incident.png`
- `docs/screenshots/app-trail.png`
- `docs/screenshots/app-report.png`
- `docs/screenshots/app-report-lower.png`

## Flutter product

- `flutter analyze`: no issues.
- `flutter test`: passes.
- Release web build succeeds with `--base-href /app/`.
- Manrope is bundled with weights 400, 500 and 600.
- App palette uses electric cobalt `#0864E8`, neon yellow `#F5FF00`, and neutral surfaces. No gradients, no italics, no weights above 600.
- Command center uses one stat strip, a focused incident card, a compact demo steps rail, and a limits panel.
- Incident detail is split into Overview, Trail, and Report tabs, with the audit trail in Report.
- Browser flow: landing, open demo, login, command center, incident Overview, Trail, Report, action list, and audit trail. No console errors.

## Not verified

- Live Gemini call. No key was available. Schema validation, reference grounding and fallback are covered by tests.
- Docker build. Docker is not installed on the development laptop. The Dockerfile and compose file are included.
- Render deploy. The blueprint is configured but no account is connected.
- Render free database expiry and cold start behavior.

## Known limits

- The public demo uses synthetic data only and must not receive production data.
- The demo risk weights are policy values, not validated standards.
- A match is a lead, not proof of intent.
- Canaries and watermarks can be removed.
