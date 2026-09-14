# MARS weekly report — build pipeline

Turns Amy Perez's weekly **Dev Time & Ticket Reporting** workbook into the
KB-styled, sortable HTML report **and** accumulates a multi-week trend history.

## Files
| File | Role |
|---|---|
| `convert.pl` | xlsx (unzipped) → `mars_data.json` (all sheets as arrays) |
| `build.pl` | `mars_data.json` → per-week **aggregate** summary → upsert `trends.json` → inject `DATA` + `TRENDS` into the template → write the report HTML |
| `report_template.html` | the report shell (Overview + Trends + data tabs). Placeholders `__DATA__` and `__TRENDS__` are filled by `build.pl` |
| `trends.json` | accumulating array of per-week aggregate summaries, oldest→newest. **Aggregate only — no individual names.** |
| `weeks/` | archived per-week `data-YYYY-MM-DD.json` (the full DATA for each week) |

## Add a new week
From this folder:

```bash
# 1. unzip the week's workbook into ./mars_x
unzip "/path/to/MARS_Weekly_Report_YYYY-MM-DD_to_YYYY-MM-DD.xlsx" -d mars_x

# 2. convert to DATA json, then archive it under weeks/
perl convert.pl                     # writes mars_data.json (reads ./mars_x)
cp mars_data.json weeks/data-<MON>.json     # <MON> = week's Monday, YYYY-MM-DD

# 3. build: updates trends.json AND writes the report
perl build.pl <MON> "<label>" weeks/data-<MON>.json ../site/reports/mars-weekly-<MON>.html
#   e.g. perl build.pl 2026-09-07 "Sep 7-11" weeks/data-2026-09-07.json ../site/reports/mars-weekly-2026-09-07.html
```

Then, in `../site/app.jsx`, add a `REPORTS` entry (`group: "mars"`) pointing at the
new file (or repoint a single rolling entry), and deploy.

- **Labels must be ASCII** (use `-`, not an en-dash) — they pass through the shell
  into JSON and a non-ASCII dash mojibakes.
- The **Trends tab** shows a baseline card at 1 week and real week-over-week line
  charts at ≥2 weeks; the Overview gains a "Week over week" alert at ≥2 weeks —
  all automatic from `trends.json`.

## Per-week summary schema (`trends.json` entries)
Aggregate only — safe to keep even if the per-person report is gated.
```
week         "YYYY-MM-DD" (Monday, sort key)
label        short x-axis label, e.g. "Sep 7-11"
people       headcount in the Weekly Summary
teamHours    sum of Wk Total
expected     sum of Exp/wk (range midpoints)
util         teamHours / expected
tickets      sum of Tickets Worked
weeklyCloses sum of the weekly Dev Closes column
closesMTD    sum of the Dev Closes sheet (August MTD scope)
avgHours     teamHours / people
flags        { lowHoursRed, lowVolRed, bounceHigh }  (counts)
friDrop      (Mon–Thu avg − Fri) / Mon–Thu avg
byRole       { <group>: { count, logged, expected, tickets, closes } }
             groups: Developer / Jr Dev / Senior-Staff / QA / Data-Other
```
