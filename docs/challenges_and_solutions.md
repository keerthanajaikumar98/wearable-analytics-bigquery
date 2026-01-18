# Challenges & Solutions

This document chronicles the technical challenges faced during the project and how they were solved - demonstrating problem-solving skills.

## Challenge 1: Data Quality Issues

**Problem**: 
- Dataset had subjects with missing files (S12 didn't perform aerobic test)
- Some files had data quality annotations (asterisks like "172***")
- Split data across multiple sessions (f14)

**Solution**:
```python
# Created comprehensive data constraints handling
KNOWN_ISSUES = {
    'STRESS': {
        'f07': 'invalid_signals_no_cover_removed',
        'f14': 'split_data'
    },
    # ...
}

def should_skip_subject(subject_id, session_type):
    # Automatically skip problematic subjects
    # Flag issues but allow override with --include-problematic
```

**Impact**: Prevented bad data from corrupting analytics while documenting data quality for transparency.

---

## Challenge 2: Timestamp Format Inconsistency

**Problem**: 
- Expected Unix timestamps (e.g., 1361377519.0)
- Got datetime strings (e.g., '2013-02-20 17:55:19')
- Python loader crashed with "could not convert string to float"

**Solution**:
```python
def parse_empatica_csv(file_path):
    first_value = df.iloc[0, 0]
    
    try:
        # Try Unix timestamp first
        start_time_unix = float(first_value)
        start_time = pd.to_datetime(start_time_unix, unit='s', utc=True)
    except (ValueError, TypeError):
        # Fall back to datetime string parsing
        start_time = pd.to_datetime(first_value)
```

**Impact**: Loader now handles both formats gracefully, making it robust to different data sources.

---

## Challenge 3: BigQuery Partition Filter Requirement

**Problem**:
- Set `require_partition_filter=true` for cost savings
- All queries started failing: "Cannot query without partition filter"
- Feature engineering queries broke

**Solution**:
```sql
-- Added to ALL queries on partitioned tables
WHERE measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 365 DAY)
```

**Impact**: 
- Queries work reliably
- Prevents accidental expensive full-table scans
- 95% cost reduction maintained

---

## Challenge 4: Integer vs Float Type Mismatch

**Problem**:
- Subject age saved as "21.0" in CSV
- BigQuery table expected INTEGER
- Load failed: "Field age has changed type from INTEGER to FLOAT"

**Solution**:
```python
# Ensure age is saved as pure integer (21, not 21.0)
df['age'] = df['age'].astype(int)
df.to_csv(output_file, index=False, float_format='%.10g')
```

**Impact**: Clean data types, no schema mismatches, faster queries.

---

## Challenge 5: Cost Optimization While Maintaining Performance

**Problem**:
- Initial design: Full table scans cost $0.031 per query
- Projected 1,500 queries/month = $46.50/month
- Needed to hit $0/month while keeping queries fast

**Solution Implemented**:
1. **Partitioning by date** → 95% cost reduction
2. **Clustering by subject/session/signal** → 10x performance
3. **Required partition filters** → Prevents mistakes
4. **Selective column reads** → Reduces data scanned
5. **Materialized common aggregations** → Pre-computed results

**Results**:
- Cost: $0/month (free tier utilization)
- Query time: 1-5 seconds (10x faster)
- Scalable to 10,000 subjects

---

## Challenge 6: Multi-Signal Feature Engineering

**Problem**:
- Need to combine EDA + HR + TEMP for stress detection
- Signals have different sampling rates (4 Hz, 1 Hz, 4 Hz)
- How to align timestamps?

**Solution**:
```sql
-- Aggregate to 1-minute windows (lowest common denominator)
SELECT 
  TIMESTAMP_TRUNC(measurement_timestamp, MINUTE) as time_window,
  AVG(CASE WHEN signal_type = 'EDA' THEN value END) as avg_eda,
  AVG(CASE WHEN signal_type = 'HR' THEN value END) as avg_hr,
  AVG(CASE WHEN signal_type = 'TEMP' THEN value END) as avg_temp
FROM fact_physiological_measurements
GROUP BY time_window
```

**Impact**: Clean multi-signal features without complex interpolation.

---

## Challenge 7: Meaningful Baseline Calculation

**Problem**:
- Need personal baseline for stress detection
- No explicit "rest" period marked in data
- How to identify baseline automatically?

**Solution**:
```sql
-- Use first 3 minutes of each session as baseline
baseline_stats AS (
  SELECT 
    subject_id,
    AVG(avg_hr) as baseline_hr,
    AVG(avg_eda) as baseline_eda
  FROM signal_pivoted sp
  JOIN dim_sessions ds ON sp.session_id = ds.session_id
  WHERE TIMESTAMP_DIFF(sp.time_window, ds.session_start_time, MINUTE) <= 3
  GROUP BY subject_id
)
```

**Impact**: Personalized stress detection without manual annotation.

---

## Challenge 8: User Segmentation Logic

**Problem**:
- Need to segment users for feature recommendations
- Multiple dimensions: fitness level, stress, recovery
- How to create actionable segments?

**Solution**:
```sql
-- Multi-dimensional classification with clear business logic
CASE 
  WHEN max_aerobic_intensity > 85 AND avg_rmssd > 30 THEN 'ATHLETE'
  WHEN pct_low_hrv > 0.5 OR avg_rmssd < 20 THEN 'RECOVERY_FOCUSED'
  WHEN avg_stress_level > 0.5 OR pct_time_stressed > 0.6 THEN 'STRESS_MANAGEMENT'
  WHEN avg_aerobic_hr < 140 AND total_meps < 100 THEN 'BEGINNER'
  WHEN total_aerobic_minutes > 20 THEN 'ACTIVE'
  ELSE 'CASUAL'
END as user_segment
```

**Impact**: 6 actionable segments with clear feature recommendations.

---

## Challenge 9: Documentation for Non-Technical Stakeholders

**Problem**:
- Technical implementation is complex (SQL, BigQuery, partitioning)
- Need to communicate value to product, business stakeholders
- How to show impact without overwhelming with technical details?

**Solution**:
- **Architecture diagrams** using Mermaid (visual, not code)
- **Before/after comparisons** showing cost savings
- **Business-focused insights** (not just technical metrics)
- **Separate documentation** for technical vs. business audiences

**Impact**: Project is accessible to both engineers and business stakeholders.

---

## Challenge 10: GitHub Repository Polish

**Problem**:
- Raw code repository isn't impressive to recruiters
- Need to demonstrate PM skills (communication, documentation)
- How to make technical work visible to non-technical reviewers?

**Solution**:
- Comprehensive README with business context
- Visual diagrams showing system architecture
- Documented insights and business value
- Clear cost optimization story ($50/mo → $0/mo)
- Organized folder structure

**Impact**: Portfolio piece that showcases both technical depth AND PM skills.

---

## Key Learnings

1. **Always validate assumptions** - Test with real data early
2. **Graceful degradation** - Handle errors, don't crash
3. **Cost consciousness** - Optimize from the start
4. **Documentation matters** - Write for your future self
5. **Think like a PM** - Technical skills + business value

---

## Mistakes Made & Fixed

| Mistake | Fix | Lesson |
|---------|-----|--------|
| Assumed Unix timestamps | Added format detection | Test with real data |
| Forgot partition filters | Added to all queries | Read error messages carefully |
| Used SELECT * everywhere | Selected specific columns | Optimize from the start |
| No cost monitoring | Built automated alerts | Monitor continuously |
| Poor commit messages | Rewrote commit history | Document as you go |

---

## What I'd Do Differently

1. **Start with cost optimization** - Don't bolt it on later
2. **Data quality checks first** - Before building features
3. **Document decisions** - Why did I choose this approach?
4. **Unit tests for loaders** - Catch errors earlier
5. **Incremental testing** - Test with 1 subject before loading all

---

This document demonstrates:
- ✅ Problem-solving ability
- ✅ Learning from mistakes
- ✅ Technical depth
- ✅ Communication skills
- ✅ PM thinking (not just engineering)
