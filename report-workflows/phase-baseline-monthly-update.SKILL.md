---
name: phase-baseline-monthly-update
description: Monthly Phase Duration Baseline update — recomputes phase durations (median active-span) from Smartsheet project plans and rebuilds the KB report
---

## Monthly Phase Duration Baseline Update

**Objective:** Rebuild the Phase Duration Baseline report from the current Smartsheet project plans, measuring each completed phase by the **active span of its child tasks** and summarizing each phase/quarter by the **median** (robust to long-idle outliers).

---

## Conventions (standardized Oct 2026 — these are fixed)

- **Duration = active span of child tasks** = (first child Start → last child End) + 1 calendar day. **NOT** the phase-header's own Start→End span, which balloons whenever a phase sits open/idle (e.g. a UAT header that spanned Jun 2025 → Jun 2026 = 386d while actual testing was days). Where a phase header has no dated children, fall back to the header's own dates.
- **A phase counts** when its Level-2 header `Status = Complete`. Rows with no start/end date are excluded.
- **Quarter = the quarter the phase COMPLETED in** (by its active end date): Q1 = Jan–Mar, Q2 = Apr–Jun, Q3 = Jul–Sep, Q4 = Oct–Dec (2026).
- **Headline per phase/quarter = MEDIAN**, shown with **n** and the **min–max range**. Cells with **n < 3** are flagged *provisional*. Phases with an active span **≥ 90 days** are listed as **long-running outliers** (they sit in the range but do not pull the median).
- **The whole series is recomputed from current data every run** — no frozen prior quarters, so corrected Smartsheet edits flow into all quarters consistently.
- The 8 standard phases: Intake & Planning · Requirements & Design · Development · Alpha Testing (Dev Testing) · Acceptance Testing (UAT/Pre-Prod) · Release · Stabilization (Hypercare) · Retrospective and Closeout.

---

## Monthly Process

The build lives in the KB repo (`bdotm-jj/jjkb`) at **`phase-pipeline/`**.

### Step 1 — Pull phase rows from the project plans
There is **no aggregating Smartsheet report** for phases, so scan the individual project-plan sheets. Find them with `search` (scope `sheetNames`, query "Project Plan"); skip Future-Projects / Archive / Template sheets. For each, via the Smartsheet connector `get_sheet_summary`:
```
columns: ["Task","Level","Status","Start Date","End Date","Phase","Project Name"]
filters: [{columnName:"Phase", operator:"NOT_IN", columnValue:["Project Information","Summary"]}]
```
This returns the 8 phase header rows (Level "2.0") plus their child tasks, tagged by the `Phase` column. For each phase whose header is Complete, take the active span over its dated child rows (fallback to the header). Record `{project, phase, quarter, activeDays, headerDays, activeStart, activeEnd, nChildren}` into `phase_data.json`. *(A sub-agent is handy here — ~70 sheets.)*

### Step 2 — Compute & generate
```bash
perl phase_gen.pl    # phase_data.json + phase_template.html -> ../site/reports/phase-duration-baseline.html
```
It computes the median/n/range per phase/quarter, the quarter roll-ups, the long-running outliers, and the data-quality notes, and injects them into the KB-styled report. (`use utf8` + `qq{}` for any `\x{...}` escapes, or dashes/arrows mojibake.)

### Step 3 — Register / refresh the KB card
The report is already in `site/app.jsx` `REPORTS` (`group:"phase"`). Update its `stats`/`summary` if the headline quarter numbers changed; bump the `app.jsx?v=` cache in `index.html` if app.jsx changed.

### Step 4 — Deploy
Commit and push to `main`; GitHub Pages redeploys. Provide the link.

---

## Data-quality watch-outs (seen Oct 2026)
- **Header-span inflation:** several headers span far longer than their active child work (e.g. CPAC Alpha header 274d vs 54d active). The active-span method corrects this; `phase_gen.pl` lists the worst cases.
- **Indexing Automation** uses a non-standard template (Design/Build/Beta/Production, no Level/Start/End) — excluded.
- **Casper Cyber Program** has malformed WBS levels (phase headers tagged Level 1, blank Phase cells) — recover its phases by matching the task name to the phase name.
- A few headers have an end date but no dated children → header fallback; a couple of date-less headers are non-computable and skipped.

---

## Output
After the update, provide: the median-by-phase/quarter table, the quarter roll-ups (projects · completions · overall median), the long-running-outlier list, and a link to the rebuilt report.
