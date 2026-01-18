-- =============================================================================
-- STRESS DETECTION FEATURES
-- Purpose: Combine multiple physiological signals to detect stress
-- =============================================================================

CREATE OR REPLACE TABLE `wearable_analytics.derived_stress_indicators` AS
WITH signal_pivoted AS (
  -- Pivot signals to one row per time window
  SELECT 
    subject_id,
    session_id,
    session_type,
    TIMESTAMP_TRUNC(measurement_timestamp, MINUTE) as time_window,
    
    -- Average values per minute
    AVG(CASE WHEN signal_type = 'EDA' THEN value END) as avg_eda,
    AVG(CASE WHEN signal_type = 'TEMP' THEN value END) as avg_temp,
    AVG(CASE WHEN signal_type = 'HR' THEN value END) as avg_hr,
    
    -- Variability metrics
    STDDEV(CASE WHEN signal_type = 'HR' THEN value END) as hr_std,
    STDDEV(CASE WHEN signal_type = 'EDA' THEN value END) as eda_std,
    
    -- Peak detection for EDA (skin conductance responses)
    MAX(CASE WHEN signal_type = 'EDA' THEN value END) - 
    MIN(CASE WHEN signal_type = 'EDA' THEN value END) as eda_range
    
  FROM `wearable_analytics.fact_physiological_measurements`
  WHERE signal_type IN ('EDA', 'TEMP', 'HR')
    AND measurement_timestamp >=  "2010-01-01"
  GROUP BY subject_id, session_id, session_type, time_window
),
baseline_stats AS (
  -- Calculate personal baseline during rest/baseline periods
  -- (First 3 minutes of each session is typically baseline)
  SELECT 
    sp.subject_id,
    AVG(sp.avg_eda) as baseline_eda,
    AVG(sp.avg_temp) as baseline_temp,
    AVG(sp.avg_hr) as baseline_hr,
    STDDEV(sp.avg_hr) as baseline_hr_std
  FROM signal_pivoted sp
  JOIN `wearable_analytics.dim_sessions` ds 
    ON sp.session_id = ds.session_id
  WHERE TIMESTAMP_DIFF(sp.time_window, ds.session_start_time, MINUTE) <= 3
  GROUP BY sp.subject_id
  HAVING baseline_eda IS NOT NULL  -- Moved filter to HAVING clause
)
SELECT 
  sp.subject_id,
  sp.session_id,
  sp.session_type,
  sp.time_window,
  sp.avg_eda,
  sp.avg_temp,
  sp.avg_hr,
  sp.hr_std,
  sp.eda_std,
  sp.eda_range,
  
  -- Baseline values
  bs.baseline_eda,
  bs.baseline_temp,
  bs.baseline_hr,
  
  -- Change from baseline (normalized)
  SAFE_DIVIDE(sp.avg_eda - bs.baseline_eda, bs.baseline_eda) as eda_change_pct,
  SAFE_DIVIDE(sp.avg_hr - bs.baseline_hr, bs.baseline_hr) as hr_change_pct,
  sp.avg_temp - bs.baseline_temp as temp_delta_celsius,
  
  -- Composite stress index (weighted combination of indicators)
  (
    0.4 * SAFE_DIVIDE(sp.avg_eda - bs.baseline_eda, bs.baseline_eda) +
    0.3 * SAFE_DIVIDE(sp.avg_hr - bs.baseline_hr, bs.baseline_hr) +
    0.2 * (sp.avg_temp - bs.baseline_temp) / 2.0 +
    0.1 * (1 - SAFE_DIVIDE(sp.hr_std, 100))
  ) as stress_index,
  
  -- Binary stress classification
  CASE 
    WHEN (
      SAFE_DIVIDE(sp.avg_eda - bs.baseline_eda, bs.baseline_eda) > 0.2 OR
      SAFE_DIVIDE(sp.avg_hr - bs.baseline_hr, bs.baseline_hr) > 0.15
    ) THEN 'STRESSED'
    ELSE 'CALM'
  END as stress_state
  
FROM signal_pivoted sp
INNER JOIN baseline_stats bs  -- Changed to INNER JOIN
  ON sp.subject_id = bs.subject_id
ORDER BY sp.subject_id, sp.time_window;