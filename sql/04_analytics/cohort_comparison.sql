-- =============================================================================
-- COHORT COMPARISON: V1 vs V2 Protocol
-- Purpose: Evaluate protocol improvements between study phases
-- Business Value: Validate study design changes, inform future protocols
-- =============================================================================

-- Data quality comparison
CREATE OR REPLACE TABLE `wearable_analytics.analytics_cohort_comparison` AS
WITH data_quality AS (
  SELECT 
    s.cohort,
    COUNT(DISTINCT pm.subject_id) as unique_subjects,
    COUNT(DISTINCT pm.session_id) as total_sessions,
    COUNT(*) / COUNT(DISTINCT pm.subject_id) as avg_measurements_per_subject,
    
    -- Signal completeness
    AVG(CASE WHEN pm.signal_type = 'HR' THEN 1.0 ELSE 0.0 END) as hr_coverage,
    AVG(CASE WHEN pm.signal_type = 'EDA' THEN 1.0 ELSE 0.0 END) as eda_coverage,
    
    -- Session duration
    AVG(TIMESTAMP_DIFF(
      MAX(pm.measurement_timestamp) OVER (PARTITION BY pm.session_id),
      MIN(pm.measurement_timestamp) OVER (PARTITION BY pm.session_id),
      MINUTE
    )) as avg_session_duration_min
    
  FROM `wearable_analytics.fact_physiological_measurements` pm
  JOIN `wearable_analytics.dim_subjects` s ON pm.subject_id = s.subject_id
  WHERE pm.measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 365 DAY)
  GROUP BY s.cohort
),
stress_metrics AS (
  SELECT 
    s.cohort,
    AVG(si.stress_index) as avg_stress_index,
    STDDEV(si.stress_index) as stress_variability,
    AVG(si.eda_change_pct) as avg_eda_response,
    AVG(si.hr_change_pct) as avg_hr_response
    
  FROM `wearable_analytics.derived_stress_indicators` si
  JOIN `wearable_analytics.dim_subjects` s ON si.subject_id = s.subject_id
  GROUP BY s.cohort
),
recovery_metrics AS (
  SELECT 
    s.cohort,
    AVG(hrv.rmssd) as avg_rmssd,
    AVG(hrv.sdnn) as avg_sdnn,
    COUNTIF(hrv.recovery_status = 'GOOD_RECOVERY') / COUNT(*) as pct_good_recovery
    
  FROM `wearable_analytics.derived_hrv_metrics` hrv
  JOIN `wearable_analytics.dim_subjects` s ON hrv.subject_id = s.subject_id
  GROUP BY s.cohort
)
SELECT 
  dq.cohort,
  dq.unique_subjects,
  dq.total_sessions,
  ROUND(dq.avg_measurements_per_subject, 0) as avg_measurements_per_subject,
  ROUND(dq.avg_session_duration_min, 1) as avg_session_duration_min,
  ROUND(dq.hr_coverage * 100, 1) as hr_coverage_pct,
  ROUND(dq.eda_coverage * 100, 1) as eda_coverage_pct,
  
  -- Stress metrics
  ROUND(sm.avg_stress_index, 3) as avg_stress_index,
  ROUND(sm.stress_variability, 3) as stress_variability,
  ROUND(sm.avg_eda_response * 100, 1) as avg_eda_response_pct,
  ROUND(sm.avg_hr_response * 100, 1) as avg_hr_response_pct,
  
  -- Recovery metrics
  ROUND(rm.avg_rmssd, 1) as avg_rmssd,
  ROUND(rm.avg_sdnn, 1) as avg_sdnn,
  ROUND(rm.pct_good_recovery * 100, 1) as pct_good_recovery,
  
  -- Statistical comparison
  CASE 
    WHEN dq.cohort = 'V2' THEN 'IMPROVED_PROTOCOL'
    ELSE 'ORIGINAL_PROTOCOL'
  END as protocol_version
  
FROM data_quality dq
LEFT JOIN stress_metrics sm ON dq.cohort = sm.cohort
LEFT JOIN recovery_metrics rm ON dq.cohort = rm.cohort
ORDER BY dq.cohort;

-- Summary
SELECT * FROM `wearable_analytics.analytics_cohort_comparison`;