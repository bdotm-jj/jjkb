# Co-Work Instructions — Cathy Parmley UAT Testing Report
**Frequency:** Monthly  
**Owner:** PMO Team  
**Tool:** Co-Work (Desktop Automation)  
**Output:** Updated HTML presentation file with month-over-month testing metrics

---

## Purpose

Every month, export Cathy Parmley's task data from Smartsheet, run it through Claude to produce an updated analysis, and save the HTML presentation. The **first report (April 2026) is the baseline** — all subsequent months are compared against it to show trends over time.

---

## What This Report Tracks

- Total testing duration per project (days)
- Testing duration trend over time (line chart)
- R1 vs R2 vs R3 round comparison — are retests getting faster?
- Average duration per round
- Monthly change from baseline and prior month

---

## Step-by-Step Instructions

### Step 1 — Export the Cathy Parmley Task Report from Smartsheet

1. Open Smartsheet and navigate to:
   **JandJ-SCCAdmin - Projects → Reports folder → Cathy Parmley Task Report**
2. Click **File → Export → Export to Excel (.xlsx)**
3. Save the file as:
   `Cathy_Parmley_Tasks_[MONTH]_[YEAR].xlsx`
   *(Example: `Cathy_Parmley_Tasks_May_2026.xlsx`)*
4. Confirm the export includes these columns:
   - Primary (task name)
   - Project Name
   - Duration
   - Assigned
   - Section
   - Start Date

> **Note:** If Start Date is not visible in the report, add it before exporting. It is required for the timeline chart.

---

### Step 2 — Open Claude and Upload the File

1. Open a new Claude conversation at claude.ai
2. Upload the exported `.xlsx` file
3. Paste the following prompt exactly:

---

**Prompt to paste into Claude:**

> **IMPORTANT — use the fixed KB template.** Attach an existing KB-styled report as the template (e.g. `may-2026.html` from the Knowledge Base repo, `bdotm-jj/jjkb` → `reports/`). Every month must reproduce that exact template — same 5-slide structure, same KB styling — with only the data changed. This is what keeps the reports consistent month to month.

```
I am running the monthly Cathy Parmley UAT Testing Report. I've attached (a) this month's Smartsheet export and (b) an existing KB-styled report (may-2026.html) to use as the TEMPLATE.

Produce this month's report as a single self-contained HTML file that reproduces the attached template EXACTLY — same 5-slide structure, same layout, same Chart.js charts, and the same "KB" visual design. Change ONLY the data; do not redesign anything.

KB design system the template uses (do not deviate):
- Bone paper background #F2EDE2; ink #0F1B2D; accent #2E6DA4; positive/faster #3D6B3D; negative/slower #C24B1E; watch #B5860D.
- Fonts: Instrument Serif (display headings, with accent-blue italics), Inter (body), JetBrains Mono (eyebrows/labels/numerals, uppercase, letter-spacing).
- Flat surfaces, hairline rules, 2px radii, NO gradients, NO dark theme, NO emoji.
- Chart.js: axis ticks #5C6A80, grid rgba(15,27,45,0.10), tooltip bg #0F1B2D; series accent #2E6DA4 / #3D6B3D / #B5860D; trend line #97A0B2.

The 5 slides:
   - Slide 1: Cover — "Cathy Parmley UAT Testing Report — [Month] [Year]" + summary stats (projects tested, total tasks, avg total days, date range)
   - Slide 2: Key metrics — avg project total, avg R1 duration, avg R2 duration, longest project, plus 3 insight callouts (finding / outlier / watch)
   - Slide 3: Testing duration over time — line chart ordered by start date with average trendline
   - Slide 4: R1 vs R2 vs R3 round comparison — grouped bar chart + data table
   - Slide 5: Key findings and recommendations

Month-over-month comparison against the April 2026 baseline:
   - Baseline avg total days per project: 5.4d | avg R1: 4.6d | avg R2: 1.8d | R1→R2 reduction: -61% | projects tested: 16
   - Call out any metric that improved or declined vs baseline.

Return the full HTML as a downloadable artifact.
```

---

### Step 3 — Save the Output

1. When Claude produces the HTML artifact, click the artifact to open it full screen
2. Right-click anywhere on the page → **Save As**
3. Save as `[month]-[year].html`, lower-case (e.g. `july-2026.html`)
4. Save into the Knowledge Base repo at `reports/` (in the `bdotm-jj/jjkb` checkout). Keep a personal copy in `Documents → PMO Reports → Cathy Parmley → Monthly Reports` if desired.

---

### Step 3b — Register it on the Knowledge Base

The KB Reports index reads a manifest. To make the new month appear:

1. Open `app.jsx` in the `bdotm-jj/jjkb` repo and find `const REPORTS = [`.
2. Copy an existing entry (e.g. the newest month) and edit the fields — `id`, `title`, `date` (ISO; drives ordering, newest first), `period`, `file` (`reports/[month]-[year].html`), `summary`, and `stats`.
3. Commit and push. The new edition shows up automatically as the latest report on the KB — no other change needed.

---

### Step 4 — Update the Tracking Log

Open the **Cathy Parmley Monthly Metrics Log** (maintain this as a running spreadsheet) and add a new row with:

| Month | Projects Tested | Avg Total Days | Avg R1 | Avg R2 | R1→R2 % Change | Longest Project | Notes |
|---|---|---|---|---|---|---|---|
| Apr 2026 *(baseline)* | 16 | 5.4d | 4.6d | 1.8d | -61% | RenRe (16d) | Baseline established |
| May 2026 | *fill in* | *fill in* | *fill in* | *fill in* | *fill in* | *fill in* | |

> **Baseline row is fixed — never update it.** All subsequent months are compared to April 2026 values.

---

### Step 5 — Distribute

Send the HTML file to:
- Cathy Parmley (cathy.parmley@jjins.com)
- Relevant PM / manager

Use the email template below.

---

## Email Template

**Subject:** Your UAT Testing Report — [Month] [Year]

> Hi Cathy,
>
> Please find attached your monthly UAT testing analysis for [Month] [Year], pulled from your task data in Smartsheet.
>
> This month's highlights:
> - [X] projects tested, [X] total tasks
> - Average testing duration: [X]d per project ([+/-X%] vs April baseline)
> - R2 retests averaged [X]d ([+/-X%] vs baseline)
>
> Open the attached HTML file in any browser — no login required.
>
> Best,  
> [Your name]

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Start Date column missing from export | Add Start Date column to the report in Smartsheet before exporting |
| Duration column shows blank for some rows | Those tasks have no duration set — Claude will note them as incomplete and exclude from averages |
| Claude doesn't recognize the file format | Re-export as .xlsx, not .csv |
| HTML file won't open | Try a different browser — Chrome or Edge recommended |

---

## Baseline Reference (April 2026)

| Metric | Value |
|---|---|
| Projects tested | 16 |
| Total tasks | 36 |
| Date range | Nov 2025 – Apr 2026 |
| Avg total days per project | 5.4d |
| Avg R1 duration | 4.6d |
| Avg R2 duration | 1.8d |
| R1 → R2 reduction | -61% |
| Longest project | RenRe — 16d |
| Only R2 > R1 exception | GLISE Lifecycle API (R2: 3d vs R1: 2d) |
