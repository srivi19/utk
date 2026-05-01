# UTK Enrollment Trends Analysis 2020-2024

Analyzing University of Tennessee Knoxville enrollment data from 2020-2024.

## What This Project Does

Tracks enrollment growth, geographic mix, and student quality using SQL and Power BI dashboards.

## Key Findings

- **26% enrollment growth** in four years (twenty-four thousand to thirty thousand students)
- **35% out-of-state** students (up from 21%)
- **Student quality improved**: GPA from three point ninety-three to four point seventeen, SAT from twelve eighteen to twelve eighty-three
- **Growth is sustainable**: peaked at seven point nine percent in twenty twenty-two, now stable at five point eight percent

## The Data

Three tables:
- `enrollment_totals` — Total enrollment by semester
- `first_year_enrollment` — Freshman GPA, ACT, SAT scores
- `transfer_enrollment` — Transfer student metrics

Two views:
- `v_enrollment` — Combined view of all enrollment data
- `v_yoy_growth` — Year-over-year growth rates

## The Queries

Four graphs power the Power BI dashboard:

1. **Graph 1** — Total enrollment growth (line chart)
2. **Graph 2** — Out-of-state vs in-state shift (stacked bar)
3. **Graph 3** — Freshman academic profile (three line charts)
4. **Graph 4** — Year-over-year growth percent (bar chart)



## Skills Shown

- Star schema design
- Window functions (LAG)
- Percentage calculations
- SQL views
- Data analysis for institutional decision-making

## Files

- `utk_enrollment_analysis.sql` — All SQL code
- `enrollment_totals.csv` — Sample data
- `first_year_enrollment.csv` — Sample data
- `transfer_enrollment.csv` — Sample data

---

**Data source**: UTK Orange Report (publicly available)  
**Author**: Vi
