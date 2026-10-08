# Cathy Parmley UAT Testing Report — build pipeline

Rebuilds the monthly UAT reports from the live Smartsheet **"Cathy Parmley Task
Report"** (report id `8800191256678276`) into KB-styled 5-slide HTML decks.

## Convention (standardized Oct 2026)
- Reports are labeled by the **month of the metrics** (cumulative through
  month-end), NOT the delivery month.
- **Current period = testing that started on/after Apr 8, 2026**, cumulative
  through the month-end, compared to the fixed **Nov 2025 – Mar 2026 baseline**
  (8 projects, avg total **8.75d**, R1 5.25d, R2 3.00d, R1→R2 −42.9%, longest
  RenRe 16d — computed the same way from the same source).
- Rounds (R1/R2/R3) are assigned by **start-date order within each project**
  (the round-name text is inconsistent, so sequence is authoritative). Verified:
  Scottsdale 10/5/6=21 and Atrium-PL 1/1/2=4 match the prior reports.
- Rows with **no start date** or **no duration** are excluded from averages.

## Files
| File | Role |
|---|---|
| `parse_cathy.pl` | report JSON (from the Smartsheet MCP `get_report`) → `cathy_clean.tsv` (startdate, project, dur, round) |
| `compute2.pl` | `cathy_clean.tsv` → `cathy_series.json` (baseline + Apr→Sep monthly aggregates, per-project rounds) |
| `cathy_gen.pl` | `cathy_series.json` + `cathy_template.html` → `../site/reports/<month>-2026.html` for each month (auto-generates callouts, baseline table, findings, recommendations) |
| `cathy_template.html` | the KB-styled 5-slide deck shell; `__DATA__`/`__MONTH__`/`__YEAR__` filled by `cathy_gen.pl` |

## Monthly refresh
```bash
# 1. pull the report via the Smartsheet MCP (get_report id 8800191256678276),
#    save the JSON, then:
perl parse_cathy.pl <report.json>     # -> cathy_clean.tsv
perl compute2.pl                      # -> cathy_series.json  (add the new month-end to @MONTHS)
perl cathy_gen.pl                     # -> ../site/reports/<month>-2026.html (all months)
```
Then add/adjust the `REPORTS` entry in `../site/app.jsx` (group "uat", labeled by
metrics month, `date` = month-end for newest-first ordering) and bump the app
cache in `index.html`.

> The whole series is recomputed each run from current data, so late Smartsheet
> edits (new rounds, corrected durations) flow into every month consistently —
> no drift between months.
