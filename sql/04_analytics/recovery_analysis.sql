-- =============================================================================
-- RECOVERY TIME ANALYSIS
-- Purpose: Measure recovery time after different exercise intensities
-- Business Value: Informs rest recommendations and training load management
-- =============================================================================

CREATE OR REPLACE TABLE `wearable_analytics.analytics_recovery_time` AS
WITH exercise_peaks AS (
  -- Find peak HR during exercise
  SELECT 
    subject_id,
    session_id,
    session_type,
    MAX(current_hr) as peak_hr,
    MAX(hr_percentage) as peak_hr_pct,
    MAX(measurement_timestamp) as peak_time
  FROM `wearable_analytics.derived_exercise_zones`
  WHERE training_zone IN ('ZONE_4_VERY_HARD', 'ZONE_5_MAXIMUM')
  GROUP BY subject_id, session_id, session_type
),
recovery_timeline AS (
  -- Track HR decline after peak
  SELECT 
    ez.subject_id,
    ez.session_id,
    ez.session_type,
    ep.peak_hr,
    ep.peak_hr_pct,
    ez.measurement_timestamp,
    ez.current_hr,
    
    -- Time since peak
    TIMESTAMP_DIFF(ez.measurement_timestamp, ep.peak_time, SECOND) as seconds_since_peak,
    
    -- Recovery percentage
    100.0 * (ep.peak_hr - ez.current_hr) / ep.peak_hr as recovery_pct,
    
    -- HR back to zones
    CASE 
      WHEN ez.current_hr / (220 - (SELECT age FROM `wearable_analytics.dim_subjects` WHERE subject_id = ez.subject_id)) < 0.60 THEN 'RECOVERED'
      ELSE 'RECOVERING'
    END as recovery_status
    
  FROM `wearable_analytics.derived_exercise_zones` ez
  JOIN exercise_peaks ep 
    ON ez.session_id = ep.session_id
  WHERE ez.measurement_timestamp >= ep.peak_time
)
SELECT 
  subject_id,
  session_id,
  session_type,
  peak_hr,
  peak_hr_pct,
  
  -- Time to recovery milestones
  MIN(CASE WHEN recovery_pct >= 25 THEN seconds_since_peak END) / 60.0 as time_to_25pct_recovery_min,
  MIN(CASE WHEN recovery_pct >= 50 THEN seconds_since_peak END) / 60.0 as time_to_50pct_recovery_min,
  MIN(CASE WHEN recovery_pct >= 75 THEN seconds_since_peak END) / 60.0 as time_to_75pct_recovery_min,
  MIN(CASE WHEN recovery_status = 'RECOVERED' THEN seconds_since_peak END) / 60.0 as time_to_full_recovery_min,
  
  -- Recovery rate (% per minute)
  MAX(recovery_pct) / NULLIF(MAX(seconds_since_peak) / 60.0, 0) as avg_recovery_rate_pct_per_min
  
FROM recovery_timeline
GROUP BY subject_id, session_id, session_type, peak_hr, peak_hr_pct;

-- Summary by session type
SELECT 
  session_type,
  COUNT(DISTINCT subject_id) as subjects,
  ROUND(AVG(peak_hr), 1) as avg_peak_hr,
  ROUND(AVG(time_to_50pct_recovery_min), 1) as avg_time_to_50pct_min,
  ROUND(AVG(time_to_75pct_recovery_min), 1) as avg_time_to_75pct_min,
  ROUND(AVG(avg_recovery_rate_pct_per_min), 2) as avg_recovery_rate
FROM `wearable_analytics.analytics_recovery_time`
WHERE time_to_50pct_recovery_min IS NOT NULL
GROUP BY session_type
ORDER BY session_type;