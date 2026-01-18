-- =============================================================================
-- SESSION PERFORMANCE METRICS
-- Purpose: Comprehensive session-level KPIs
-- Business Value: Dashboard metrics, user progress tracking
-- =============================================================================

CREATE OR REPLACE TABLE `wearable_analytics.analytics_session_performance` AS
WITH session_basics AS (
  SELECT 
    ds.session_id,
    ds.subject_id,
    ds.session_type,
    ds.session_date,
    ds.duration_minutes,
    s.age,
    s.gender,
    220 - s.age as estimated_max_hr
    
  FROM `wearable_analytics.dim_sessions` ds
  JOIN `wearable_analytics.dim_subjects` s ON ds.subject_id = s.subject_id
),
hr_metrics AS (
  SELECT 
    session_id,
    AVG(value) as avg_hr,
    MAX(value) as max_hr,
    MIN(value) as min_hr,
    STDDEV(value) as hr_variability
    
  FROM `wearable_analytics.fact_physiological_measurements`
  WHERE signal_type = 'HR'
    AND measurement_timestamp >= "2010-01-01"
  GROUP BY session_id
),
effort_metrics AS (
  SELECT 
    session_id,
    SUM(total_effort_points) as total_meps,
    SUM(minutes_in_zone) as active_minutes,
    MAX(CASE WHEN training_zone = 'ZONE_5_MAXIMUM' THEN minutes_in_zone END) as max_zone_minutes
    
  FROM `wearable_analytics.session_zone_summary`
  GROUP BY session_id
),
stress_metrics AS (
  SELECT 
    session_id,
    AVG(stress_index) as avg_stress_index,
    MAX(stress_index) as peak_stress_index,
    COUNTIF(stress_state = 'STRESSED') / COUNT(*) as pct_time_stressed
    
  FROM `wearable_analytics.derived_stress_indicators`
  GROUP BY session_id
),
hrv_metrics AS (
  SELECT 
    session_id,
    AVG(rmssd) as avg_rmssd,
    AVG(sdnn) as avg_sdnn
    
  FROM `wearable_analytics.derived_hrv_metrics`
  GROUP BY session_id
)
SELECT 
  sb.*,
  
  -- Heart rate metrics
  ROUND(hm.avg_hr, 1) as avg_hr,
  ROUND(hm.max_hr, 1) as max_hr,
  ROUND(100.0 * hm.max_hr / sb.estimated_max_hr, 1) as max_hr_pct,
  ROUND(hm.hr_variability, 1) as hr_variability,
  
  -- Effort metrics
  COALESCE(em.total_meps, 0) as total_meps,
  COALESCE(em.active_minutes, 0) as active_minutes,
  COALESCE(em.max_zone_minutes, 0) as max_zone_minutes,
  
  -- Stress metrics (for STRESS sessions)
  ROUND(sm.avg_stress_index, 3) as avg_stress_index,
  ROUND(sm.peak_stress_index, 3) as peak_stress_index,
  ROUND(sm.pct_time_stressed * 100, 1) as pct_time_stressed,
  
  -- Recovery metrics
  ROUND(hrvm.avg_rmssd, 1) as avg_rmssd,
  ROUND(hrvm.avg_sdnn, 1) as avg_sdnn,
  
  -- Performance score (composite)
  CASE 
    WHEN sb.session_type IN ('AEROBIC', 'ANAEROBIC') THEN
      LEAST(100, COALESCE(em.total_meps / 2, 0) + 
                 (100.0 * hm.max_hr / sb.estimated_max_hr) / 2)
    WHEN sb.session_type = 'STRESS' THEN
      100 - (COALESCE(sm.avg_stress_index, 0) * 100)
    ELSE NULL
  END as performance_score
  
FROM session_basics sb
LEFT JOIN hr_metrics hm ON sb.session_id = hm.session_id
LEFT JOIN effort_metrics em ON sb.session_id = em.session_id
LEFT JOIN stress_metrics sm ON sb.session_id = sm.session_id
LEFT JOIN hrv_metrics hrvm ON sb.session_id = hrvm.session_id
ORDER BY sb.session_date DESC, sb.subject_id;

-- Top performing sessions
SELECT 
  session_id,
  subject_id,
  session_type,
  session_date,
  total_meps,
  max_hr_pct,
  ROUND(performance_score, 1) as performance_score
FROM `wearable_analytics.analytics_session_performance`
WHERE performance_score IS NOT NULL
ORDER BY performance_score DESC
LIMIT 10;