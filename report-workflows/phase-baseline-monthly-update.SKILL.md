---
name: phase-baseline-monthly-update
description: Monthly Phase Duration Baseline update — pulls completed phases from Smartsheet and updates the HTML baseline file
---

## Monthly Phase Duration Baseline Update

**Objective:** Update the Phase Duration Baseline HTML file with newly completed phase data from Smartsheet for the current month/quarter, including a Project Classification breakdown sourced from the Projects Intake Sheet.

---

### Step 1 — Determine the current quarter and date range

Based on today's date, determine which quarter is active and the date range to use:

| Quarter | Months | Date range |
|---------|--------|------------|
| Q2 | May, Jun, Jul updates | Apr 1 – Jun 30, 2026 |
| Q3 | Aug, Sep, Oct updates | Jul 1 – Sep 30, 2026 |
| Q4 | Nov, Dec, Jan updates | Oct 1 – Dec 31, 2026 |

Use today's date as the END DATE (e.g., if today is August 2, use August 2, 2026 — not the end of the quarter).

---

### Step 2 — Search Smartsheet for completed phases

Search Smartsheet for all sheets whose name contains "Project Plan" across all workspaces.

For each project plan sheet found, pull all rows where:
- **Level = 2** (phase header rows only)
- **Status = Complete**
- **End Date falls within the quarter's date range** (start of quarter through today)
- **Task/Phase name exactly matches one of these 8 phases:**
  1. Intake & Planning
  2. Requirements & Design
  3. Development
  4. Alpha Testing (Dev Testing)
  5. Acceptance Testing (UAT/Pre-Prod)
  6. Release
  7. Stabilization (Hypercare)
  8. Retrospective and Closeout

**Duration calculation:** End Date − Start Date + 1 (both endpoints inclusive, calendar days). Exclude rows missing a start or end date.

Columns to pull: Task, Level, Status, Start Date, End Date, Project Name

---

### Step 3 — Calculate statistics per phase

For each of the 8 phases, calculate:
- **Average duration** (in calendar days, rounded to 1 decimal)
- **Min** and **Max** duration
- **n** = count of completed phases included

If a phase has zero completions this quarter, note it as n=0 (leave as "—" in the HTML).

---

### Step 4 — Pull Project Classification from the Intake Sheet

The Projects Intake Sheet is at Smartsheet sheet ID **4414567862980484**.

For each unique project that had at least one qualifying completed phase in this quarter, look up its row in the intake sheet by matching **Project Name** and retrieve the **Project Classification** column value.

Project Classification options are:
- New UI / Full New Build
- Support & Specialty (Broad Scope)
- Carrier API Integration
- 3rd Party Integration
- New Feature — Legacy System
- Legacy System Change (No New Feature)
- New Feature — MARS (Existing System)
- New Company / Zero Contract
- Enhancement (Minor Change)
- Other

Group the contributing projects by their classification.

---

### Step 5 — Update the HTML file

The baseline HTML file is the **KB-styled** report in the Knowledge Base repo (`bdotm-jj/jjkb`):
`reports/phase-duration-baseline.html`

**Preserve the KB template.** This file is already styled in the Knowledge Base design system — bone paper `#F2EDE2`, ink `#0F1B2D`, accent `#2E6DA4`, Instrument Serif headings, Inter body, JetBrains Mono labels, flat surfaces, hairline rules, 2px radii, no gradients, no dark theme. **Change only the data — never restyle.** Do not introduce new fonts, colors, gradients, or layout. If you regenerate any markup, match the existing classes and tokens exactly.

Make the following updates (data only):

**Phase table:**
- Fill in the current quarter's avg column (Q2, Q3, or Q4) with the new averages
- Update the Range column if the new data extends the existing min or max
- Update the n count (cumulative across all quarters)
- Add the quarter's visual bar segment to each phase row

**Quarter summary card:**
- Remove the pending overlay
- Update with: total projects, overall avg days, longest phase name

**Contributing Projects section:**
- Update the "Q# contributing projects" section with the project names grouped by Project Classification

**Do not change any prior quarter's data.**

Save the updated file back to `reports/phase-duration-baseline.html` in the `bdotm-jj/jjkb` repo, then commit and push. It is already registered in the KB Reports manifest (`app.jsx` → `REPORTS`), so the refreshed data shows on the Knowledge Base automatically — no manifest change needed unless the stats on its index card changed.

Provide a link so the user can open the updated file.

---

### Methodology reminders

- Duration = End Date − Start Date + 1 (both endpoints inclusive)
- Only **completed** phases are included
- A phase end date **must fall within the quarter** to count
- Phases with no start or end date are excluded
- Projects in "Future Projects" folders are unlikely to have Q-period completions but should still be scanned

---

### Output

After completing the update, provide:
1. A summary table of phase averages calculated this month
2. The project list grouped by classification
3. A link to the updated HTML file
4. Any phases with n=0 or notable outliers
