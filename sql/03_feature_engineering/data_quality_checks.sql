-- =============================================================================
-- DATA QUALITY MONITORING
-- Purpose: Identify data quality issues and anomalies
-- =============================================================================

-- Create view for ongoing data quality monitoring
CREATE OR REPLACE VIEW `wearable_analytics.vw_data_quality_report` AS
WITH base AS (
  SELECT
    subject_id,
    session_type,
    signal_type,
    measurement_timestamp,
    value,
    AVG(value) OVER (PARTITION BY signal_type) AS signal_avg,
    STDDEV(value) OVER (PARTITION BY signal_type) AS signal_stddev
  FROM `wearable_analytics.fact_physiological_measurements`
  WHERE measurement_timestamp >=  "2010-01-01"
),
flagged AS (
  SELECT
    *,
    CASE
      WHEN signal_stddev IS NOT NULL
        AND ABS(value - signal_avg) > 3 * signal_stddev
      THEN 1 
      ELSE 0
    END AS is_outlier
  FROM base
),
signal_stats AS (
  SELECT 
    subject_id,
    session_type,
    signal_type,
    COUNT(*) AS total_measurements,
    COUNT(DISTINCT DATE(measurement_timestamp)) AS days_recorded,
    MIN(measurement_timestamp) AS first_measurement,
    MAX(measurement_timestamp) AS last_measurement,
    TIMESTAMP_DIFF(
      MAX(measurement_timestamp),
      MIN(measurement_timestamp),
      SECOND
    ) / 60.0 AS duration_minutes,
    AVG(value) AS avg_value,
    STDDEV(value) AS stddev_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    COUNTIF(value IS NULL) AS null_count,
    SUM(is_outlier) AS outlier_count
  FROM flagged
  GROUP BY subject_id, session_type, signal_type
)
SELECT 
  *,
  ROUND(100.0 * outlier_count / NULLIF(total_measurements, 0), 2) AS outlier_percentage,
  ROUND(100.0 * null_count / NULLIF(total_measurements, 0), 2) AS null_percentage,
  CASE signal_type
    WHEN 'BVP'   THEN duration_minutes * 60 * 64
    WHEN 'EDA'   THEN duration_minutes * 60 * 4
    WHEN 'TEMP'  THEN duration_minutes * 60 * 4
    WHEN 'ACC_X' THEN duration_minutes * 60 * 32
    WHEN 'ACC_Y' THEN duration_minutes * 60 * 32
    WHEN 'ACC_Z' THEN duration_minutes * 60 * 32
    WHEN 'HR'    THEN duration_minutes * 60 * 1
    ELSE NULL
  END AS expected_sample_count,
  CASE 
    WHEN signal_type != 'IBI' THEN
      ROUND(
        100.0 * total_measurements / NULLIF(
          CASE signal_type
            WHEN 'BVP'   THEN duration_minutes * 60 * 64
            WHEN 'EDA'   THEN duration_minutes * 60 * 4
            WHEN 'TEMP'  THEN duration_minutes * 60 * 4
            WHEN 'ACC_X' THEN duration_minutes * 60 * 32
            WHEN 'ACC_Y' THEN duration_minutes * 60 * 32
            WHEN 'ACC_Z' THEN duration_minutes * 60 * 32
            WHEN 'HR'    THEN duration_minutes * 60 * 1
          END, 0
        ),
        2
      )
  END AS data_completeness_pct
FROM signal_stats
ORDER BY subject_id, session_type, signal_type;