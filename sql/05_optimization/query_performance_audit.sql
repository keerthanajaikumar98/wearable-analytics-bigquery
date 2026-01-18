-- =============================================================================
-- QUERY PERFORMANCE AUDIT
-- Purpose: Analyze recent queries to identify optimization opportunities
-- Note: Requires access to INFORMATION_SCHEMA.JOBS (last 7 days)
-- =============================================================================

SELECT
  creation_time,
  job_id,
  user_email,
  query,

  -- Performance metrics
  ROUND(total_slot_ms / 1000.0, 2) AS total_slot_seconds,
  ROUND(total_bytes_processed / POW(1024, 3), 2) AS gb_processed,
  ROUND(total_bytes_billed / POW(1024, 3), 2) AS gb_billed,

  -- Estimated cost ($6.25 per TB)
  ROUND((total_bytes_billed / POW(1024, 4)) * 6.25, 4) AS estimated_cost_usd,

  -- Execution duration
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS execution_time_sec,

  -- Efficiency score (lower is better)
  SAFE_DIVIDE(total_bytes_billed, total_bytes_processed) AS billing_efficiency,

  -- Cost flags
  CASE
    WHEN total_bytes_billed > POW(1024, 4) THEN '🔴 EXPENSIVE (>1TB)'
    WHEN total_bytes_billed > POW(1024, 3) * 100 THEN '🟡 MODERATE (>100GB)'
    ELSE '🟢 EFFICIENT'
  END AS cost_flag,

  -- Cache status
  CASE
    WHEN cache_hit THEN '✓ Cache Hit'
    ELSE '✗ No Cache'
  END AS cache_status

FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_USER
WHERE
  creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND statement_type = 'SELECT'
  AND job_type = 'QUERY'
  AND state = 'DONE'
  AND error_result IS NULL
ORDER BY total_bytes_billed DESC
LIMIT 20;
