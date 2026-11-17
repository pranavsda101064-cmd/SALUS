# Landing page design

The public landing page follows the installed `landing-page-design` skill at `D:\Hackthon\Chacha apps\.agents\skills\landing-page-design\SKILL.md`. It is served at `/`, while the Flutter product is served at `/app/`.

## Strategy

- One audience: owners and operations leads at Indian businesses with 10 to 100 people and no security team.
- One offer: run the live Ghost Copy and see a partial copy traced back to its source.
- One primary action: open the live Ghost Copy. The same action appears in the nav, hero and final section.
- Layout: classic hero plus sections. The product is understandable from one incident panel.
- Voice: plain, calm, specific. No hype, no invented customers, no pricing claims.

## Page order

1. Floating nav with How it works, Evidence, FAQ and the primary action.
2. Hero: headline, subheadline, primary action, proof line and incident panel.
3. Tagline reveal.
4. Problem.
5. Benefits, five outcome driven rows.
6. How it works, with an interactive Ghost Copy console that reads live demo evidence and falls back to a snapshot.
7. Evidence, real demo numbers and limits.
8. FAQ, eight questions and answers.
9. Final call to action.
10. Footer with privacy, terms and demo limits.

## Copy

- Hero: "Know what left your company. Then know what to do next."
- Subheadline: fingerprints, partial copies and the event trail, built for teams of 10 to 100.
- Tagline reveal: "Your data does not disappear. It leaves a trail."
- Proof: 300 of 1,000 records recovered from a copy with 3 deleted columns.
- Evidence: 0.999 match, 300 records, 93 risk, 3 canary rows, all from the synthetic demo.

The page uses the actual demo numbers and states the limits: USB copies, screenshots, retyped data and activity outside connected sources are invisible. A match is a lead, not proof.

## Visual system

- Font: Manrope variable, bundled locally under the SIL Open Font License.
- Palette: flat `#000000`, `#181818`, `#1F1F1F`, `#272727`, `#313131`, white text and `#9B9B9B` muted text. Electric cobalt `#0864E8` is the primary accent for links, eyebrows, icons and actions. Neon yellow `#F5FF00` marks risk, critical state, match references and the final tagline word.
- No background gradients. The only gradient is the hero heading text, white to muted.
- Icons: Phosphor, inline SVG, MIT licensed. No Material icons on the landing page.
- Type: sizes snap to the skill scale. Headings use semibold, never above 600.
- Spacing and radius: only the skill tokens. Nested cards are avoided.
- Motion: base curve `cubic-bezier(0.22, 1, 0.36, 1)`, transform and opacity only.
- Tagline reveal: each word starts at 28 percent opacity and lights up as it crosses a trigger line with an IntersectionObserver.
- Scroll reveals run once. `prefers-reduced-motion` shows final states immediately.
- Theme: cream paper with a faint grain texture (`assets/paper.png`). Key phrases carry a flat yellow highlighter stroke (`assets/marks/highlight.svg`, scaled on scroll with transform only). No dark sections.
- Background motion: photos drift behind sections at low opacity with parallax. The hero tagline has a slow float on the incident panel. An Indian ID marquee pauses on hover.
- Ghost Copy scene: a pinned scroll section with 1,000 cells. 300 match and light up, the rest drop out, matching the demo numbers.
- Carousel autoplays every 6 seconds with a progress bar. It pauses on hover, focus or a hidden tab. Keyboard arrows, Home and End work.
- Photos are from Pexels under the Pexels License. They are credited in the footer.

## Interaction and accessibility

- Skip to content link.
- Visible focus rings.
- Mobile menu is a full height panel with a transforming toggle, staggered links, Escape to close, focus handling and scroll lock.
- No dead links. Nav anchors, legal pages, 404 and the app link all resolve.
- `text-wrap: balance` on headings and `pretty` on paragraphs.
- No italics, no ultra bold, no hyphenated prose. Contract IDs such as `INC-4001` keep their hyphens because they are data references.
- One h1, semantic sections, FAQ JSON-LD, title, description, canonical, OG image and branded favicon.

## Embedded simulation

The `#how-it-works` section contains an eight chapter interactive simulation. It is a labelled replay of the Ghost Copy, not a generic animation.

- Chapters: dataset, movement, ghost copy, intake and identification, Data DNA, canary and tracking, neural behaviour, risk and report.
- The page reads `GET /api/v1/simulation/ghost-copy` first. That endpoint is demo only and returns only synthetic ORG-01 metadata, counts, references and hashes.
- If the API is asleep, unseeded, or demo mode is off, the page falls back to `simulation-data.json` and labels itself as a bundled snapshot.
- Movement events keep the SIMULATED label. Lineage edges show their stored EVENT or MATCH reference.
- The neural network drawing is an illustration of the stored 10-8-4-10 autoencoder architecture. The B score, percentile and top features are real.
- Controls are play, pause, restart, previous, next and speed. Keyboard arrows and Home are supported.
- Reduced motion shows static final states and turns the play action into a chapter step.

## Implementation

- `frontend/landing/index.html`, `styles.css`, `app.js`, `simulation.css`, `simulation.js`, `simulation-data.json`
- `frontend/landing/privacy.html`, `terms.html`, `404.html`
- `frontend/landing/favicon.svg`, `og-image.png`, icon PNGs
- `frontend/landing/assets/fonts/Manrope-VariableFont_wght.ttf` and `OFL.txt`
- `scripts/build_site.ps1` and `scripts/build_site.sh` build a `dist` folder with landing at root and Flutter at `app/`
- `scripts/serve_site.ps1` serves the local build
- `scripts/build_brand_assets.py` regenerates the favicon PNGs
- `frontend/landing/_tools/og.html` is the source for the OG image

## Known exceptions

- The product dashboard still uses its own dark product design system. The skill was scoped to the landing page to protect the working demo.
- Contract IDs contain hyphens. They are identifiers, not prose.
- There are no forms, so there is no client side email validation or cookie consent. The demo sets no tracking cookies.
