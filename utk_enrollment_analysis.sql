-- ============================================================================
-- UTK INSTITUTIONAL EFFECTIVENESS: ENROLLMENT ANALYSIS QUERIES
-- ============================================================================
### UTK Enrollment Trends Analysis (2020–2024)

A SQL portfolio project analyzing publicly available enrollment data from the
University of Tennessee, Knoxville's Office of Institutional Research and
Strategic Analysis (IRSA).

**Data source:** [UTK Orange Report](https://data.utk.edu/enrollmentmanagement/)
— published by the Division of Enrollment Management.

-- Purpose: Analyze University of Tennessee Knoxville enrollment trends across
--          multiple student categories (in-state, out-of-state, international,
--          minority, underrepresented minority) and academic metrics
-- 

-- Author: Vi


## Key Questions Answered

1. How fast is total undergraduate enrollment growing?
2. Is UTK becoming more of an out-of-state institution?
3. How has the academic profile (GPA, ACT, SAT) of incoming freshmen changed?
4. Is diversity (URM %) improving in absolute and relative terms?
5. How does transfer student enrollment track vs. first-year enrollment?
6. Which year saw the biggest single-year growth jump?

## Skills Demonstrated

- Schema design with constraints
- Multi-table relational data model
- Window functions: LAG()
- Calculated fields and percentage metrics
- Aggregations and trend analysis
- Reusable SQL views

---

*Data is publicly available and sourced directly from UTK IRSA publications.*

-- ============================================================================

-- ============================================================================
-- TABLE 1: ENROLLMENT_TOTALS
-- ============================================================================
-- Purpose: FACT TABLE - Store aggregate enrollment data by term
-- Grain: One row per term (semester)
-- Contains: Total enrollment counts broken down by student category
-- ============================================================================

DROP TABLE IF EXISTS enrollment_totals;

CREATE TABLE enrollment_totals (
    term               VARCHAR(20) PRIMARY KEY,      -- Unique term ID (e.g., 'FALL2023', 'SPRING2024')
    term_year          INT NOT NULL,                 -- Academic year (e.g., 2023, 2024)
    total_headcount    INT NOT NULL,                 -- Total enrolled students (fact measure)
    in_state           INT NOT NULL,                 -- Count: In-state students
    out_of_state       INT NOT NULL,                 -- Count: Out-of-state students
    international      INT NOT NULL,                 -- Count: International students
    minority           INT NOT NULL,                 -- Count: Students identifying as minority
    urm                INT NOT NULL                  -- Count: Underrepresented Minority (URM) students
);

-- Verification: Check table was created
SELECT * FROM enrollment_totals;


-- ============================================================================
-- TABLE 2: FIRST_YEAR_ENROLLMENT
-- ============================================================================
-- Purpose: DIMENSION TABLE - Track first-year/freshman cohort metrics
-- Grain: One row per term
-- Contains: Freshman enrollment counts and academic profile metrics
-- ============================================================================

CREATE TABLE first_year_enrollment (
    term               VARCHAR(20) PRIMARY KEY,              -- Foreign key to enrollment_totals
    term_year          INT NOT NULL,                         -- Academic year
    headcount          INT NOT NULL,                         -- Number of new freshmen enrolled
    in_state           INT NOT NULL,                         -- New freshmen from in-state
    out_of_state       INT NOT NULL,                         -- New freshmen from out-of-state
    international      INT NOT NULL,                         -- New freshmen who are international
    minority           INT NOT NULL,                         -- New freshmen identifying as minority
    avg_hs_gpa         NUMERIC(4,2) NOT NULL,                -- Average high school GPA (e.g., 3.82)
    pct_above_4_gpa    NUMERIC(5,1),                         -- Percentage of freshmen with HS GPA > 4.0 (weighted)
    avg_act            NUMERIC(4,1) NOT NULL,                -- Average ACT composite score (e.g., 28.5)
    avg_sat            INT NOT NULL                          -- Average SAT total score (e.g., 1250)
);


-- ============================================================================
-- TABLE 3: TRANSFER_ENROLLMENT
-- ============================================================================
-- Purpose: DIMENSION TABLE - Track transfer student metrics
-- Grain: One row per term
-- Contains: Transfer enrollment counts and academic profile
-- ============================================================================

CREATE TABLE transfer_enrollment (
    term               VARCHAR(20) PRIMARY KEY,              -- Foreign key to enrollment_totals
    term_year          INT NOT NULL,                         -- Academic year
    headcount          INT NOT NULL,                         -- Number of transfer students
    in_state           INT NOT NULL,                         -- Transfer students from in-state institutions
    out_of_state       INT NOT NULL,                         -- Transfer students from out-of-state institutions
    international      INT NOT NULL,                         -- International transfer students
    minority           INT NOT NULL,                         -- Transfer students identifying as minority
    avg_transfer_gpa   NUMERIC(4,2) NOT NULL                 -- Average GPA from prior institution (e.g., 3.45)
);


-- ============================================================================
-- VIEW 1: v_enrollment (COMPREHENSIVE ENROLLMENT PROFILE)
-- ============================================================================
-- Purpose: JOIN all enrollment tables to create single analytical view
-- Use Case: Faculty/deans need holistic view of enrollment composition
-- ============================================================================

CREATE VIEW v_enrollment AS
SELECT 
    -- Identifiers
    e.term,                                                    -- Term identifier (e.g., 'FALL2023')
    e.term_year,                                               -- Academic year
    
    -- Absolute counts
    e.total_headcount AS total_ug,                             -- Total undergraduate enrollment
    f.headcount AS new_freshman,                               -- New freshman cohort size
    t.headcount AS new_transfers,                              -- New transfer cohort size

    -- FORMULA 1: OUT-OF-STATE PERCENTAGE
    -- Purpose: Show proportion of out-of-state students
    -- Formula: (out_of_state / total_headcount) * 100
    -- Why: Institutional effectiveness metric - shows geographic diversity
    -- Example: If 800 out of 10,000 students are out-of-state: (800/10000)*100 = 8%
    ROUND(e.out_of_state * 100 / e.total_headcount, 1) AS pct_out_of_state,
    
    -- FORMULA 2: UNDERREPRESENTED MINORITY (URM) PERCENTAGE
    -- Purpose: Measure demographic diversity for equity reporting
    -- Formula: (urm_count / total_headcount) * 100.0
    -- Why: Required by IPEDS and institutional diversity goals
    -- Example: If 1,500 URM out of 10,000: (1500/10000)*100 = 15%
    -- Note: Use 100.0 (float) not 100 (int) to ensure decimal precision
    ROUND(e.urm * 100.0 / e.total_headcount, 1) AS pct_urm,
    
    -- Academic profile metrics (freshman cohort)
    f.avg_hs_gpa,                                              -- Average high school GPA of new freshmen
    f.avg_act,                                                 -- Average ACT score of new freshmen
    f.avg_sat,                                                 -- Average SAT score of new freshmen
    
    -- Transfer academic profile
    t.avg_transfer_gpa                                         -- Average college GPA of transfer students
    
FROM enrollment_totals e
-- INNER JOIN: Only include terms with freshman and transfer data
JOIN first_year_enrollment f USING (term)
JOIN transfer_enrollment t USING (term)

ORDER BY e.term_year;

-- Test the view
SELECT * FROM v_enrollment;


-- ============================================================================
-- VIEW 2: v_yoy_growth (YEAR-OVER-YEAR GROWTH ANALYSIS)
-- ============================================================================
-- Purpose: Calculate enrollment growth rates term-to-term
-- Use Case: Track enrollment trends, identify growth/decline patterns
-- Window Function: LAG() to compare current to previous term
-- ============================================================================

CREATE VIEW v_yoy_growth AS 
SELECT 
    term,                                                      -- Current term
    term_year,                                                 -- Current academic year
    total_headcount,                                           -- Current term enrollment
    
    -- WINDOW FUNCTION: LAG() gets previous term's headcount
    -- Syntax: LAG(column) OVER (ORDER BY sort_column)
    -- Purpose: Enables comparison of current vs previous values without JOIN
    LAG(total_headcount) OVER (ORDER BY term_year) 
        AS prev_headcount,                                     -- Previous term enrollment for comparison
    
    -- FORMULA 3: YEAR-OVER-YEAR GROWTH PERCENTAGE
    -- Purpose: Measure enrollment growth rate between consecutive terms
    -- Formula: ((current - previous) / previous) * 100
    -- 
    -- Breaking it down:
    --   1. (total_headcount - LAG(total_headcount)) = absolute change
    --   2. Divide by LAG(total_headcount) = rate of change
    --   3. Multiply by 100.0 = convert to percentage
    --   4. NULLIF(LAG(...), 0) = prevent division by zero (if previous was 0)
    --   5. ROUND(..., 1) = round to 1 decimal place for readability
    --
    -- Example: If previous term had 10,000 students and current has 10,200:
    --   ((10200 - 10000) / 10000) * 100 = (200 / 10000) * 100 = 2.0% growth
    --
    -- Edge cases handled:
    --   - First term: LAG() returns NULL, so pct_growth = NULL (expected)
    --   - Division by zero: NULLIF prevents error if previous = 0
    --
    ROUND(
        (total_headcount - LAG(total_headcount) OVER (ORDER BY term_year)) 
        * 100.0 
        / NULLIF(LAG(total_headcount) OVER (ORDER BY term_year), 0),
        1
    ) AS pct_growth 
    
FROM enrollment_totals
ORDER BY term_year;

-- Test the view
SELECT * FROM v_yoy_growth;



-- ============================================================================
-- ANALYTICAL QUERIES - DASHBOARD VISUALIZATIONS
-- ============================================================================
-- These queries power the Power BI dashboards and reports
-- Reference: UTK pdf.pdf - 5 slide Power BI dashboard
-- ============================================================================

-- ============================================================================
-- GRAPH 1: UTK UNDERGRADUATE ENROLLMENT GROWTH (2020-2024)
-- ============================================================================
-- PDF Reference: SLIDE 2 (Line chart showing total headcount trend)
-- Data Points: Fall 2020: 24.3K → Fall 2024: 30.6K
-- Purpose: Show total enrollment growth trajectory over time
-- Visualization: Line chart with term on X-axis, total_headcount on Y-axis
-- Key Insight: 26% growth in 4 years (24,254 to 30,564 students)
-- Business Implication: Growth acceleration from 2020-2022 (post-pandemic recovery)
--                       Continued steady growth 2022-2024
--
SELECT 
    term,
    term_year,
    total_headcount
FROM enrollment_totals
ORDER BY term_year;


-- ============================================================================
-- GRAPH 2: OUT-OF-STATE VS IN-STATE STUDENT SHIFT (4-YEAR TREND)
-- ============================================================================
-- PDF Reference: SLIDE 3 (Stacked bar chart showing geographic composition)
-- Data Points: 
--   Fall 2020: 21% out-of-state, 79% in-state
--   Fall 2024: 35% out-of-state, 65% in-state
-- Purpose: Show geographic composition change over time
-- Visualization: Stacked or grouped bar chart
-- Key Insight: 14-percentage-point swing toward out-of-state recruitment
-- Business Implication: Higher tuition revenue + national reach + less dependent on TN
--
-- Formula Explanation:
--   pct_in_state = (in_state / total_headcount) * 100
--   pct_out_of_state = (out_of_state / total_headcount) * 100
--
-- Why separate these percentages?
--   - Shows how composition is shifting (attraction to in-state vs out-of-state)
--   - Institutional goal tracking (often want to increase out-of-state)
--   - Budget implications (out-of-state students pay higher tuition = more revenue)
--   - Example: 14-point swing toward out-of-state = significant revenue growth
--
SELECT 
    term,
    term_year,
    ROUND(in_state * 100.0 / total_headcount, 1) AS pct_in_state,
    ROUND(out_of_state * 100.0 / total_headcount, 1) AS pct_out_of_state
FROM enrollment_totals 
ORDER BY term_year;


-- ============================================================================
-- GRAPH 3: FRESHMAN ACADEMIC PROFILE TREND
-- ============================================================================
-- PDF Reference: SLIDE 4 (Three line charts: GPA, SAT, ACT)
-- Data Points:
--   GPA: 3.93 (Fall 2020) → 4.17 (Fall 2024) [+0.24 increase]
--   SAT: 1218 (Fall 2020) → 1283 (Fall 2024) [+65 points]
--   ACT: 27.7 (Fall 2020) → 27.9 (Fall 2024) [stable]
--
-- Purpose: Show whether incoming freshman class quality is improving/declining
-- Visualization: Multi-line chart (one line per metric)
-- Key Insight: As enrollment grew 26%, student quality IMPROVED
-- Business Implication: Better retention, grad rates, and graduate success
--
-- Metrics measured:
--   - avg_hs_gpa: Indicator of college readiness (0.0-4.0 scale)
--   - avg_act: Standardized test performance (max 36)
--   - avg_sat: Standardized test performance (max 1600)
--
-- Interpretation:
--   - Upward trend: Admission standards increasing, better student preparation
--   - Downward trend: May indicate enrollment challenges or strategic shift
--   - Our case: UPWARD TREND = Stronger cohorts as we grow enrollment
--
SELECT 
    term,
    term_year,
    avg_hs_gpa, 
    avg_act, 
    avg_sat
FROM first_year_enrollment 
ORDER BY term_year;


-- ============================================================================
-- GRAPH 4: YEAR-OVER-YEAR ENROLLMENT GROWTH %
-- ============================================================================
-- PDF Reference: SLIDE 5 (Bar chart showing growth rates by year)
-- Data Points: Fall 2021: 3.4% → Fall 2022: 7.9% → Fall 2023: 6.8% → Fall 2024: 5.8%
-- Purpose: Show enrollment growth trajectory and identify acceleration/deceleration
-- Visualization: Bar chart with term on X-axis, pct_growth on Y-axis
-- 
-- Key Insights:
--   - Fall 2021: 3.4% (post-pandemic, stabilization from lowest point)
--   - Fall 2022: 7.9% (PEAK - major post-COVID rebound)
--   - Fall 2023: 6.8% (continued growth but moderating)
--   - Fall 2024: 5.8% (healthy, sustainable growth rate)
--
-- Business Implication: Growth is moderating to sustainable 5-6% levels
--                       Not boom-bust cycle, but steady trajectory
--                       National avg growth: 2-3%, UTK at 5.8% = very strong
--
SELECT * FROM v_yoy_growth;


-- ============================================================================
-- NOTES FOR FACULTY/DEANS
-- ============================================================================
-- These queries support:
-- 1. STRATEGIC PLANNING: Are we on track with enrollment goals?
-- 2. BUDGET FORECASTING: Total revenue based on headcount and student mix
-- 3. DIVERSITY METRICS: Progress toward inclusion goals (IPEDS reporting)
-- 4. INSTITUTIONAL EFFECTIVENESS: Demonstrated through enrollment trends
-- 5. COMPARATIVE ANALYSIS: How do we compare to peer institutions?
--

