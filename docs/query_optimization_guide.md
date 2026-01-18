# BigQuery Query Optimization Guide

## Cost Optimization Principles

### 1. Always Use Partition Filters

**❌ BAD - Scans entire table:**
```sql
SELECT COUNT(*) 
FROM wearable_analytics.fact_physiological_measurements
WHERE subject_id = 'S01';
-- Cost: Scans all partitions = $0.03 for 5GB table
```

**✅ GOOD - Scans only relevant partitions:**
```sql
SELECT COUNT(*) 
FROM wearable_analytics.fact_physiological_measurements
WHERE subject_id = 'S01'
  AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY);
-- Cost: Scans 7 days = ~$0.001
-- **Savings: 97%**
```

### 2. Use Clustering Columns in WHERE Clauses

**✅ OPTIMIZED - Uses clustering:**
```sql
SELECT *
FROM wearable_analytics.fact_physiological_measurements
WHERE measurement_timestamp >= '2025-01-01'
  AND subject_id = 'S01'          -- Clustered column #1
  AND session_type = 'STRESS'     -- Clustered column #2
  AND signal_type = 'HR';         -- Clustered column #3
-- BigQuery only reads blocks containing this combination
```

### 3. SELECT Only Needed Columns

**❌ BAD - Scans all columns:**
```sql
SELECT * 
FROM wearable_analytics.fact_physiological_measurements
WHERE measurement_timestamp >= '2025-01-01';
-- Reads all 8 columns
```

**✅ GOOD - Reads only needed columns:**
```sql
SELECT subject_id, measurement_timestamp, value
FROM wearable_analytics.fact_physiological_measurements
WHERE measurement_timestamp >= '2025-01-01';
-- Reads only 3 columns
-- **Savings: 62%**
```

### 4. Use LIMIT for Exploratory Queries

**❌ BAD - Processes entire dataset:**
```sql
SELECT * 
FROM wearable_analytics.fact_physiological_measurements
WHERE measurement_timestamp >= '2025-01-01'
ORDER BY measurement_timestamp DESC;
```

**✅ GOOD - Processes less data:**
```sql
SELECT * 
FROM wearable_analytics.fact_physiological_measurements
WHERE measurement_timestamp >= '2025-01-01'
ORDER BY measurement_timestamp DESC
LIMIT 100;
-- BigQuery can stop early
```

### 5. Use Approximate Aggregations

**❌ EXPENSIVE - Exact count:**
```sql
SELECT COUNT(DISTINCT subject_id)
FROM wearable_analytics.fact_physiological_measurements
WHERE measurement_timestamp >= '2025-01-01';
```

**✅ CHEAPER - Approximate count (within 2% accuracy):**
```sql
SELECT APPROX_COUNT_DISTINCT(subject_id)
FROM wearable_analytics.fact_physiological_measurements
WHERE measurement_timestamp >= '2025-01-01';
-- **Up to 10x faster, lower cost**
```

### 6. Materialize Expensive Queries

If you run the same complex query repeatedly:
```sql
-- Create a materialized view (auto-refreshed)
CREATE MATERIALIZED VIEW wearable_analytics.mv_daily_summaries AS
SELECT 
  DATE(measurement_timestamp) as date,
  subject_id,
  session_type,
  signal_type,
  COUNT(*) as measurement_count,
  AVG(value) as avg_value
FROM wearable_analytics.fact_physiological_measurements
WHERE measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
GROUP BY date, subject_id, session_type, signal_type;

-- Now query the materialized view (much cheaper)
SELECT * FROM wearable_analytics.mv_daily_summaries
WHERE date >= '2025-01-01';
```

### 7. Avoid Self-Joins on Large Tables

