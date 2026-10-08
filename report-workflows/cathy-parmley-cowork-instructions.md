# Co-Work Instructions — Cathy Parmley UAT Testing Report
**Frequency:** Monthly
**Owner:** PMO Team
**Output:** Updated KB-styled HTML report (one per month) in the Knowledge Base

---

## Conventions (read first — these are fixed)

- **Reports are labeled by the MONTH OF THE METRICS**, not the month they were
  delivered. A report produced on Oct 1 that covers data through Sep 30 is the
  **September** report. (Earlier reports were mistakenly named by delivery month,
  which produced a duplicate "June" and partial May/June — do not repeat that.)
- **Current period = testing that started on or after Apr 8, 2026**, counted
  cumulatively **through the month-end** being reported.
- **Baseline is fixed: Nov 2025 – Mar 2026** (8 projects, avg total **8.75d**,
  R1 5.25d, R2 3.00d, R1→R2 −42.9%, longest RenRe 16d). Every month is compared
  to this. **Never change the baseline.**
- **Rounds (R1/R2/R3) are assigned by start-date order within each project** —
  the round-name text in Smartsheet is inconsistent, so sequence wins. Rows with
  **no Start Date or no Duration are excluded** from the averages.
- The **whole series is recomputed from current Smartsheet data every month**, so
  late edits (new rounds, corrected durations) stay consistent across all months.

---

## What This Report Tracks

- Projects tested and testing rounds in the current period
- Total testing duration per project (days) + trend line ordered by start date
- R1 vs R2 vs R3 round comparison — are retests getting faster?
- Average duration per round, longest project
- Change vs the Nov 2025 – Mar 2026 baseline

---

## Monthly Process (automated pipeline)

The report build lives in the KB repo (`bdotm-jj/jjkb`) at **`uat-pipeline/`**.
Run it through Claude Code (or any environment with the Smartsheet connector +
Perl). See `uat-pipeline/README.md` for the canonical steps; in short:

### Step 1 — Pull the source data
Source = the Smartsheet **report "Cathy Parmley Task Report"** (report id
`8800191256678276`), in *JandJ-SCCAdmin - Projects → Reports → Operations*.
Pull it via the Smartsheet connector (`get_report`) and save the JSON. (It is
one row per UAT testing round across all Project Plan sheets, with Project Name,
round, Duration, and Start Date.)

### Step 2 — Compute & generate
From `uat-pipeline/`:
```bash
perl parse_cathy.pl <report.json>   # -> cathy_clean.tsv (startdate, project, dur, round)
perl compute2.pl                    # -> cathy_series.json (baseline + Apr->month-end aggregates)
perl cathy_gen.pl                   # -> ../site/reports/<month>-2026.html for every month
```
When a new month ends, add its month-end date to `@MONTHS` in `compute2.pl`
before running. The generator reproduces the KB-styled 5-slide deck and
auto-writes the callouts, baseline table, findings, and recommendations.

### Step 3 — Register it on the Knowledge Base
1. Open `site/app.jsx`, find `const REPORTS = [`.
2. Add/adjust the `uat` entry for the new month: `id` and `file`
   (`reports/<month>-2026.html`), `title` = the **metrics month**, `date` = the
   **month-end** (ISO; drives newest-first ordering), `period`
   (`Current period · Apr 8 – <Month end>, 2026`), `summary`, and `stats`.
3. Bump the `app.jsx?v=` cache number in `site/index.html`.

### Step 4 — Deploy
Commit and push to `main`. GitHub Pages redeploys automatically; the new edition
shows up as the latest UAT report on the KB (Reports → UAT Reports).

> **Manual fallback (no pipeline access):** export the report to `.xlsx`, hand it
> to Claude with an existing KB report as the template, and ask it to reproduce
> the deck changing only the data — using the conventions and baseline above.
> The automated pipeline is preferred because it keeps every month consistent.

---

## Tracking Log (optional)

Keep a running row per month. **The baseline row is fixed — never update it.**

| Month | Projects | Rounds | Avg Total | Avg R1 | Avg R2 | R1→R2 | Longest | Notes |
|---|---|---|---|---|---|---|---|---|
| Baseline *(Nov'25–Mar'26)* | 8 | 21 | 8.75d | 5.25d | 3.00d | −42.9% | RenRe (16d) | Fixed reference |
| April 2026 | 3 | 4 | 4.7d | 4.3d | 1.0d | — | Scottsdale API (10d) | |
| May 2026 | 6 | 9 | 7.3d | 6.5d | 1.5d | −76.9% | Workflow Dashboard (20d) | |
| June 2026 | 9 | 15 | 8.6d | 6.9d | 2.6d | −62.3% | Workflow Dashboard (20d) | |
| July 2026 | 9 | 16 | 9.2d | 6.9d | 2.6d | −62.3% | Scottsdale API (21d) | |
| August 2026 | 10 | 18 | 8.7d | 6.5d | 2.3d | −64.1% | Scottsdale API (21d) | |
| September 2026 | 11 | 22 | 9.6d | 6.2d | 2.5d | −59.6% | Auto Renewals - PL (26d) | |

---

## Email Template

**Subject:** Your UAT Testing Report — [Month] [Year]

> Hi Cathy,
>
> Please find your monthly UAT testing analysis for [Month] [Year], pulled from
> your task data in Smartsheet.
>
> This month's highlights:
> - [X] projects tested, [X] testing rounds
> - Average testing duration: [X]d per project ([+/-X%] vs the Nov–Mar baseline)
> - R2 retests averaged [X]d
>
> Open it on the Knowledge Base (Reports → UAT Reports) — no login required.
>
> Best,
> [Your name]

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Start Date missing on some rows | Those rows are excluded from averages; add the Start Date in the project plan if the round should count |
| Duration blank on some rows | Excluded from averages (incomplete) — expected for rows still in progress |
| A project's R1/R2/R3 looks mislabeled | Rounds are assigned by start-date order, not the round name — check the Start Dates in Smartsheet |
| Old months' numbers changed | Expected — the series is recomputed from current data each run, so corrected Smartsheet edits flow into prior months |
| En-dashes / arrows show as mojibake | `cathy_gen.pl` must have `use utf8;` |

---

## Baseline Reference (Nov 2025 – Mar 2026) — fixed

| Metric | Value |
|---|---|
| Projects tested | 8 |
| Testing rounds | 21 |
| Date range | Nov 25, 2025 – Mar 27, 2026 |
| Avg total days per project | 8.75d |
| Avg R1 duration | 5.25d |
| Avg R2 duration | 3.00d |
| Avg R3 duration | 1.75d |
| R1 → R2 reduction | −42.9% |
| Longest project | RenRe — 16d |
