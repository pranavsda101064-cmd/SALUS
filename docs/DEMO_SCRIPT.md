# Demo script

Goal: finish the Ghost Copy in under 3 minutes and leave time for the risk story.

## Before you walk on stage

1. Warm the API: open `https://salus-api.onrender.com/api/v1/health` in a tab.
2. Log in once and keep the command center open.
3. Confirm `demo_data/clients_export_final.csv` exists on the demo laptop.
4. Keep a recorded backup of the full flow.
5. Keep the local fallback ready: Django on port 8000, Flutter on port 8080.

## The script

### 0:00 to 0:20, open

"Small companies in India handle Aadhaar, PAN and customer lists every day, and they have no security team. When a file leaks, they cannot answer a simple question: where did this come from?"

Tagline: "Your data does not disappear. It leaves a trail."

### 0:20 to 0:40, command center

"This is the SALUS command center for Acme Traders, a synthetic 60 person distributor. Everything you see is simulated and labelled. We have one data source, customer_master_v1, one thousand synthetic customers, and five canary rows."

Point at the demo safety badges.

### 0:40 to 1:00, replay activity

Click "Replay simulated activity".

"Priya from sales downloads the customer master at 22:40 IST and shares it to an external domain four minutes later. Both events are simulated for this build, and both are labelled."

Point at the SIMULATED label on the timeline later.

### 1:00 to 1:20, the ghost copy

"Outside the company, someone strips the watermark, renames the file, converts it to CSV, deletes three columns and drops 700 rows."

Show the ghost recipe card or the terminal output from `scripts/ghost_copy.py`.

### 1:20 to 1:50, investigation intake

Open Investigation, select `demo_data/clients_export_final.csv`, click "Run investigation".

While it runs: "SALUS fingerprints each cell, weights rare values by how unusual they are, and compares the overlap with stored datasets. Row hashes would break when columns are deleted. Cell hashes do not."

### 1:50 to 2:30, the incident

Point at the result in this order.

1. Match: 0.999, 300 of 1,000 records, 8 columns. "This is 30 percent of the source records. The match survives the format change, the deleted columns and the dropped rows."
2. Canary: "CN-007 was issued to vendor.acme@external.test. The copy still carries three canary rows. That tells us which issuance this came from, not who forwarded it next."
3. Lineage: "Every edge points to a real event or a real match. The download is EV-10021, the share is EV-10027, the match is MT-2001. We never invent a download from a similarity score."
4. Risk: "93 out of 100. Sensitivity 92, destination 85, behaviour 100 against Priya's normal pattern, sequence 100 because it was after hours and followed by an external share. The weights are demo policy and shown on screen."
5. Report and actions: "The report explains what left, who moved it, and four actions: revoke access, contact the canary recipient, review notification, and restrict downloads."

### 2:30 to 2:50, honesty and close

"SALUS cannot see a USB stick, a screenshot or data typed by hand. A match is a lead, not proof of intent. The risk engine is deterministic and auditable. The language model only explains the evidence. With a Gemini key the report is generated live. Without a key, the deterministic report is the fallback you just saw."

Close: "Investigation first, plain language, two minute setup, built for the businesses that need it most."

## Likely questions

**Is this just DLP?**
No. DLP blocks known patterns at the endpoint or gateway. SALUS investigates a file that is already outside and links it to the source, the actor and the event trail. It is investigation first.

**What if columns are renamed?**
Cell hashes do not include the column name. Renamed headers and dropped columns do not break the match.

**How do you avoid false positives?**
Rare value weighting, a minimum of two matched cells per row, containment thresholds, a canary, and an explicit "lead, not proof" rule. The report shows the evidence and the limits.

**Why is the risk score 93?**
Show the four factors and the weights. Emphasize that these are demo policy values, not validated standards, and the formula is deterministic.

**What if Gemini fails?**
The fallback report is generated from the same evidence JSON. The UI labels the provider. The demo does not depend on the API.

**Privacy?**
Raw file contents are parsed in memory and not stored. Fingerprints, labels and metadata are stored. Every query is tenant scoped. Monitoring is visible and authorized.

**What is next?**
Google Workspace connector, secure viewer, endpoint agent, embedding matcher, MinHash for scale, Gemma for private classification.

## Recovery moves

- Upload fails: use the already opened incident or the recorded backup.
- API cold start: wait, or switch to localhost.
- Gemini key missing: say so and show the template. The provider badge is on screen.
- Judges ask for a smaller dataset: the 1,000 rows are generated deterministically, so the numbers reproduce.