**❌ BAD - Expensive self-join:**
```sql
SELECT a.subject_id, a.value as hr, b.value as eda
FROM wearable_analytics.fact_physiological_measurements a
JOIN wearable_analytics.fact_physiological_measurements b
  ON a.session_id = b.session_id
  AND a.measurement_timestamp = b.measurement_timestamp
WHERE a.signal_type = 'HR'
  AND b.signal_type = 'EDA';
```

**✅ GOOD - Use PIVOT or conditional aggregation:**
```sql
SELECT 
  session_id,
  measurement_timestamp,
  MAX(CASE WHEN signal_type = 'HR' THEN value END) as hr,
  MAX(CASE WHEN signal_type = 'EDA' THEN value END) as eda
FROM wearable_analytics.fact_physiological_measurements
WHERE signal_type IN ('HR', 'EDA')
  AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY session_id, measurement_timestamp;
```

## Query Cost Estimation

Before running expensive queries:
```bash
# Dry run to estimate cost
bq query --use_legacy_sql=false --dry_run 'YOUR_QUERY_HERE'

# Or in Python:
from google.cloud import bigquery
client = bigquery.Client()

job_config = bigquery.QueryJobConfig(dry_run=True, use_query_cache=False)
query_job = client.query("YOUR_QUERY_HERE", job_config=job_config)

bytes_processed = query_job.total_bytes_processed
cost = (bytes_processed / 1e12) * 6.25
print(f"Estimated cost: ${cost:.4f}")
```

## Monthly Cost Budget

**Free Tier Limits:**
- First 1 TB of queries/month: FREE
- First 10 GB storage: FREE

**Typical Project Costs (with optimization):**
- Storage (5-10 GB): **FREE**
- Queries (<1 TB/month): **FREE**
- **Total: $0/month** ✅

**Without Optimization:**
- Storage (5-10 GB): **FREE**
- Queries (5-10 TB/month): **$31-62/month** ❌

## Monitoring Commands
```bash
# Check current month usage
bq query --use_legacy_sql=false '
SELECT 
  SUM(total_bytes_billed) / POWER(1024, 4) as tb_billed_this_month,
  SUM(total_bytes_billed) / POWER(1024, 4) * 6.25 as estimated_cost
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time >= TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), MONTH)
  AND statement_type = "SELECT"
'

# Find expensive queries
bq query --use_legacy_sql=false '
SELECT 
  creation_time,
  total_bytes_billed / POWER(1024, 3) as gb_billed,
  query
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
ORDER BY total_bytes_billed DESC
LIMIT 10
'
```

## Performance Benchmarks

### Our Optimized Queries:

| Query Type | Data Scanned | Cost | Time |
|------------|--------------|------|------|
| Single subject, 7 days | 50 MB | $0.0003 | 1-2s |
| All subjects, 7 days | 500 MB | $0.003 | 3-5s |
| Complex aggregation, 30 days | 2 GB | $0.012 | 5-10s |
| Full table scan (avoid!) | 5 GB | $0.031 | 20-30s |

## Best Practices Checklist

- [ ] Always filter on `measurement_timestamp`
- [ ] Use clustered columns in WHERE clauses
- [ ] SELECT only needed columns
- [ ] Use LIMIT for exploration
- [ ] Leverage query cache (same query within 24h)
- [ ] Dry run expensive queries first
- [ ] Monitor monthly usage
- [ ] Materialize frequently-used aggregations
- [ ] Use APPROX functions when exact counts not needed
- [ ] Avoid SELECT * in production queries

## Real Example: Cost Comparison

**Unoptimized Query:**
```sql
SELECT *
FROM wearable_analytics.fact_physiological_measurements
WHERE subject_id = 'S01';
-- Scans: 5 GB
-- Cost: $0.031
```

**Optimized Query:**
```sql
SELECT subject_id, measurement_timestamp, signal_type, value
FROM wearable_analytics.fact_physiological_measurements
WHERE subject_id = 'S01'
  AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
LIMIT 10000;
-- Scans: 5 MB
-- Cost: $0.00003
-- **1000x cheaper!**
