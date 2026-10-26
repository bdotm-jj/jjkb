# Sprint Completion report — build pipeline

Turns each LOB's **Sprint Reports** workbook (e.g. `Stabilization Sprint Reports.xlsx`,
which is the **Stabilization** LOB) into a KB-styled report that charts every sprint's
**completion %** against the **80% goal**, plus tickets closed — and a landing page that
compares all LOBs against the goal.

**One workbook = one LOB.** The LOB name comes from the file, not the sheet
(Stabilization → "Stabilization"; other LOB files carry their real name).

## Files
| File | Role |
|---|---|
| `convert_sprint.pl` | unzipped xlsx + LOB name → `lobs/data-<lob>.json` (one entry per `Sprint N` sheet). Used for the spreadsheet LOBs (Stabilization, Commercial Lines) |
| `build_manual.pl` | `<LOB> <lob>_sprints.tsv` → `lobs/data-<lob>.json`. Used for LOBs sourced by hand (email / Confluence / one-off workbook): Personal Lines, Program, Flood |
| `sprint_gen.pl` | all `lobs/data-*.json` → per-LOB `../site/reports/sprint-<lob>.html` + landing `../site/reports/sprints.html` |
| `sprint_lob_template.html` | per-LOB report: completion-% line w/ 80% goal line, tickets-closed bars, sortable sprint table. Placeholders `__LOB__`, `__DATA__` |
| `sprint_index_template.html` | landing: each-LOB-vs-80%-goal bars + one-line-per-LOB trend + LOB cards. Placeholder `__DATA__` |
| `lobs/` | archived per-LOB `data-*.json`. **Gitignored** (holds ticket keys/summaries); only the HTML reports ship |
| `*_sprints.tsv` | transcribed source rows for the manual LOBs (`pl_sprints.tsv`, `program_sprints.tsv`, `flood_sprints.tsv`) — auditable; committed |

### LOB sources (as of Oct 2026)
| LOB | Source | Builder |
|---|---|---|
| Stabilization | `Stabilization Sprint Reports.xlsx` | `convert_sprint.pl … Stabilization …` |
| Commercial Lines | `CL_Sprint_Reports*.xlsx` | `convert_sprint.pl … "Commercial Lines" … compute` |
| Personal Lines | Abdoul Balla emails "PL - Sprint NN Final Report" (+ Confluence for Sprint 34) | `build_manual.pl "Personal Lines" pl_sprints.tsv …` |
| Program | `Program_Sprint_NN_Report.xlsx` (Summary + All Tickets; one sprint) — use **% Complete (excl. blocked)** = in-our-control | `build_manual.pl Program program_sprints.tsv …` |
| Flood | Confluence "Flood Pod — Sprint Index" child pages (PROVISIONAL until the official report arrives) | `build_manual.pl Flood flood_sprints.tsv …` |

Completion % is **taken as published by each LOB** (teams compute it on an in-our-control basis — completed ÷ (commitment − pending-3rd-party − waiting-on-customer) — but the exact "complete" set differs slightly by team). Per-sprint `note`s carry caveats (mid-sprint displacement, provisional figures). Append a row to the LOB's `*_sprints.tsv` (or drop a new workbook) and re-run its builder + `sprint_gen.pl`.

## What's measured
- **Completion %** = the workbook's own stored `Sprint Completion %` per sheet
  (their hours-based formula: completed ÷ (commitment − pending-3rd-party − waiting-on-customer)).
  Read verbatim — not recomputed. A sprint with no stored % (e.g. Stabilization Sprint 7) renders as a gap.
- **Tickets closed** = count of tickets in a `Done`/`Closed`/`Resolved` status that sprint.
- **Committed** = number of ticket rows in the sprint (apples-to-apples; early sprints store
  "Total Tickets Committed" as *hours*, so the row count is the ticket figure used).
- **Goal** = 80% (constant in each LOB json).

Sheets are **not uniform** week to week — headers drift (some tabs are `Column1..9`), the
status column moves, and the committed/`%` cells sit in different columns. `convert_sprint.pl`
finds the status column by content and the committed/% values by their row label, so it survives the drift.

## Add / refresh an LOB
From this folder:
```bash
# 1. unzip the LOB's workbook
rm -rf lob_x && unzip -q "/path/to/<LOB> Sprint Reports.xlsx" -d lob_x

# 2. convert -> archive under lobs/  (LOB name is explicit; Stabilization = Stabilization)
perl convert_sprint.pl lob_x "Stabilization" lobs/data-maintenance.json

# 3. regenerate every LOB report + the landing page
perl sprint_gen.pl
```
`sprints.html` is the entry point (LOBs ordered by latest completion %); each LOB report
back-links to it. Re-running `sprint_gen.pl` always rebuilds every report from current
`lobs/*.json`, so the cross-LOB charts pick up new LOBs automatically.

## Notes
- Aggregate by sprint/LOB only — **no assignee names** in the output (unlike the MARS report).
- `use utf8` in the Perl; KB design tokens + Chart.js 4.4.1 (cdnjs) match the rest of the KB.
